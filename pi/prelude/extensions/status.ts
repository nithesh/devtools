import { execFileSync } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

function gitBranch(cwd: string): string | undefined {
  try {
    return execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd, encoding: "utf8" }).trim();
  } catch {
    return undefined;
  }
}

function gitDirty(cwd: string): boolean {
  try {
    execFileSync("git", ["diff", "--quiet"], { cwd });
    execFileSync("git", ["diff", "--cached", "--quiet"], { cwd });
    return false;
  } catch {
    return true;
  }
}

export default function statusExtension(pi: ExtensionAPI) {
  const update = (ctx: ExtensionContext) => {
    const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "none";
    const thinking = pi.getThinkingLevel();
    const branch = gitBranch(ctx.cwd);
    const dirty = branch && gitDirty(ctx.cwd) ? "*" : "";
    const git = branch ? `${branch}${dirty}` : "no-git";
    ctx.ui.setStatus("prelude-runtime", `model:${model} • think:${thinking} • git:${git}`);
  };

  pi.on("session_start", async (_event, ctx) => update(ctx));
  pi.on("model_select", async (_event, ctx) => update(ctx));
  pi.on("thinking_level_select", async (_event, ctx) => update(ctx));
  pi.on("turn_end", async (_event, ctx) => update(ctx));

  pi.on("agent_start", async (_event, ctx) => {
    ctx.ui.setStatus("prelude-state", "working");
  });

  pi.on("agent_end", async (_event, ctx) => {
    ctx.ui.setStatus("prelude-state", "idle");
    update(ctx);
  });
}
