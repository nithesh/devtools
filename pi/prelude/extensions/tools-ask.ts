import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Editor, Key, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "typebox";

interface QuestionOption {
  value: string;
  label: string;
  description?: string;
}

interface Question {
  id: string;
  label?: string;
  prompt: string;
  options: QuestionOption[];
  allowOther?: boolean;
}

interface Answer {
  id: string;
  value: string;
  label: string;
  wasCustom: boolean;
  index?: number;
}

interface AskDetails {
  questions: Array<Question & { label: string; allowOther: boolean }>;
  answers: Answer[];
  cancelled: boolean;
}

const OptionSchema = Type.Object({
  value: Type.String({ description: "The returned value" }),
  label: Type.String({ description: "The displayed option label" }),
  description: Type.Optional(Type.String({ description: "Optional extra info" })),
});

const QuestionSchema = Type.Object({
  id: Type.String({ description: "Unique question id" }),
  label: Type.Optional(Type.String({ description: "Short label for this question" })),
  prompt: Type.String({ description: "Question prompt" }),
  options: Type.Array(OptionSchema, { description: "Selectable options" }),
  allowOther: Type.Optional(Type.Boolean({ description: "Allow freeform answer" })),
});

const ParamsSchema = Type.Object({
  questions: Type.Array(QuestionSchema, { description: "Questions to ask" }),
});

function errorResult(message: string, questions: AskDetails["questions"] = []) {
  return {
    content: [{ type: "text" as const, text: message }],
    details: { questions, answers: [], cancelled: true } satisfies AskDetails,
  };
}

export default function toolsAsk(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user",
    label: "Ask User",
    description: "Ask one or multiple clarification questions and return structured answers.",
    promptSnippet: "Collect structured clarification from the user with one or multiple choice questions.",
    promptGuidelines: [
      "Use ask_user when requirements are ambiguous or trade-offs need user input.",
      "Batch related clarification questions in one ask_user call instead of many one-off questions.",
    ],
    parameters: ParamsSchema,

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (!ctx.hasUI) return errorResult("Error: ask_user requires interactive mode.");
      if (!params.questions || params.questions.length === 0) {
        return errorResult("Error: questions must contain at least one question.");
      }

      const questions = params.questions.map((q, i) => ({
        ...q,
        label: q.label ?? `Q${i + 1}`,
        allowOther: q.allowOther !== false,
      }));

      for (const q of questions) {
        if (!q.options || q.options.length === 0) return errorResult(`Error: question '${q.id}' has no options.`, questions);
      }

      const result = await ctx.ui.custom<AskDetails>((tui, theme, _kb, done) => {
        const answers = new Map<string, Answer>();
        let qIndex = 0;
        let optionIndex = 0;
        let inputMode = false;
        let confirmCancel = false;
        let confirmPartial = false;
        let confirmChoice = 1; // 0 submit partial, 1 go back

        const editor = new Editor(tui, {
          borderColor: (s) => theme.fg("accent", s),
          selectList: {
            selectedPrefix: (t) => theme.fg("accent", t),
            selectedText: (t) => theme.fg("accent", t),
            description: (t) => theme.fg("muted", t),
            scrollInfo: (t) => theme.fg("dim", t),
            noMatch: (t) => theme.fg("warning", t),
          },
        });
        editor.setText(answers.get(questions[qIndex].id)?.wasCustom ? answers.get(questions[qIndex].id)?.value ?? "" : "");

        const getOptions = (idx: number) => {
          const q = questions[idx];
          return [...q.options.map((o) => ({ ...o, isOther: false })), ...(q.allowOther ? [{ value: "__other__", label: "Other", isOther: true }] : [])];
        };

        const submit = (cancelled: boolean) => {
          done({ questions, answers: Array.from(answers.values()), cancelled });
        };

        const unanswered = () => questions.filter((q) => !answers.has(q.id));

        const maybeSubmit = () => {
          if (unanswered().length === 0) return submit(false);
          confirmPartial = true;
          confirmChoice = 1;
        };

        const handleInput = (data: string) => {
          const options = getOptions(qIndex);
          const q = questions[qIndex];

          if (confirmCancel) {
            if (matchesKey(data, Key.left) || matchesKey(data, Key.right) || matchesKey(data, Key.tab) || matchesKey(data, Key.shift("tab"))) {
              confirmChoice = confirmChoice === 0 ? 1 : 0;
              tui.requestRender();
              return;
            }
            if (matchesKey(data, Key.enter)) {
              if (confirmChoice === 0) submit(true);
              else confirmCancel = false;
              tui.requestRender();
              return;
            }
            return;
          }

          if (confirmPartial) {
            if (matchesKey(data, Key.left) || matchesKey(data, Key.right) || matchesKey(data, Key.tab) || matchesKey(data, Key.shift("tab"))) {
              confirmChoice = confirmChoice === 0 ? 1 : 0;
              tui.requestRender();
              return;
            }
            if (matchesKey(data, Key.enter)) {
              if (confirmChoice === 0) submit(false);
              else confirmPartial = false;
              tui.requestRender();
              return;
            }
            if (matchesKey(data, Key.escape)) {
              confirmPartial = false;
              tui.requestRender();
            }
            return;
          }

          if (inputMode) {
            if (matchesKey(data, Key.escape)) {
              inputMode = false;
              tui.requestRender();
              return;
            }
            if (matchesKey(data, Key.enter)) {
              const value = editor.getText().trim() || "(empty)";
              answers.set(q.id, { id: q.id, value, label: value, wasCustom: true });
              inputMode = false;
              if (qIndex < questions.length - 1) qIndex += 1;
              optionIndex = 0;
              tui.requestRender();
              return;
            }
            editor.handleInput(data);
            tui.requestRender();
            return;
          }

          if (matchesKey(data, Key.up)) {
            optionIndex = Math.max(0, optionIndex - 1);
            tui.requestRender();
            return;
          }

          if (matchesKey(data, Key.down)) {
            optionIndex = Math.min(options.length - 1, optionIndex + 1);
            tui.requestRender();
            return;
          }

          if (matchesKey(data, Key.left) || matchesKey(data, Key.shift("tab"))) {
            qIndex = (qIndex - 1 + questions.length) % questions.length;
            optionIndex = 0;
            editor.setText(answers.get(questions[qIndex].id)?.wasCustom ? answers.get(questions[qIndex].id)?.value ?? "" : "");
            tui.requestRender();
            return;
          }

          if (matchesKey(data, Key.right) || matchesKey(data, Key.tab)) {
            qIndex = (qIndex + 1) % questions.length;
            optionIndex = 0;
            editor.setText(answers.get(questions[qIndex].id)?.wasCustom ? answers.get(questions[qIndex].id)?.value ?? "" : "");
            tui.requestRender();
            return;
          }

          if (matchesKey(data, Key.ctrl("enter"))) {
            maybeSubmit();
            tui.requestRender();
            return;
          }

          if (matchesKey(data, Key.escape)) {
            if (answers.size > 0) {
              confirmCancel = true;
              confirmChoice = 1;
            } else {
              submit(true);
            }
            tui.requestRender();
            return;
          }

          if (matchesKey(data, Key.enter)) {
            const selected = options[optionIndex];
            if (!selected) return;
            if (selected.isOther) {
              inputMode = true;
              editor.setText(answers.get(q.id)?.wasCustom ? answers.get(q.id)?.value ?? "" : "");
              tui.requestRender();
              return;
            }

            answers.set(q.id, {
              id: q.id,
              value: selected.value,
              label: selected.label,
              wasCustom: false,
              index: optionIndex + 1,
            });
            if (qIndex < questions.length - 1) qIndex += 1;
            optionIndex = 0;
            editor.setText(answers.get(questions[qIndex].id)?.wasCustom ? answers.get(questions[qIndex].id)?.value ?? "" : "");
            tui.requestRender();
          }
        };

        return {
          handleInput,
          invalidate() {},
          render(width: number) {
            const q = questions[qIndex];
            const opts = getOptions(qIndex);
            const lines: string[] = [];

            const tabs = questions
              .map((qq, idx) => {
                const active = idx === qIndex;
                const answered = answers.has(qq.id) ? "●" : "○";
                const base = `${answered} ${qq.label}`;
                return active ? theme.bg("selectedBg", theme.fg("text", ` ${base} `)) : theme.fg("muted", ` ${base} `);
              })
              .join(" ");

            lines.push(truncateToWidth(tabs, width));
            lines.push("");
            lines.push(truncateToWidth(theme.fg("text", `${q.label}: ${q.prompt}`), width));
            lines.push("");

            const currentCustom = answers.get(q.id)?.wasCustom ? answers.get(q.id)?.value : undefined;

            opts.forEach((opt, idx) => {
              const selected = idx === optionIndex;
              const prefix = selected ? theme.fg("accent", "> ") : "  ";
              const label = opt.isOther
                ? currentCustom
                  ? `Other: ${currentCustom}`
                  : "Other (type custom answer)"
                : `${idx + 1}. ${opt.label}`;
              const styled = selected ? theme.fg("accent", label) : label;
              lines.push(truncateToWidth(prefix + styled, width));
              if (!opt.isOther && opt.description) lines.push(truncateToWidth(`    ${theme.fg("muted", opt.description)}`, width));
            });

            if (inputMode) {
              lines.push("");
              lines.push(truncateToWidth(theme.fg("muted", "Editing Other inline. Enter to save, Esc to cancel."), width));
              lines.push(truncateToWidth(`  ${theme.fg("accent", editor.getText() || "")}`, width));
            }

            lines.push("");
            lines.push(theme.fg("muted", "Answers:"));
            if (answers.size === 0) {
              lines.push(theme.fg("dim", "  (none yet)"));
            } else {
              for (const ans of answers.values()) {
                const qLabel = questions.find((qq) => qq.id === ans.id)?.label ?? ans.id;
                const text = ans.wasCustom ? `${qLabel}: (custom) ${ans.label}` : `${qLabel}: ${ans.label}`;
                lines.push(truncateToWidth(`  ${text}`, width));
              }
            }

            if (confirmPartial) {
              const missing = unanswered().map((qq) => qq.label).join(", ");
              const left = confirmChoice === 0 ? theme.bg("selectedBg", " Submit partial ") : " Submit partial ";
              const right = confirmChoice === 1 ? theme.bg("selectedBg", " Go back ") : " Go back ";
              lines.push("");
              lines.push(theme.fg("warning", `Unanswered: ${missing}`));
              lines.push(`${left}  ${right}`);
            }

            if (confirmCancel) {
              const left = confirmChoice === 0 ? theme.bg("selectedBg", " Cancel flow ") : " Cancel flow ";
              const right = confirmChoice === 1 ? theme.bg("selectedBg", " Continue ") : " Continue ";
              lines.push("");
              lines.push(theme.fg("warning", "Cancel and discard current questionnaire?"));
              lines.push(`${left}  ${right}`);
            }

            lines.push("");
            lines.push(
              theme.fg(
                "dim",
                "↑↓ option • ←/→ or Tab nav • Enter select • Ctrl+Enter submit • Esc cancel",
              ),
            );
            return lines.map((l) => truncateToWidth(l, width));
          },
        };
      });

      const lines = result.answers.length
        ? result.answers.map((a) => {
            const qLabel = questions.find((q) => q.id === a.id)?.label ?? a.id;
            return a.wasCustom
              ? `${qLabel}: user wrote '${a.label}'`
              : `${qLabel}: user selected ${a.index}. ${a.label}`;
          })
        : [result.cancelled ? "User cancelled question flow." : "No answers provided."];

      return {
        content: [{ type: "text", text: lines.join("\n") }],
        details: result,
      };
    },
  });
}
