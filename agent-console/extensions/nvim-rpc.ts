import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const execFileAsync = promisify(execFile);

async function nvimExpr(socket: string, expr: string) {
  try {
    await execFileAsync("nvim", ["--server", socket, "--remote-expr", expr], {
      timeout: 4000,
    });
  } catch (error: any) {
    if (error?.code === "ENOENT") {
      throw new Error("nvim executable not found in PATH");
    }
    if (error?.code === "ETIMEDOUT") {
      throw new Error("neovim RPC call timed out");
    }
    throw new Error(`neovim RPC failed: ${error?.message ?? String(error)}`);
  }
}

function vimString(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "nvim_open_file",
    label: "Neovim Open File",
    description: "Open a file in the Neovim pane at an optional line.",
    parameters: Type.Object({
      path: Type.String({ description: "Path to file to open" }),
      line: Type.Optional(Type.Number({ description: "1-based line number" })),
    }),
    async execute(_toolCallId, params) {
      const socket = process.env.NVIM_LISTEN_ADDRESS;
      if (!socket) throw new Error("NVIM_LISTEN_ADDRESS is not set");

      await nvimExpr(socket, `execute('edit ' .. fnameescape(${vimString(params.path)}))`);
      if (params.line && params.line > 0) {
        await nvimExpr(socket, `cursor(${Math.floor(params.line)}, 1)`);
      }

      return {
        content: [{ type: "text", text: `Opened ${params.path}` }],
        details: { path: params.path, line: params.line ?? null },
      };
    },
  });

  pi.registerTool({
    name: "nvim_focus_tree",
    label: "Neovim Focus Tree",
    description: "Reveal/focus current file in nvim-tree.",
    parameters: Type.Object({}),
    async execute() {
      const socket = process.env.NVIM_LISTEN_ADDRESS;
      if (!socket) throw new Error("NVIM_LISTEN_ADDRESS is not set");

      await nvimExpr(socket, "execute('NvimTreeFindFile')");
      return {
        content: [{ type: "text", text: "Focused nvim-tree on current file" }],
        details: {},
      };
    },
  });

  pi.registerTool({
    name: "nvim_show_diff",
    label: "Neovim Show Diff",
    description: "Open file and show a vertical diff against provided new content.",
    parameters: Type.Object({
      path: Type.String({ description: "Base file path" }),
      newContent: Type.String({ description: "New content to diff against file" }),
    }),
    async execute(_toolCallId, params) {
      const socket = process.env.NVIM_LISTEN_ADDRESS;
      if (!socket) throw new Error("NVIM_LISTEN_ADDRESS is not set");

      const dir = await mkdtemp(join(tmpdir(), "agent-console-diff-"));
      const tempPath = join(dir, "candidate.tmp");
      await writeFile(tempPath, params.newContent, "utf8");

      await nvimExpr(socket, `execute('edit ' .. fnameescape(${vimString(params.path)}))`);
      await nvimExpr(
        socket,
        `execute('vert diffsplit ' .. fnameescape(${vimString(tempPath)}))`
      );

      return {
        content: [{ type: "text", text: `Opened diff for ${params.path}` }],
        details: { path: params.path, tempPath },
      };
    },
  });
}
