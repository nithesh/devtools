import { existsSync, readFileSync } from "node:fs";
import { dirname, join, normalize, resolve } from "node:path";
import { getAgentDir, isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";

interface GuardrailsConfig {
  protectedPaths?: string[];
  allowPaths?: string[];
  dangerousCommands?: string[];
  alwaysBlockCommands?: string[];
}

const DEFAULT_PROTECTED_PATHS = [
  ".env",
  ".git",
  "node_modules",
  "dist",
  "build",
  ".next",
  "target",
];

const DEFAULT_DANGEROUS_COMMANDS = [
  "rm -rf",
  "sudo",
  "git reset --hard",
  "git clean -fd",
  "chmod -R",
  "npm publish",
  "gh release",
  "docker push",
  "kubectl delete",
];

const DEFAULT_ALWAYS_BLOCK_COMMANDS = ["rm -rf /", "mkfs", "dd if="];

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

function commandMatches(command: string, patterns: string[]): string | null {
  const c = command.toLowerCase();
  const match = patterns.find((p) => c.includes(p.toLowerCase()));
  return match ?? null;
}

function loadConfig(cwd: string): Required<GuardrailsConfig> {
  const userPath = join(getAgentDir(), "prelude", "guardrails.json");
  const projectPath = findNearestProjectConfig(cwd, join(".pi", "prelude", "guardrails.json"));
  const merged = {
    ...loadJson(userPath),
    ...loadJson(projectPath),
  };

  return {
    protectedPaths: merged.protectedPaths ?? DEFAULT_PROTECTED_PATHS,
    allowPaths: merged.allowPaths ?? [],
    dangerousCommands: merged.dangerousCommands ?? DEFAULT_DANGEROUS_COMMANDS,
    alwaysBlockCommands: merged.alwaysBlockCommands ?? DEFAULT_ALWAYS_BLOCK_COMMANDS,
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
    if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
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
      const hardBlock = commandMatches(command, config.alwaysBlockCommands);
      if (hardBlock) {
        return {
          block: true,
          reason: `Blocked dangerous command by policy (pattern: ${hardBlock}).`,
        };
      }

      const risky = commandMatches(command, config.dangerousCommands);
      if (!risky) return;

      if (!ctx.hasUI) {
        return {
          block: true,
          reason: `Blocked risky command in non-interactive mode (pattern: ${risky}).`,
        };
      }

      const ok = await ctx.ui.confirm("Guardrails", `Allow risky bash command?\n\nPattern: ${risky}\nCommand: ${command}`);
      if (!ok) {
        return {
          block: true,
          reason: `User denied risky command (pattern: ${risky}).`,
        };
      }
    }
  });
}
