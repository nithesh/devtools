import { execFileSync } from "node:child_process";
import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

const SPARK = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];

function sparkline(values: number[], width = 12): string {
  const tail = values.slice(-width);
  const chars = tail.map((v) => {
    const idx = Math.max(0, Math.min(SPARK.length - 1, Math.floor(v * SPARK.length)));
    return SPARK[idx];
  });

  if (chars.length < width) {
    return `${"▁".repeat(width - chars.length)}${chars.join("")}`;
  }

  return chars.join("");
}

function fmtK(n: number): string {
  return n < 1000 ? `${n}` : `${(n / 1000).toFixed(0)}k`;
}

function progressBar(percent: number, width = 12): string {
  const p = Math.max(0, Math.min(100, percent));
  const filled = Math.round((p / 100) * width);
  const empty = Math.max(0, width - filled);
  return `${"█".repeat(filled)}${"░".repeat(empty)}`;
}

function getMode(ctx: ExtensionContext): string {
  const e = ctx.sessionManager
    .getBranch()
    .filter((x) => x.type === "custom" && x.customType === "mode-state")
    .pop() as { data?: { name?: string } } | undefined;
  return e?.data?.name ?? "none";
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

function getCost(ctx: ExtensionContext): number {
  let cost = 0;
  for (const e of ctx.sessionManager.getBranch()) {
    if (e.type === "message" && e.message.role === "assistant") {
      const m = e.message as AssistantMessage;
      cost += m.usage?.cost?.total ?? 0;
    }
  }
  return cost;
}

export default function statusExtension(pi: ExtensionAPI) {
  const ctxHistory: number[] = [];
  let state: "idle" | "working" = "idle";

  const updateFallback = (ctx: ExtensionContext) => {
    const model = ctx.model?.id ?? "no-model";
    const mode = getMode(ctx);
    const usage = ctx.getContextUsage();
    const used = usage?.tokens ?? 0;
    const max = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
    const pct = usage?.percent != null ? Math.round(usage.percent) : max > 0 ? Math.round((used / max) * 100) : 0;
    ctx.ui.setStatus("pi.prelude.cockpit", `m:${mode} • mdl:${model} • ctx:${fmtK(used)} ${pct}%`);
  };

  const update = (ctx: ExtensionContext) => {
    const usage = ctx.getContextUsage();
    const used = usage?.tokens ?? 0;
    const max = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
    const pctNow = usage?.percent != null ? usage.percent : max > 0 ? (used / max) * 100 : 0;
    const ratio = Math.max(0, Math.min(1, pctNow / 100));
    ctxHistory.push(Math.max(0, Math.min(1, ratio)));
    if (ctxHistory.length > 12) ctxHistory.shift();

    const mode = getMode(ctx);
    const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no-model";
    const think = pi.getThinkingLevel();
    const cost = getCost(ctx);

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          const branch = footerData.getGitBranch() ?? "no-git";
          const dirty = branch !== "no-git" && gitDirty(ctx.cwd);
          const git = `${branch}${dirty ? "*" : ""}`;

          const pct = usage?.percent != null ? Math.round(usage.percent) : max > 0 ? Math.round((used / max) * 100) : 0;
          const showSpark = width >= 100;
          const spark = showSpark ? sparkline(ctxHistory, 12) : "";
          const bar = progressBar(pct, width >= 100 ? 10 : 6);

          const ctxText = `ctx ${bar} ${fmtK(used)}/${fmtK(max)} ${pct}%${spark ? ` ${spark}` : ""}`;

          const ctxStyled =
            used >= 100_000 || pct >= 85
              ? theme.fg(pct >= 85 ? "error" : "warning", ctxText)
              : theme.fg("muted", ctxText);

          const modeChip = theme.bg("selectedBg", theme.fg("text", ` mode:${mode} `));
          const gitChip = theme.fg("muted", ` git:${git} `);
          const modelChip = theme.fg("muted", ` model:${model} `);
          const thinkChip = theme.fg("muted", ` think:${think} `);
          const costChip = theme.fg("dim", ` $${cost.toFixed(2)} `);
          const stateChip = theme.fg(state === "working" ? "accent" : "dim", ` ${state} `);

          const row1 = `${modeChip} • ${gitChip}`;
          const row2Wide = `${modelChip} • ${thinkChip} • ${ctxStyled} • ${costChip} • ${stateChip}`;
          const row2Medium = `${theme.fg("muted", `mdl:${ctx.model?.id ?? "none"}`)} • ${theme.fg("muted", `th:${think}`)} • ${ctxStyled} • ${theme.fg("dim", `$${cost.toFixed(2)}`)}`;
          const row1Narrow = `${theme.fg("muted", `m:${mode}`)} • ${theme.fg("muted", `g:${git}`)} • ${ctxStyled} • ${theme.fg("dim", `$${cost.toFixed(2)}`)}`;

          if (width < 70) {
            return [truncateToWidth(row1Narrow, width)];
          }

          const second = visibleWidth(row2Wide) <= width
            ? row2Wide
            : visibleWidth(row2Medium) <= width
              ? row2Medium
              : `${ctxStyled} • ${theme.fg("dim", `$${cost.toFixed(2)}`)}`;

          return [truncateToWidth(row1, width), truncateToWidth(second, width)];
        },
      };
    });

    updateFallback(ctx);
  };

  pi.on("session_start", async (_event, ctx) => update(ctx));
  pi.on("model_select", async (_event, ctx) => update(ctx));
  pi.on("thinking_level_select", async (_event, ctx) => update(ctx));
  pi.on("turn_end", async (_event, ctx) => update(ctx));

  pi.on("agent_start", async (_event, ctx) => {
    state = "working";
    update(ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    state = "idle";
    update(ctx);
  });
}
