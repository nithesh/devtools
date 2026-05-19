# Spec: `tools-ask` UX Polish (Phase 2.1)

## Goal

Make `ask_user` feel fast, keyboard-first, and visually clear while preserving structured outputs.

## Problems in current UX

- "Other" answer uses a separate prompt and hides context.
- Next/previous via list items feels clunky.
- Partial submit behavior is unclear.
- Multi-question orientation is weak (no strong progress/tabs).

## UX Requirements

## 1) Inline "Other" input

When user selects "Other":
- Keep options visible.
- Open inline input editor below options.
- `Enter` saves custom answer for current question.
- `Esc` cancels inline input and returns to options.

## 2) Keyboard-first navigation

- `↑/↓`: move option cursor in current question
- `←/→` or `Tab`/`Shift+Tab`: move between questions
- `Enter`: select option / confirm inline custom answer
- `Ctrl+Enter`: attempt submit
- `Esc`: cancel whole questionnaire (with confirm if any answers exist)

No next/previous pseudo-options in the option list.

## 3) Partial submit behavior

On submit with unanswered questions:
- Show confirm dialog with missing labels/ids.
- Choices:
  - "Submit partial"
  - "Go back"

Default should be "Go back".

## 4) Multi-question layout

Show top tab/progress line:
- Question chips: active + answered state
- Example: `[● Scope] [○ Style] [● Commit]`

Legend:
- `●` answered
- `○` unanswered

## 5) Answer preview

Show compact summary section:
- Current answers by label/id
- Mark custom answers

## 6) Visual style

- Muted defaults, strong accent for selection
- Stable footer with key help
- Compact layout with minimal flicker

## Data/Behavior Contract

No schema changes required.
Return payload remains:
- `details.questions`
- `details.answers`
- `details.cancelled`

## Acceptance Criteria

1. Users can navigate all questions without selecting answers.
2. Inline custom answer works without losing option context.
3. Submit with missing answers triggers partial-submit confirmation.
4. Full keyboard flow works without mouse.
5. Result payload remains backward-compatible.

## Implementation Plan

1. Replace per-question `ctx.ui.select` loop with custom `ctx.ui.custom` component.
2. Reuse ideas from pi example `questionnaire.ts`:
   - tabbed multi-question interaction
   - inline editor mode
   - unified input handling
3. Keep current tool schema and output shape.
4. Add a manual smoke checklist in this spec after implementation.

## Open choices

- Should single-question flow use same custom UI (recommended: yes, for consistency)?
- Should `Esc` always cancel immediately, or confirm when answers exist (recommended: confirm)?
