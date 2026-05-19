import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";

interface TodoItem {
  id: number;
  text: string;
  done: boolean;
}

interface TodoDetails {
  action: "list" | "add" | "update" | "done" | "clear";
  todos: TodoItem[];
  nextId: number;
  error?: string;
}

const Params = Type.Object({
  action: StringEnum(["list", "add", "update", "done", "clear"] as const),
  id: Type.Optional(Type.Number()),
  text: Type.Optional(Type.String()),
  done: Type.Optional(Type.Boolean()),
});

export default function toolsTodo(pi: ExtensionAPI) {
  let todos: TodoItem[] = [];
  let nextId = 1;

  const snapshot = (action: TodoDetails["action"], error?: string): TodoDetails => ({
    action,
    todos: [...todos],
    nextId,
    ...(error ? { error } : {}),
  });

  const reconstruct = (ctx: ExtensionContext) => {
    todos = [];
    nextId = 1;

    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message") continue;
      const msg = entry.message;
      if (msg.role !== "toolResult" || msg.toolName !== "todo") continue;
      const d = msg.details as TodoDetails | undefined;
      if (!d) continue;
      todos = d.todos ?? [];
      nextId = d.nextId ?? 1;
    }
  };

  pi.on("session_start", async (_event, ctx) => reconstruct(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstruct(ctx));

  pi.registerTool({
    name: "todo",
    label: "Todo",
    description: "Manage lightweight branch-aware todos",
    promptSnippet: "Track and update a concise task list across the current session branch.",
    parameters: Params,

    async execute(_toolCallId, params) {
      switch (params.action) {
        case "list": {
          const text = todos.length ? todos.map((t) => `[${t.done ? "x" : " "}] #${t.id} ${t.text}`).join("\n") : "No todos.";
          return { content: [{ type: "text", text }], details: snapshot("list") };
        }
        case "add": {
          if (!params.text?.trim()) {
            return { content: [{ type: "text", text: "Error: text is required for add." }], details: snapshot("add", "text required") };
          }
          const item: TodoItem = { id: nextId++, text: params.text.trim(), done: false };
          todos.push(item);
          return { content: [{ type: "text", text: `Added todo #${item.id}: ${item.text}` }], details: snapshot("add") };
        }
        case "update": {
          if (params.id === undefined) {
            return { content: [{ type: "text", text: "Error: id is required for update." }], details: snapshot("update", "id required") };
          }
          const item = todos.find((t) => t.id === params.id);
          if (!item) {
            return { content: [{ type: "text", text: `Error: todo #${params.id} not found.` }], details: snapshot("update", "not found") };
          }
          if (params.text?.trim()) item.text = params.text.trim();
          return { content: [{ type: "text", text: `Updated todo #${item.id}: ${item.text}` }], details: snapshot("update") };
        }
        case "done": {
          if (params.id === undefined) {
            return { content: [{ type: "text", text: "Error: id is required for done." }], details: snapshot("done", "id required") };
          }
          const item = todos.find((t) => t.id === params.id);
          if (!item) {
            return { content: [{ type: "text", text: `Error: todo #${params.id} not found.` }], details: snapshot("done", "not found") };
          }
          item.done = params.done ?? !item.done;
          return { content: [{ type: "text", text: `Todo #${item.id} marked ${item.done ? "done" : "not done"}.` }], details: snapshot("done") };
        }
        case "clear": {
          const count = todos.length;
          todos = [];
          nextId = 1;
          return { content: [{ type: "text", text: `Cleared ${count} todos.` }], details: snapshot("clear") };
        }
      }
    },
  });
}
