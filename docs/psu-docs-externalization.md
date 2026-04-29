# PSU Docs Externalization Decision

Decision: keep `docs/psu-docs` in this repository until the replacement gate is satisfied.

Phase 13 evaluated the externalization options from `plans/plan-codebase-complexity-elimination.md`. The safe current option is to keep the vendored PSU docs in-repo because they are the deterministic local source used by project guidance, Codex PSU skills, Claude PSU agents, and Azure recovery procedures.

Do not delete `docs/psu-docs` unless all of these are true:

- `AGENTS.md`, `CLAUDE.md`, `.agents/skills/psu`, and the matching Claude PSU agents or skills point to the replacement source.
- The replacement source is deterministic: a pinned submodule, a pinned docs fetch/update command, or an equivalent local extract with a reproducible update path.
- Local and Azure recovery references remain available, including Azure hosting, PSU module security model, app tokens, app registration, and command reference docs.
- The replacement has been validated by the PSU docs externalization gate test.

This phase does not delete files. It records the current decision and prevents accidental removal of the local PSU knowledge source before a deterministic replacement exists.
