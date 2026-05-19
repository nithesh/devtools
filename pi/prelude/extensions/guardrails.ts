import { existsSync, readFileSync } from "node:fs";
import { dirname, join, normalize, relative, resolve } from "node:path";
import { getAgentDir, isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";

interface RuleGroup {
  exact?: string[];
  prefix?: string[];
}

interface GuardrailsConfig {
  protectedReadPatterns?: string[];
  allowReadPatterns?: string[];
  protectedWritePatterns?: string[];
  allowWritePatterns?: string[];
  dangerously_allow?: RuleGroup;
  always_block?: RuleGroup;
  confirm?: RuleGroup;
}

export interface ResolvedRules {
  exact: string[];
  prefix: string[];
}

interface ResolvedGuardrailsConfig {
  protectedReadPatterns: string[];
  allowReadPatterns: string[];
  protectedWritePatterns: string[];
  allowWritePatterns: string[];
  dangerously_allow: ResolvedRules;
  always_block: ResolvedRules;
  confirm: ResolvedRules;
}

const DEFAULT_PROTECTED_READ_PATTERNS = [
  "/.env",
  "**/id_rsa",
  "**/id_ed25519",
  "**/*.pem",
  "**/*.key",
  "**/*.p12",
  "**/*.pfx",
  "**/.aws/credentials",
  "**/.npmrc",
  "**/.docker/config.json",
];
const DEFAULT_ALLOW_READ_PATTERNS = ["/.env.example", "/.envrc"];
const DEFAULT_PROTECTED_WRITE_PATTERNS = ["/.env", "/.git/**", "**/node_modules/**", "**/dist/**", "**/build/**", "**/.next/**", "**/target/**"];
const DEFAULT_ALLOW_WRITE_PATTERNS: string[] = [];

const DEFAULT_DANGEROUSLY_ALLOW: ResolvedRules = { exact: [], prefix: [] };
const DEFAULT_ALWAYS_BLOCK: ResolvedRules = { exact: ["rm -rf /"], prefix: ["mkfs", "dd if="] };
const DEFAULT_CONFIRM: ResolvedRules = {
  exact: ["git reset --hard", "git clean -fd"],
  prefix: ["rm -rf", "sudo", "chmod -r", "npm publish", "gh release", "docker push", "kubectl delete"],
};

function findNearestProjectConfig(cwd: string, relativeConfigPath: string): string | null {
  let currentDir = cwd;
  while (true) {
    const candidate = join(currentDir, relativeConfigPath);
    if (existsSync(candidate)) return candidate;

    const parentDir = dirname(currentDir);
    if (parentDir === currentDir) return null;
    currentDir = parentDir;
  }
}

function findGitRoot(cwd: string): string {
  let currentDir = cwd;
  while (true) {
    if (existsSync(join(currentDir, ".git"))) return currentDir;
    const parentDir = dirname(currentDir);
    if (parentDir === currentDir) return cwd;
    currentDir = parentDir;
  }
}

function loadJson(path: string | null): GuardrailsConfig {
  if (!path || !existsSync(path)) return {};
  try {
    return JSON.parse(readFileSync(path, "utf8")) as GuardrailsConfig;
  } catch {
    return {};
  }
}

function normalizeCmd(text: string): string {
  return text.toLowerCase().replace(/\s+/g, " ").trim();
}

function normalizeRel(p: string): string {
  return p.replace(/\\/g, "/").replace(/^\.(\/|$)/, "").replace(/^\/+/, "");
}

function globToRegExp(glob: string): RegExp {
  let s = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        s += ".*";
        i++;
      } else {
        s += "[^/]*";
      }
      continue;
    }
    if (c === "?") {
      s += "[^/]";
      continue;
    }
    if (/[\\^$+?.()|{}\[\]]/.test(c)) {
      s += `\\${c}`;
    } else {
      s += c;
    }
  }
  return new RegExp(`^${s}$`);
}

export function patternMatches(absPath: string, cwd: string, gitRoot: string, pattern: string): boolean {
  const normalizedPattern = normalizeRel(pattern.trim());
  if (!normalizedPattern) return false;

  const relToCwd = normalizeRel(relative(cwd, absPath));
  const relToRoot = normalizeRel(relative(gitRoot, absPath));
  const anchored = pattern.trim().startsWith("/");
  const target = anchored ? relToRoot : relToCwd;

  const basePattern = normalizedPattern.endsWith("/") ? `${normalizedPattern}**` : normalizedPattern;
  const rx = globToRegExp(basePattern);

  if (anchored) {
    return rx.test(target);
  }

  if (!normalizedPattern.includes("/")) {
    return target.split("/").some((seg) => rx.test(seg));
  }

  return rx.test(target);
}

export function splitCommandSegments(command: string): string[] {
  return command
    .split(/&&|\|\||;|\||\n/g)
    .map((s) => normalizeCmd(s))
    .filter((s) => s.length > 0);
}

export function matchesPrefix(segment: string, prefix: string): boolean {
  return segment === prefix || segment.startsWith(`${prefix} `);
}

export function matchRule(segment: string, rules: ResolvedRules): string | null {
  const exact = rules.exact.find((r) => segment === normalizeCmd(r));
  if (exact) return exact;
  const pref = rules.prefix.find((r) => matchesPrefix(segment, normalizeCmd(r)));
  return pref ?? null;
}

function resolveRules(group: RuleGroup | undefined, defaults: ResolvedRules): ResolvedRules {
  return { exact: group?.exact ?? defaults.exact, prefix: group?.prefix ?? defaults.prefix };
}

function loadConfig(cwd: string): ResolvedGuardrailsConfig {
  const userPath = join(getAgentDir(), "prelude", "guardrails.json");
  const projectPath = findNearestProjectConfig(cwd, join(".pi", "prelude", "guardrails.json"));
  const merged = { ...loadJson(userPath), ...loadJson(projectPath) };

  return {
    protectedReadPatterns: merged.protectedReadPatterns ?? DEFAULT_PROTECTED_READ_PATTERNS,
    allowReadPatterns: merged.allowReadPatterns ?? DEFAULT_ALLOW_READ_PATTERNS,
    protectedWritePatterns: merged.protectedWritePatterns ?? DEFAULT_PROTECTED_WRITE_PATTERNS,
    allowWritePatterns: merged.allowWritePatterns ?? DEFAULT_ALLOW_WRITE_PATTERNS,
    dangerously_allow: resolveRules(merged.dangerously_allow, DEFAULT_DANGEROUSLY_ALLOW),
    always_block: resolveRules(merged.always_block, DEFAULT_ALWAYS_BLOCK),
    confirm: resolveRules(merged.confirm, DEFAULT_CONFIRM),
  };
}

export default function guardrails(pi: ExtensionAPI) {
  let config = loadConfig(process.cwd());
  let errorNotified = false;

  const refresh = (ctx: ExtensionContext) => {
    config = loadConfig(ctx.cwd);
  };

  const handleError = (ctx: ExtensionContext, err: unknown) => {
    if (!errorNotified) {
      errorNotified = true;
      ctx.ui.notify(`Guardrails degraded: ${String((err as Error)?.message ?? err)}`, "warning");
    }
  };

  pi.on("session_start", async (_event, ctx) => refresh(ctx));

  pi.on("tool_call", async (event, ctx) => {
    try {
      if (isToolCallEventType("read", event) || isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
        const rawPath = event.input.path;
        const absPath = normalize(resolve(ctx.cwd, rawPath));
        const gitRoot = findGitRoot(ctx.cwd);

        const isRead = isToolCallEventType("read", event);
        const allowList = isRead ? config.allowReadPatterns : config.allowWritePatterns;
        const protectedList = isRead ? config.protectedReadPatterns : config.protectedWritePatterns;

        const allowedBy = allowList.find((p) => patternMatches(absPath, ctx.cwd, gitRoot, p));
        if (allowedBy) return;

        const blockedBy = protectedList.find((p) => patternMatches(absPath, ctx.cwd, gitRoot, p));
        if (blockedBy) {
          return {
            block: true,
            reason: `Blocked ${event.toolName} on protected path '${rawPath}' (pattern: ${blockedBy}).`,
          };
        }
        return;
      }

      if (isToolCallEventType("bash", event)) {
        const command = event.input.command ?? "";
        const segments = splitCommandSegments(command);

        const blockedMatches: string[] = [];
        const confirmMatches: string[] = [];

        for (const seg of segments) {
          if (matchRule(seg, config.dangerously_allow)) continue;

          const block = matchRule(seg, config.always_block);
          if (block) {
            blockedMatches.push(`${block} (segment: ${seg})`);
            continue;
          }

          const confirm = matchRule(seg, config.confirm);
          if (confirm) confirmMatches.push(`${confirm} (segment: ${seg})`);
        }

        if (blockedMatches.length > 0) {
          return { block: true, reason: `Blocked dangerous command by policy: ${blockedMatches[0]}` };
        }

        if (confirmMatches.length === 0) return;
        if (!ctx.hasUI) {
          return { block: true, reason: `Blocked risky command in non-interactive mode: ${confirmMatches[0]}` };
        }

        const ok = await ctx.ui.confirm(
          "Guardrails",
          `Allow risky bash command?\n\nMatch: ${confirmMatches[0]}\nCommand: ${command}`,
        );
        if (!ok) return { block: true, reason: `User denied risky command: ${confirmMatches[0]}` };
      }
    } catch (err) {
      handleError(ctx, err);
      return { block: true, reason: "Guardrails internal error; command blocked safely." };
    }
  });
}
