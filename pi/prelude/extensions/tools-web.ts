import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";

const execFileAsync = promisify(execFile);

const WebSearchParams = Type.Object({
  query: Type.String({ description: "Search query" }),
  limit: Type.Optional(Type.Number({ description: "Result limit (default 5, max 10)" })),
});

const WebFetchParams = Type.Object({
  url: Type.String({ description: "URL to fetch" }),
  maxBytes: Type.Optional(Type.Number({ description: "Max output bytes (default 16000, max 64000)" })),
});

function truncateBytes(text: string, maxBytes: number): { text: string; truncated: boolean } {
  const buf = Buffer.from(text, "utf8");
  if (buf.length <= maxBytes) return { text, truncated: false };
  return { text: buf.subarray(0, maxBytes).toString("utf8"), truncated: true };
}

function shortError(err: unknown): string {
  if (err && typeof err === "object") {
    const e = err as { stderr?: string; message?: string };
    return (e.stderr || e.message || "Unknown error").trim().slice(0, 500);
  }
  return String(err);
}

export default function toolsWeb(pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description: "Search the web for docs/news/pages. Uses Brave API when BRAVE_API_KEY is set, else ddgr.",
    parameters: WebSearchParams,
    promptSnippet: "Search the web and return concise cited results.",

    async execute(_toolCallId, params) {
      const query = params.query?.trim();
      if (!query) {
        return {
          content: [{ type: "text", text: "Error: query is required." }],
          isError: true,
        };
      }

      const limit = Math.min(Math.max(Math.floor(params.limit ?? 5), 1), 10);
      const braveKey = process.env.BRAVE_API_KEY?.trim();
      const attempted: string[] = [];
      let lastError: string | null = null;

      if (braveKey) {
        attempted.push("brave");
        try {
          const url = new URL("https://api.search.brave.com/res/v1/web/search");
          url.searchParams.set("q", query);
          url.searchParams.set("count", String(limit));

          const res = await fetch(url, {
            headers: {
              Accept: "application/json",
              "X-Subscription-Token": braveKey,
            },
          });

          if (res.ok) {
            const data = (await res.json()) as {
              web?: { results?: Array<{ title?: string; url?: string; description?: string }> };
            };

            const rows = data.web?.results ?? [];
            if (rows.length === 0) {
              return {
                content: [{ type: "text", text: "No search results found." }],
                details: { backend: "brave", query, limit, count: 0 },
              };
            }

            const lines = rows.slice(0, limit).map((r, i) => {
              const title = r.title?.trim() || "(no title)";
              const pageUrl = r.url?.trim() || "(no url)";
              const snippet = r.description?.trim();
              return `${i + 1}. ${title}\n   ${pageUrl}${snippet ? `\n   ${snippet}` : ""}`;
            });

            return {
              content: [{ type: "text", text: lines.join("\n\n") }],
              details: { backend: "brave", query, limit, count: rows.length },
            };
          }

          lastError = `Brave search failed (${res.status})`;
        } catch (err) {
          lastError = `Brave search failed: ${shortError(err)}`;
        }
      }

      attempted.push("ddgr");
      try {
        const { stdout } = await execFileAsync("ddgr", ["--json", "--np", "-n", String(limit), query], {
          maxBuffer: 1024 * 1024,
        });

        let rows: Array<{ title?: string; url?: string; abstract?: string }> = [];
        try {
          rows = JSON.parse(stdout);
        } catch {
          return {
            content: [{ type: "text", text: "Error: web_search backend returned invalid JSON." }],
            isError: true,
            details: { attempted, query, limit },
          };
        }

        if (!Array.isArray(rows) || rows.length === 0) {
          return {
            content: [{ type: "text", text: "No search results found." }],
            details: { backend: "ddgr", query, limit, count: 0, attempted },
          };
        }

        const lines = rows.slice(0, limit).map((r, i) => {
          const title = r.title?.trim() || "(no title)";
          const pageUrl = r.url?.trim() || "(no url)";
          const snippet = r.abstract?.trim();
          return `${i + 1}. ${title}\n   ${pageUrl}${snippet ? `\n   ${snippet}` : ""}`;
        });

        return {
          content: [{ type: "text", text: lines.join("\n\n") }],
          details: { backend: "ddgr", query, limit, count: rows.length, attempted, fallbackFrom: braveKey ? "brave" : null },
        };
      } catch (err) {
        const ddgrErr = shortError(err);
        return {
          content: [
            {
              type: "text",
              text: `Error: web_search failed. Attempted backends: ${attempted.join(" -> ")}.\n${lastError ? `${lastError}\n` : ""}${ddgrErr}`,
            },
          ],
          isError: true,
          details: { backend: "ddgr", query, limit, attempted, lastError },
        };
      }
    },
  });

  pi.registerTool({
    name: "web_fetch",
    label: "Web Fetch",
    description: "Fetch URL content with bounded output.",
    parameters: WebFetchParams,
    promptSnippet: "Fetch and summarize a URL with bounded output.",

    async execute(_toolCallId, params) {
      const url = params.url?.trim();
      if (!url) {
        return {
          content: [{ type: "text", text: "Error: url is required." }],
          isError: true,
        };
      }

      const maxBytes = Math.min(Math.max(Math.floor(params.maxBytes ?? 16000), 512), 64000);

      try {
        const { stdout } = await execFileAsync(
          "curl",
          ["-L", "--silent", "--show-error", "--max-time", "20", url],
          { maxBuffer: 2 * 1024 * 1024 },
        );

        const normalized = stdout.replace(/\r\n/g, "\n");
        const { text, truncated } = truncateBytes(normalized, maxBytes);

        return {
          content: [{ type: "text", text: `Source: ${url}\n\n${text}${truncated ? "\n\n[truncated]" : ""}` }],
          details: { url, maxBytes, truncated },
        };
      } catch (err) {
        return {
          content: [
            {
              type: "text",
              text: "Error: web_fetch failed. Ensure `curl` is installed and URL is reachable.\n" + shortError(err),
            },
          ],
          isError: true,
          details: { url, maxBytes },
        };
      }
    },
  });
}
