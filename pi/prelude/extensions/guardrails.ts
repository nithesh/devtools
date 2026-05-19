import { existsSync, readFileSync } from "node:fs";
import { dirname, join, normalize, resolve } from "node:path";
import { getAgentDir, isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";

interface RuleGroup {
  exact?: string[];
  prefix?: string[];
}

interface GuardrailsConfig {
  protectedPaths?: string[];
  allowPaths?: string[];
  dangerously_allow?: RuleGroup;
  always_block?: RuleGroup;
  confirm?: RuleGroup;
}

interface ResolvedRules {
  exact: string[];
  prefix: string[];
}

interface ResolvedGuardrailsConfig {
  protectedPaths: string[];
  allowPaths: string[];
  dangerously_allow: ResolvedRules;
  always_block: ResolvedRules;
  confirm: ResolvedRules;
}

const DEFAULT_PROTECTED_PATHS = [".env", ".git", "node_modules", "dist", "build", ".next", "target"];

const DEFAULT_DANGEROUSLY_ALLOW: ResolvedRules = { exact: [], prefix: [] };

const DEFAULT_ALWAYS_BLOCK: ResolvedRules = {
  exact: ["rm -rf /"],
  prefix: ["mkfs", "dd if="],
};

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

function loadJson(path: string | null): GuardrailsConfig {
  if (!path || !existsSync(path)) return {};
  try {
    return JSON.parse(readFileSync(path, "utf8")) as GuardrailsConfig;
  } catch {
    return {};
  }
}

function hasPathPrefix(target: string, base: string): boolean {
  const t = normalize(target);
  const b = normalize(base);
  return t === b || t.startsWith(`${b}/`);
}

function pathMatchesRule(absPath: string, rule: string, cwd: string): boolean {
  const base = resolve(cwd, rule);
  return hasPathPrefix(absPath, base);
}

function normalizeCmd(text: string): string {
  return text.toLowerCase().replace(/\s+/g, " ").trim();
}

function splitCommandSegments(command: string): string[] {
  return command
    .split(/&&|\|\||;|\||\n/g)
    .map((s) => normalizeCmd(s))
    .filter((s) => s.length > 0);
}

function matchesPrefix(segment: string, prefix: string): boolean {
  return segment === prefix || segment.startsWith(`${prefix} `);
}

function matchRule(segment: string, rules: ResolvedRules): string | null {
  const exact = rules.exact.find((r) => segment === normalizeCmd(r));
  if (exact) return exact;

  const pref = rules.prefix.find((r) => matchesPrefix(segment, normalizeCmd(r)));
  if (pref) return pref;

  return null;
}

function resolveRules(group: RuleGroup | undefined, defaults: ResolvedRules): ResolvedRules {
  return {
    exact: group?.exact ?? defaults.exact,
    prefix: group?.prefix ?? defaults.prefix,
  };
}

function loadConfig(cwd: string): ResolvedGuardrailsConfig {
  const userPath = join(getAgentDir(), "prelude", "guardrails.json");
  const projectPath = findNearestProjectConfig(cwd, join(".pi", "prelude", "guardrails.json"));
  const merged = {
    ...loadJson(userPath),
    ...loadJson(projectPath),
  };

  return {
    protectedPaths: merged.protectedPaths ?? DEFAULT_PROTECTED_PATHS,
    allowPaths: merged.allowPaths ?? [],
    dangerously_allow: resolveRules(merged.dangerously_allow, DEFAULT_DANGEROUSLY_ALLOW),
    always_block: resolveRules(merged.always_block, DEFAULT_ALWAYS_BLOCK),
    confirm: resolveRules(merged.confirm, DEFAULT_CONFIRM),
  };
}

export default function guardrails(pi: ExtensionAPI) {
  let config = loadConfig(process.cwd());

  const refresh = (ctx: ExtensionContext) => {
    config = loadConfig(ctx.cwd);
  };

  pi.on("session_start", async (_event, ctx) => {
    refresh(ctx);
  });

  pi.on("tool_call", async (event, ctx) => {
    if (isToolCallEventType("read", event) || isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
      const rawPath = event.input.path;
      const absPath = resolve(ctx.cwd, rawPath);

      const allow = config.allowPaths.find((rule) => pathMatchesRule(absPath, rule, ctx.cwd));
      if (allow) return;

      const blockedBy = config.protectedPaths.find((rule) => pathMatchesRule(absPath, rule, ctx.cwd));
      if (blockedBy) {
        return {
          block: true,
          reason: `Blocked ${event.toolName} on protected path '${rawPath}' (rule: ${blockedBy}).`,
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
        if (confirm) {
          confirmMatches.push(`${confirm} (segment: ${seg})`);
        }
      }

      if (blockedMatches.length > 0) {
        return {
          block: true,
          reason: `Blocked dangerous command by policy: ${blockedMatches[0]}`,
        };
      }

      if (confirmMatches.length === 0) return;

      if (!ctx.hasUI) {
        return {
          block: true,
          reason: `Blocked risky command in non-interactive mode: ${confirmMatches[0]}`,
        };
      }

      const ok = await ctx.ui.confirm(
        "Guardrails",
        `Allow risky bash command?\n\nMatch: ${confirmMatches[0]}\nCommand: ${command}`,
      );
      if (!ok) {
        return {
          block: true,
          reason: `User denied risky command: ${confirmMatches[0]}`,
        };
      }
    }
  });
}
