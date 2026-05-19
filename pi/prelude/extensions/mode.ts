import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { Api, Model } from "@mariozechner/pi-ai";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";

type ModeName = "plan" | "build" | "debug" | "review" | "quick";

interface ModeConfig {
  provider?: string;
  model?: string;
  thinkingLevel?: ThinkingLevel;
  tools?: string[];
  instructions?: string;
}

type ModesConfig = Record<string, ModeConfig>;

interface OriginalState {
  model: Model<Api> | undefined;
  thinkingLevel: ThinkingLevel;
  tools: string[];
}

const DEFAULT_MODES: Record<ModeName, ModeConfig> = {
  plan: {
    thinkingLevel: "high",
    tools: ["read", "grep", "find", "ls", "ask_user", "todo", "web_search", "web_fetch"],
    instructions:
      "You are in planning mode. Do not edit or write files. Explore thoroughly, ask clarifying questions when ambiguous, and produce a concrete implementation plan.",
  },
  build: {
    thinkingLevel: "medium",
    tools: ["read", "bash", "edit", "write", "grep", "find", "ls", "ask_user", "todo"],
    instructions: "You are in build mode. Make focused changes, keep scope tight, and verify with relevant checks.",
  },
  debug: {
    thinkingLevel: "high",
    tools: ["read", "bash", "edit", "write", "grep", "find", "ls", "ask_user", "todo"],
    instructions: "You are in debug mode. Reproduce, isolate root cause, apply minimal fix, and verify.",
  },
  review: {
    thinkingLevel: "medium",
    tools: ["read", "grep", "find", "ls", "ask_user", "web_search", "web_fetch"],
    instructions: "You are in review mode. Do not edit files unless explicitly requested.",
  },
  quick: {
    thinkingLevel: "minimal",
    tools: ["read", "grep", "find", "ls", "ask_user", "todo"],
    instructions: "You are in quick mode. Be concise and action-oriented.",
  },
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

function loadModes(cwd: string): ModesConfig {
  const userPath = join(getAgentDir(), "prelude", "modes.json");
  const projectPath = findNearestProjectConfig(cwd, join(".pi", "prelude", "modes.json"));

  const parse = (path: string | null): ModesConfig => {
    if (!path || !existsSync(path)) return {};
    try {
      return JSON.parse(readFileSync(path, "utf-8")) as ModesConfig;
    } catch {
      return {};
    }
  };

  return { ...DEFAULT_MODES, ...parse(userPath), ...parse(projectPath) };
}

export default function modeExtension(pi: ExtensionAPI) {
  let modes: ModesConfig = { ...DEFAULT_MODES };
  let activeModeName: string | undefined;
  let activeMode: ModeConfig | undefined;
  let originalState: OriginalState | undefined;

  const orderedModeNames = () => Object.keys(modes).sort();

  const updateStatus = (ctx: ExtensionContext) => {
    ctx.ui.setStatus("prelude-mode", activeModeName ? `mode:${activeModeName}` : undefined);
  };

  const restoreOriginalState = async () => {
    if (!originalState) return;
    if (originalState.model) await pi.setModel(originalState.model);
    pi.setThinkingLevel(originalState.thinkingLevel);
    pi.setActiveTools(originalState.tools);
  };

  const applyMode = async (name: string, mode: ModeConfig, ctx: ExtensionContext) => {
    if (!originalState) {
      originalState = {
        model: ctx.model,
        thinkingLevel: pi.getThinkingLevel() as ThinkingLevel,
        tools: pi.getActiveTools(),
      };
    }

    if (mode.provider && mode.model) {
      const model = ctx.modelRegistry.find(mode.provider, mode.model);
      if (!model) {
        ctx.ui.notify(`Mode '${name}': model ${mode.provider}/${mode.model} not found`, "warning");
      } else {
        const ok = await pi.setModel(model);
        if (!ok) ctx.ui.notify(`Mode '${name}': missing API key`, "warning");
      }
    }

    if (mode.thinkingLevel) pi.setThinkingLevel(mode.thinkingLevel);

    if (mode.tools && mode.tools.length > 0) {
      const allTools = new Set(pi.getAllTools().map((t) => t.name));
      const valid = mode.tools.filter((t) => allTools.has(t));
      const invalid = mode.tools.filter((t) => !allTools.has(t));
      if (invalid.length > 0) ctx.ui.notify(`Mode '${name}': unknown tools: ${invalid.join(", ")}`, "warning");
      if (valid.length > 0) pi.setActiveTools(valid);
    }

    activeModeName = name;
    activeMode = mode;
    updateStatus(ctx);
  };

  const applyByName = async (name: string, ctx: ExtensionContext) => {
    if (name === "none") {
      activeModeName = undefined;
      activeMode = undefined;
      await restoreOriginalState();
      updateStatus(ctx);
      ctx.ui.notify("Mode cleared", "info");
      return;
    }

    const mode = modes[name];
    if (!mode) {
      ctx.ui.notify(`Unknown mode '${name}'`, "error");
      return;
    }

    await applyMode(name, mode, ctx);
    ctx.ui.notify(`Mode '${name}' active`, "info");
  };

  const cycleMode = async (ctx: ExtensionContext) => {
    const names = orderedModeNames();
    if (names.length === 0) return;
    const current = activeModeName;
    const i = current ? names.indexOf(current) : -1;
    const next = names[(i + 1) % names.length];
    await applyByName(next, ctx);
  };

  const togglePlanBuild = async (ctx: ExtensionContext) => {
    const next = activeModeName === "plan" ? "build" : "plan";
    await applyByName(next, ctx);
  };

  pi.registerShortcut("ctrl+alt+u", {
    description: "Cycle prelude modes",
    handler: cycleMode,
  });

  pi.registerShortcut("ctrl+alt+p", {
    description: "Toggle plan/build mode",
    handler: togglePlanBuild,
  });

  pi.registerShortcut("ctrl+alt+r", {
    description: "Switch to review mode",
    handler: async (ctx) => applyByName("review", ctx),
  });

  pi.registerShortcut("ctrl+alt+d", {
    description: "Switch to debug mode",
    handler: async (ctx) => applyByName("debug", ctx),
  });

  pi.registerCommand("mode", {
    description: "Switch working mode",
    handler: async (args, ctx) => {
      const name = args?.trim();
      if (name) return applyByName(name, ctx);

      const names = orderedModeNames();
      const choice = await ctx.ui.select("Select mode", [...names, "none"]);
      if (!choice) return;
      await applyByName(choice, ctx);
    },
  });

  pi.on("before_agent_start", async (event) => {
    if (!activeMode?.instructions) return;
    return { systemPrompt: `${event.systemPrompt}\n\n${activeMode.instructions}` };
  });

  pi.on("session_start", async (_event, ctx) => {
    modes = loadModes(ctx.cwd);

    const restored = ctx.sessionManager
      .getEntries()
      .filter((e) => e.type === "custom" && e.customType === "mode-state")
      .pop() as { data?: { name?: string } } | undefined;

    if (restored?.data?.name && modes[restored.data.name]) {
      await applyMode(restored.data.name, modes[restored.data.name], ctx);
    }

    updateStatus(ctx);
  });

  pi.on("turn_start", async () => {
    if (activeModeName) pi.appendEntry("mode-state", { name: activeModeName });
  });
}
