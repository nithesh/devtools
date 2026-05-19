# Spec: `tools-todo.ts` (Phase 2.2)

## Goal

Add a branch-aware `todo` tool for lightweight task tracking during a session.

## Tool

- `todo`

## Actions

- `list`
- `add` (requires `text`)
- `update` (requires `id`, optional `text`)
- `done` (requires `id`, optional `done` boolean)
- `clear`

## Requirements

1. State reconstructed from `todo` tool result `details` on session start/tree navigation.
2. No external file/db state.
3. Human-readable content + structured `details` on every action.
4. Graceful errors for missing ids/fields.

## Acceptance

- Add/list/update/done/clear works.
- State follows branch/time travel.
- Errors are explicit and non-fatal.
