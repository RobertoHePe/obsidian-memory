---
name: obsidian-memory
description: Use when a project has Obsidian Agent Memory or needs durable bounded Markdown context across AI coding sessions.
---

# Obsidian Memory

Use a generated bounded digest by default and progressively disclose durable detail. The Obsidian vault is canonical; conversation context and generated `Agent Memory/start.md` are not.

## Session start

When `.obsidian-memory/SKILL.md` exists:

1. Read the repository-local `.obsidian-memory/SKILL.md`.
2. Run `bash .obsidian-memory/scripts/memory.sh startup`. It refuses user-owned, malformed, or oversized starts and prints only a valid bounded generated digest. Do not preload state, backlog, decisions, or session history.
3. Run `bash .obsidian-memory/scripts/memory.sh status` for the latest handoff and tracked-change count.
4. If the task needs more context, run `bash .obsidian-memory/scripts/memory.sh list` or `bash .obsidian-memory/scripts/memory.sh search -- "literal term"`.
5. Open only the linked notes and source files relevant to the task.

Do not escalate a date gap or any tracked change into a full-memory reread. Inspect affected paths and retrieve related memory selectively.

If the repository needs memory and `.obsidian-memory/SKILL.md` is absent, run the deterministic installer. It supports fresh repositories, recognized uppercase `Memory/` vaults, and recognized lowercase `vault/` vaults:

```bash
bash /path/to/obsidian-memory/init.sh --strict /path/to/project
```

Review its report. Existing vault content must remain in place; only additive `Agent Memory/` content may be created inside the vault. Arbitrary `Memory/`, ambiguous dual-vault layouts, old outside-vault `memory/`, and unsafe symlink paths must fail closed.

## During work

- Edit `state.md` (`# Now`, `# Constraints`, `# Risks`) and `backlog.md` (`# Active`) inside the active vault's `Agent Memory/` directory.
- Never hand-edit a `start.md` carrying the generated marker.
- Put durable rationale in `Agent Memory/decisions.md`.
- Put architecture/runbook detail in linked Markdown notes and add a one-line route to `Agent Memory/index.md`.
- Search before opening history. Prefer repository history for exhaustive diffs.
- Add YAML Properties only when a human or tool actually uses them; no schema is required.

After source edits without a handoff:

```bash
bash .obsidian-memory/scripts/memory.sh refresh
```

## Handoff

At a meaningful boundary:

1. Update state and backlog sources.
2. Append decisions that constrain future work.
3. Run `bash .obsidian-memory/scripts/memory.sh new-session` and fill the compact outcome/next/links fields.

`new-session` creates a unique note, updates `sessions/index.md`, and refreshes the digest. Do not paste transcripts, broad file listings, repeated rules, or full test output.

## Digest contract

Refresh is deterministic and has no timestamp. It selects at most 12 Now lines, 5 unchecked Active tasks, 5 recent session links, and 3 lines each of Constraints/Risks, then adds fixed discovery routes. The result is capped at 80 lines and 3,000 bytes.

An existing `Agent Memory/start.md` is managed only when its generated markers envelope the entire file. Preserve unmarked, malformed, or externally extended files and stage a checksum-named candidate. Fully enclosed generated output may be atomically replaced only when its source-derived bytes changed.

## Migration and conflicts

The installer is non-interactive and offline. It must:

- preserve established `vault/` or recognized uppercase `Memory/` paths, file bytes, modes, mtimes, sizes, symlink targets, Obsidian settings, attachments, indexes, and helpers;
- create the compact layer inside the selected vault as `Agent Memory/`;
- install the runtime skill only under `.obsidian-memory/`; never modify the target repository's generic `scripts/` directory;
- back up and merge the marked block from `templates/agents-memory-block.md` into existing `AGENTS.md` once; keep durable-update triggers there and procedural file/command details in the repository-local skill;
- preserve user-owned Agent Memory source files;
- stage checksum-named candidates when managed helpers or digest ownership conflict;
- refuse symlink destinations and report malformed markers;
- remain filesystem-idempotent on an unchanged second run.

Use `--strict` in CI when preserved conflicts should return exit 2. Use `--report FILE` for a durable report artifact.

## Vault format

Use ordinary Markdown. Generated routes use standard Markdown links for portability; existing and human-authored Obsidian wikilinks remain valid. Do not rewrite established notes merely to normalize links or add frontmatter.
