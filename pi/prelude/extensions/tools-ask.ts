import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
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
      if (!ctx.hasUI) {
        return errorResult("Error: ask_user requires interactive mode.");
      }

      if (!params.questions || params.questions.length === 0) {
        return errorResult("Error: questions must contain at least one question.");
      }

      const questions = params.questions.map((q, i) => ({
        ...q,
        label: q.label ?? `Q${i + 1}`,
        allowOther: q.allowOther !== false,
      }));

      const answers = new Map<string, Answer>();
      let i = 0;

      while (true) {
        const q = questions[i];
        if (!q.options || q.options.length === 0) {
          return errorResult(`Error: question '${q.id}' has no options.`, questions);
        }

        const optionLabels = q.options.map((opt, idx) => `${idx + 1}. ${opt.label}`);
        const otherLabel = "Other (type custom answer)";
        const prevLabel = "← Previous question";
        const nextLabel = "→ Next question";
        const submitLabel = "✓ Submit answers";

        const selectItems = [
          ...optionLabels,
          ...(q.allowOther ? [otherLabel] : []),
          ...(i > 0 ? [prevLabel] : []),
          ...(i < questions.length - 1 ? [nextLabel] : []),
          submitLabel,
        ];

        const answeredCount = Array.from(answers.keys()).length;
        const picked = await ctx.ui.select(
          `${q.label} (${i + 1}/${questions.length}, answered ${answeredCount}/${questions.length}): ${q.prompt}`,
          selectItems,
        );

        if (!picked) {
          return {
            content: [{ type: "text", text: "User cancelled question flow." }],
            details: { questions, answers: Array.from(answers.values()), cancelled: true } satisfies AskDetails,
          };
        }

        if (picked === prevLabel) {
          i = Math.max(0, i - 1);
          continue;
        }

        if (picked === nextLabel) {
          i = Math.min(questions.length - 1, i + 1);
          continue;
        }

        if (picked === submitLabel) {
          const finalized = Array.from(answers.values());
          const lines = finalized.length
            ? finalized.map((a) =>
                a.wasCustom ? `${a.id}: user wrote '${a.label}'` : `${a.id}: user selected ${a.index}. ${a.label}`,
              )
            : ["No answers provided."];

          return {
            content: [{ type: "text", text: lines.join("\n") }],
            details: { questions, answers: finalized, cancelled: false } satisfies AskDetails,
          };
        }

        if (picked === otherLabel) {
          const custom = await ctx.ui.input(`${q.label}: Enter custom answer`);
          if (custom === null) continue;
          const value = custom.trim() || "(empty)";
          answers.set(q.id, { id: q.id, value, label: value, wasCustom: true });
          if (i < questions.length - 1) i += 1;
          continue;
        }

        const index = optionLabels.indexOf(picked);
        const selected = q.options[index];
        if (index < 0 || !selected) {
          return errorResult(`Error: invalid selection for question '${q.id}'.`, questions);
        }

        answers.set(q.id, {
          id: q.id,
          value: selected.value,
          label: selected.label,
          wasCustom: false,
          index: index + 1,
        });

        if (i < questions.length - 1) i += 1;
      }
    },
  });
}
