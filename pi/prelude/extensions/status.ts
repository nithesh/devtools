import { execFileSync } from "node:child_process";
import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

const SPARK = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];

function sparkline(values: number[], width = 10): string {
  const tail = values.slice(-width);
  const chars = tail.map((v) => {
    const idx = Math.max(0, Math.min(SPARK.length - 1, Math.floor(v * SPARK.length)));
    return SPARK[idx];
  });
  return `${"▁".repeat(Math.max(0, width - chars.length))}${chars.join("")}`;
}

function fmtK(n: number): string {
  return n < 1000 ? `${n}` : `${(n / 1000).toFixed(0)}k`;
}

function progressBar(percent: number, width = 10): string {
  const p = Math.max(0, Math.min(100, percent));
  const filled = Math.round((p / 100) * width);
  return `${"█".repeat(filled)}${"░".repeat(Math.max(0, width - filled))}`;
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
  const history: number[] = [];
  let footerDisabled = false;
  let errorNotified = false;

  const fallbackStatus = (ctx: ExtensionContext, used: number, max: number, pct: number) => {
    const mode = getMode(ctx);
    const model = ctx.model?.id ?? "no-model";
    ctx.ui.setStatus("pi.prelude.cockpit", `m:${mode} • mdl:${model} • ctx:${fmtK(used)}/${fmtK(max)} ${pct}%`);
  };

  const disableFooter = (ctx: ExtensionContext, reason: string) => {
    footerDisabled = true;
    ctx.ui.setFooter(undefined);
    if (!errorNotified) {
      errorNotified = true;
      ctx.ui.notify(`Cockpit footer disabled: ${reason}`, "warning");
    }
  };

  const update = (ctx: ExtensionContext) => {
    const usage = ctx.getContextUsage();
    const used = usage?.tokens ?? 0;
    const max = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
    const pct = usage?.percent != null ? Math.round(usage.percent) : max > 0 ? Math.round((used / max) * 100) : 0;
    const ratio = Math.max(0, Math.min(1, pct / 100));

    history.push(ratio);
    if (history.length > 12) history.shift();

    fallbackStatus(ctx, used, max, pct);

    if (footerDisabled) return;

    try {
      ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          try {
            const branch = footerData.getGitBranch() ?? "no-git";
            const git = `${branch}${branch !== "no-git" && gitDirty(ctx.cwd) ? "*" : ""}`;

            const rawStatuses = footerData.getExtensionStatuses() as unknown;
            const statuses = Array.isArray(rawStatuses)
              ? rawStatuses
              : rawStatuses && typeof rawStatuses === "object"
                ? Object.entries(rawStatuses as Record<string, unknown>).map(([key, value]) => {
                    if (value && typeof value === "object") {
                      const v = value as { key?: string; text?: string };
                      return { key: v.key ?? key, text: v.text ?? "" };
                    }
                    return { key, text: String(value ?? "") };
                  })
                : [];

            const statusText = statuses
              .filter((s) => s.key !== "pi.prelude.cockpit")
              .map((s) => s.text)
              .filter(Boolean)
              .join(" ");

            const bar = progressBar(pct, width >= 100 ? 10 : 6);
            const showSpark = width >= 100;
            const spark = showSpark ? sparkline(history, 10) : "";
            const ctxText = `ctx ${bar} ${fmtK(used)}/${fmtK(max)} ${pct}%${spark ? ` ${spark}` : ""}`;

            const ctxStyled =
              pct >= 85
                ? theme.fg("error", ctxText)
                : used >= 100_000
                  ? theme.fg("warning", ctxText)
                  : theme.fg("muted", ctxText);

            const mode = getMode(ctx);
            const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no-model";
            const think = pi.getThinkingLevel();
            const cost = getCost(ctx);

            const modeChip = theme.bg("selectedBg", theme.fg("text", ` mode:${mode} `));
            const gitChip = theme.fg("muted", ` git:${git} `);
            const modelChip = theme.fg("muted", ` model:${model} `);
            const thinkChip = theme.fg("muted", ` think:${think} `);
            const costChip = theme.fg("dim", ` $${cost.toFixed(2)} `);
            const rightStatus = statusText ? theme.fg("dim", statusText) : "";

            const row1Left = `${modeChip} • ${gitChip} • ${modelChip}`;
            if (width < 70) {
              const compact = `${theme.fg("muted", `m:${mode}`)} • ${theme.fg("muted", `g:${git}`)} • ${ctxStyled} • ${theme.fg("dim", `$${cost.toFixed(2)}`)}`;
              return [truncateToWidth(compact, width)];
            }

            const row2Wide = `${thinkChip} • ${ctxStyled} • ${costChip}`;
            const row2Medium = `${theme.fg("muted", `th:${think}`)} • ${ctxStyled} • ${theme.fg("dim", `$${cost.toFixed(2)}`)}`;
            const row2 = visibleWidth(row2Wide) <= width ? row2Wide : row2Medium;

            if (!rightStatus) {
              return [truncateToWidth(row1Left, width), truncateToWidth(row2, width)];
            }

            const pad = Math.max(1, width - visibleWidth(row1Left) - visibleWidth(rightStatus));
            const row1 = truncateToWidth(`${row1Left}${" ".repeat(pad)}${rightStatus}`, width);
            return [row1, truncateToWidth(row2, width)];
          } catch {
            return [truncateToWidth(theme.fg("warning", "cockpit unavailable, using fallback status"), width)];
          }
        },
      };
    });
    } catch {
      disableFooter(ctx, "setFooter failed");
    }
  };

  pi.on("session_start", async (_event, ctx) => update(ctx));
  pi.on("model_select", async (_event, ctx) => update(ctx));
  pi.on("thinking_level_select", async (_event, ctx) => update(ctx));
  pi.on("turn_end", async (_event, ctx) => update(ctx));
  pi.on("agent_start", async (_event, ctx) => update(ctx));
  pi.on("agent_end", async (_event, ctx) => update(ctx));
}
