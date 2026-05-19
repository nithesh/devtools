# pi/prelude smoke (manual UX-only)

Most contract/build checks are automated in `nix flake check` (`checks.pi-prelude-contract`, `checks.pi-prelude-build`).

Use this short manual pass for TUI/interaction quality only.

## 1) Launch

```bash
nix develop
pi
```

## 2) Mode UX

- `/mode plan`, `/mode build`
- `Ctrl+Alt+U` cycle
- `Ctrl+Alt+P` plan/build toggle

Check: fast switches, no noisy glitches, status updates correctly.

## 3) ask_user UX

Trigger `ask_user` with 2-3 questions (`allowOther: true`).

Check:
- `Tab`/`Shift+Tab` and arrows navigate questions/options smoothly
- inline **Other** edit keeps context visible
- `Ctrl+Enter` submit flow is clear
- partial-submit warning is understandable

## 4) status UX

Switch model/thinking and run a prompt.

Check:
- status readability (mode/model/git)
- working → idle transitions feel stable
