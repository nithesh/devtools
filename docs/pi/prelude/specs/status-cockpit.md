# Spec: `status.ts` cockpit polish

## Goal

Deliver a cohesive, high-signal status cockpit that feels lively (powerline-inspired) without powerline glyph clutter.

## Scope

In scope:
- full footer replacement via extension custom footer API
- 2-row default cockpit
- capsule-chip visual style (no `[...]` boxed look)
- context/cost integrated into primary status model
- width-aware narrow fallback
- optional sparkline when space allows

Out of scope:
- heavyweight animations

## Footer ownership model

- Replace built-in footer presentation with `ctx.ui.setFooter(...)` from extension.
- Treat cockpit as the single source of truth for runtime/status presentation.
- If custom footer API is unavailable in a mode/client, gracefully fall back to status-line chips (`ctx.ui.setStatus`) with compact formatting.

## Layout model

## Default (normal/wide width): 2 rows

Row 1 (identity/focus):
- mode chip (accent)
- git branch chip (+ dirty marker)
- optional task chip (if available later)

Row 2 (runtime/resources):
- model chip
- thinking chip
- context block (sparkline + absolute + percent)
- cost chip

## Narrow behavior

- Medium width: keep 2 rows, drop sparkline first.
- Narrow width: collapse to single row with compact chips.
- Ultra narrow: keep only highest-priority chips.

Priority (highest to lowest):
1. mode
2. git
3. context
4. model
5. thinking
6. cost
7. sparkline

## Visual style

- Capsule-like chips using spacing and subtle separators (`•`), not boxed brackets.
- "Pop" via selective emphasis:
  - mode chip uses accent background/foreground
  - context chip escalates color on thresholds
  - dirty marker (`*`) is warm highlight
- Keep non-critical chips muted for calm baseline.

Example (wide):
` mode:build  •  git:main*  •  model:sonnet-4-5  •  think:high  •  ctx ▁▂▃▅▆ 124k/200k 62%  •  $0.42 `

Example (narrow):
` m:build • g:main* • ctx 124k 62% • $0.42 `

## Context + threshold policy

- Absolute threshold for context rot risk:
  - `<100k` tokens: normal (no warning)
  - `>=100k` tokens: warm warning
- Capacity threshold:
  - `>=85%` of model max context: hard warning/error
- Effective severity uses max of both signals.

## Sparkline

- Show sparkline only when width allows.
- Represents recent context usage trend across last N turns.
- Drop sparkline first under width pressure.

## Data shown

Required:
- mode
- git branch + dirty marker
- model
- thinking level
- context usage (`used/max` and `%`)
- cumulative cost

Optional future:
- task summary
- budget/remaining

## Update triggers

- `session_start`
- `model_select`
- `thinking_level_select`
- `turn_end`
- mode status updates (via existing mode extension status key)
- agent lifecycle updates when needed for visual freshness (without noisy flicker)

## Acceptance criteria

1. Cockpit replaces built-in footer in supported interactive clients.
2. Default cockpit renders as 2 rows with capsule-chip style.
3. Narrow fallback preserves readability and priority ordering.
4. Context threshold colors follow the policy above.
5. Sparkline appears only when space permits.
6. Cockpit remains stable (low flicker) during normal interaction.
7. Unsupported footer environments fall back to compact status-line chips.

## Test plan

Manual smoke:
1. Launch pi via devShell.
2. Switch modes and verify mode chip emphasis.
3. Switch model + thinking and verify runtime chips.
4. Make repo dirty and verify dirty marker emphasis.
5. Generate longer context and verify threshold color transitions (<100k normal, >=100k warning, >=85% hard warning).
6. Resize terminal to medium/narrow widths and verify fallback behavior.
