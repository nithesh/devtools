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
- footer failure (if induced) degrades to fallback status without breaking session

## 5) guardrails UX

- try reading `./.env` at repo root → expect block
- try reading `./.env.example` and `./.envrc` → allowed
- try editing `./.env` → blocked
- try dangerous bash (`rm -rf ./tmp`) → confirm prompt
- decline confirm → blocked reason

Check:
- block/confirm reasons are concise and actionable
- no prompt noise for benign commands (`ls`, `grep`)

## 6) web tools UX

- `web_search` with normal query (with and without `BRAVE_API_KEY`)
- if possible, simulate Brave failure and confirm fallback to `ddgr`
- `web_fetch` on known URL

Check:
- results include URL citations
- bounded/truncated output behavior is clear
- deterministic error text when backend/network is unavailable
