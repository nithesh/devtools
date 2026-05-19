# Spec: `tools-ask.ts` (Phase 2)

## Goal

Provide a robust `ask_user` tool for structured clarification in interactive sessions.

## Scope

In scope:
- single-question prompts
- multi-question prompts
- option selection
- optional freeform answer (`other`)
- structured return payload in `details`

Out of scope:
- persistence/history browser UI
- non-interactive fallback beyond explicit error

## Tool Contract

Tool name: `ask_user`

Parameters (conceptual):

```json
{
  "questions": [
    {
      "id": "scope",
      "label": "Scope",
      "prompt": "What scope do you want?",
      "options": [
        { "value": "small", "label": "Small" },
        { "value": "medium", "label": "Medium" },
        { "value": "large", "label": "Large" }
      ],
      "allowOther": true
    }
  ]
}
```

Each question:
- `id` (required)
- `prompt` (required)
- `options` (required, non-empty)
- `label` (optional, default `Q<n>`)
- `allowOther` (optional, default `true`)

## Runtime Behavior

1. Validate interactive mode (`ctx.hasUI`)
2. Validate question structure (at least one question)
3. Render:
   - single question: option list
   - multiple questions: tabbed question flow + submit tab
4. Accept answers:
   - option selected by index
   - freeform entry if `allowOther`
5. Return both:
   - concise text summary in `content`
   - structured result in `details`

## Result Shape

`details` should include:
- `questions`: normalized question set
- `answers`: array of answers with:
  - `id`
  - `value`
  - `label`
  - `wasCustom`
  - `index?` for selected option
- `cancelled`: boolean

## Failure Modes

- non-interactive mode → error result with `cancelled: true`
- empty `questions` → error result with `cancelled: true`
- user cancels → success result with `cancelled: true` + human-readable content

## Prompt Guidance

Add tool guideline:
- use `ask_user` when requirements are ambiguous
- batch related clarification questions
- keep choices concise and mutually exclusive where possible

## Acceptance Criteria

1. `/mode plan` sessions can call `ask_user` successfully.
2. Single-question flow returns selected answer and details.
3. Multi-question flow returns complete structured details.
4. Cancelling returns `cancelled: true` without crashing.
5. Tool clearly errors in non-interactive mode.

## Test Plan (minimal)

Manual smoke:
1. Start `pi` from prelude package.
2. Ask agent to call `ask_user` with one question.
3. Ask agent to call `ask_user` with 2-3 questions.
4. Test freeform "other" input.
5. Cancel flow and verify graceful result.
6. Run `pi -p` and verify non-interactive error path.
