# 0001 - Record decisions as ADRs

- Status: accepted
- Date: 2026-07-19

## Context

This repo exists because the machine gets reinstalled and the setup has to be
rebuilt from scratch. Config files record *what* the setup is, but not *why* --
and the "why" is the expensive part to rediscover (which of five remapping tools
survived contact with Wayland, why one particular quirk file exists, which
approach was tried and abandoned).

Two earlier attempts at this same goal already exist in `~/Workspace`
(`Toshy/`, `gnome-macos-remap-wayland/`) with no record of why they were set
aside.

## Decision

Every non-obvious choice gets a numbered markdown file in `docs/decisions/`,
using this format: Context / Decision / Consequences. Numbered sequentially,
never renumbered. Superseded decisions stay in the repo with their status
changed to `superseded by NNNN` rather than being deleted.

## Consequences

- Small ongoing writing cost per decision.
- A reinstall (or a future agent) can reconstruct intent, not just state.
