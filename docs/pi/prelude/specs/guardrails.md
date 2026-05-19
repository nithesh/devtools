# Spec: `guardrails.ts` (Phase 3)

## Goal

Add lightweight safety controls that reduce accidental destructive actions while keeping flow fast.

## Scope

In scope:
- pre-execution checks for risky tool calls
- protected path policy for file-modifying tools
- dangerous shell command confirmation/blocking
- clear user-facing reasons when blocked

Out of scope:
- full sandboxing
- policy engines / role-based auth
- per-command approval history storage

## Events/hooks

- `tool_call` hook

Primary targets:
- `read`
- `write`
- `edit`
- `bash`

## Policy model

## 1) Protected path write policy

Protect by default with separate read/write lists.

Read-protected defaults:
- `/.env` (exact file)
- private keys / credentials (`**/id_rsa`, `**/id_ed25519`, `**/*.pem`, `**/*.key`, `**/*.p12`, `**/*.pfx`, `**/.aws/credentials`, `**/.npmrc`, `**/.docker/config.json`)

Read-allow defaults:
- `/.env.example`
- `/.envrc`

Write-protected defaults:
- `/.env`
- `/.git/**`
- `**/node_modules/**`
- build artifacts (`**/dist/**`, `**/build/**`, `**/.next/**`, `**/target/**`)

Behavior:
- if `read.path` matches protected read pattern and not allow pattern → block
- if `write.path`/`edit.path` matches protected write pattern and not allow pattern → block
- return reason message with matched pattern

Config:
- global defaults in extension
- optional project overrides via nearest-upward `.pi/prelude/guardrails.json` discovery from `ctx.cwd`
- optional user override via `${getAgentDir()}/prelude/guardrails.json`
- precedence: project override > user override > defaults
  - `protectedReadPatterns: string[]`
  - `allowReadPatterns: string[]` (higher priority allowlist)
  - `protectedWritePatterns: string[]`
  - `allowWritePatterns: string[]` (higher priority allowlist)

Pattern semantics (gitignore-like):
- `*` and `**` globs are supported.
- Patterns starting with `/` are anchored at git root (like `.gitignore`).
- Patterns without leading `/` are matched relative to current working path.
- `.env.example` and `.envrc` are explicitly allowed by default.

## 2) Dangerous bash policy

Detect dangerous command patterns (substring/regex):
- `rm -rf`
- `sudo`
- `git reset --hard`
- `git clean -fd`
- `chmod -R`
- publish/deploy class commands (`npm publish`, `gh release`, etc.)

Behavior:
- interactive mode: confirm via `ctx.ui.confirm`
  - default is deny if user declines
- non-interactive mode: block with explicit error reason

Config:
- defaults in extension
- optional overrides from the same config discovery chain above using structured rule groups:
  - `dangerously_allow.exact: string[]`
  - `dangerously_allow.prefix: string[]`
  - `always_block.exact: string[]`
  - `always_block.prefix: string[]`
  - `confirm.exact: string[]`
  - `confirm.prefix: string[]`

Override semantics (MVP):
- Each configured list **replaces** the built-in list for that key.
- If you want to add one confirm command, copy the built-in confirm list and append your command.
- This is intentionally simple for now; we may add append/merge semantics later.

## Matching semantics (MVP)

- Split bash input into segments by shell operators (`&&`, `||`, `;`, `|`, newline).
- Evaluate each segment with precedence:
  1. `dangerously_allow` (skip checks for that segment)
  2. `always_block` (block immediately)
  3. `confirm` (mark as risky)
- `exact` means normalized segment equals rule.
- `prefix` means normalized segment starts with rule as a command prefix.
- If any segment is blocked, block.
- Else if any segment is risky, request one confirmation (interactive) or block (non-interactive).

Note: this is a lightweight custom matcher. Before expanding it, we should review ecosystem patterns/tools to avoid reinventing policy matching unnecessarily.

## 3) Explanations and ergonomics

On block/deny, return concise reason:
- what was blocked
- why (rule/pattern)
- how to proceed (edit config or use safer command)

No noisy prompts for low-risk actions.

## Acceptance criteria

1. `read` and `write`/`edit` policies can differ via split path lists, and blocked operations return clear reasons.
2. Dangerous `bash` commands require confirmation in interactive mode.
3. Dangerous `bash` commands are blocked in non-interactive mode.
4. Project config overrides load and affect decisions.
5. Safe commands remain unaffected (low false-positive noise).

## Config discovery requirements

- Use `getAgentDir()` from `@mariozechner/pi-coding-agent` for user-level path.
- Do **not** hardcode `~/.pi/agent` or rely on `$HOME` directly.
- Discover project config by walking parent dirs from `ctx.cwd` (nearest `.pi/prelude/guardrails.json`).
- Optionally stop upward traversal at git root.

## Test plan

Automated (contract level):
- verify guardrails extension file exists and registers `tool_call`
- verify protected path constants/patterns are present
- verify dangerous command patterns are present

Manual smoke:
1. ask model to read `.env` → expect block
2. ask model to edit `.env` → expect block
3. ask model to run `rm -rf ./tmp` → expect confirm
4. decline confirm → expect blocked reason
5. run benign `ls`/`grep` → no prompt
6. add override config and retest behavior
