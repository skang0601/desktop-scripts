# 0001 - Record decisions as ADRs

- Status: accepted
- Date: 2026-07-19

## Context

The setup has to be rebuildable from scratch after a reinstall. Config files
record what the setup is, not why, and the why is what is expensive to
rediscover: which remapping tool works under Wayland, why a quirk file exists,
which approaches fail and how.

## Decision

Every non-obvious choice gets a numbered Markdown file in `docs/decisions/`
with Context, Decision and Consequences sections. Numbers are sequential and
never reused. A superseded decision keeps its file, with its status changed to
`superseded by NNNN`.

## Consequences

- Small ongoing writing cost per decision.
- A reinstall, or anyone working in the repo later, can recover the intent and
  not only the state.
