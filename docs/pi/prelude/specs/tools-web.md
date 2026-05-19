# Spec: `tools-web.ts` (Phase 3)

## Goal

Provide lightweight web access tools for planning/research flows without heavy runtime dependencies.

## Tools

- `web_search`
- `web_fetch`

## `web_search` contract

Parameters:
- `query` (required)
- `limit` (optional, default 5, max 10)

Behavior:
- Prefer Brave Web Search API when `BRAVE_API_KEY` is set.
- Fallback to CLI backend (`ddgr`) when no Brave key is available.
- Return concise list with title + URL (+ snippet if available).
- Truncate output safely.

## `web_fetch` contract

Parameters:
- `url` (required)
- `maxBytes` (optional, default 16000, max 64000)

Behavior:
- Fetch with `curl`.
- Return textual content (best-effort plain text).
- Truncate to `maxBytes`.
- Include source URL in output.

## Failure behavior

- Missing backend binary (`ddgr`/`curl`) or missing Brave key + missing fallback => explicit error.
- Command/network failure => explicit error with short stderr.
- Invalid input => explicit validation-style error text.

## Acceptance

1. `web_search` returns structured, readable results when backend exists.
2. `web_fetch` returns fetched content with bounds.
3. Errors are deterministic and non-fatal.
