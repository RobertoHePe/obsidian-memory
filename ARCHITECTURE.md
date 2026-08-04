# Architecture: Bounded Project Memory

## Decision

Keep one Obsidian vault as durable storage, place the compact `Agent Memory/` layer inside it, use editable long-form source notes, and generate a strictly bounded cold-start digest. Do not impose an external knowledge schema or rewrite established notes.

## Where the legacy context went

The previous protocol mandated `AGENTS.md`, `vault/00_Index.md`, `vault/12_Session_Rules.md`, `vault/13_Current_State.md`, `vault/14_Backlog.md`, and the latest session note at every start. A date gap, any newer file, or any uncommitted change forced the same full reread.

The checked-in legacy fixture measures 5,264 bytes and 764 whitespace-delimited words before it contains meaningful project detail. Waste came from:

- duplicate protocol text in `AGENTS.md` and `12_Session_Rules.md`;
- a generic index with nonexistent starter links;
- placeholder state/backlog sections and a large blank session form;
- duplicated facts across state, backlog, decisions, and every session;
- change detection using “read everything” as its only recovery path.

`bash tests/measure.sh` reproduces that baseline and lists every measured file. It uses exact bytes/newlines and `wc` whitespace words as size proxies, never as tokenizer-exact counts.

## Read and write architecture

The clean default startup set is only `AGENTS.md` plus generated `Memory/Agent Memory/start.md` (2,322 bytes / 314 `wc` words). Editable sources and cold history are behind explicit routes.

```text
state.md ───────┐
backlog.md ─────┼─ refresh ─→ start.md ← AGENTS.md (default read)
sessions/index ─┘                 │
                                  └─→ index.md
                                      ├─ state/backlog detail
                                      ├─ decisions.md
                                      ├─ selected session
                                      └─ vault.md → established note in the same vault
```

`.obsidian-memory/scripts/memory.sh status` reports the active vault, latest handoff, and tracked git-change count without dumping paths. `list` opens the next disclosure level. `search` performs literal Markdown retrieval across the active `Memory/` or `vault/`; it has no network or LLM dependency.

Writes follow information lifetime:

- `state.md`: current facts, constraints, risks, and longer detail.
- `backlog.md`: active/later/done checkbox tasks.
- `decisions.md`: append-only choices whose rationale constrains future work.
- detail notes: durable architecture/runbooks linked from the index.
- session notes: compact handoffs at meaningful boundaries.
- `start.md`: generated projection, never a source of truth.
- git/source files: exhaustive implementation history; memory links rather than duplicates it.

## Bounded digest algorithm

`refresh` selects, in order:

1. at most 12 nonblank lines from `state.md`’s exact `# Now` section;
2. at most 5 unchecked tasks from `backlog.md`’s exact `# Active` section;
3. the last 5 session-index entries, displayed newest first;
4. at most 3 lines each from exact `# Constraints` and `# Risks` sections;
5. fixed standard-Markdown links to index, state, backlog, decisions, sessions, and `vault.md` when present.

Selected lines are admitted using decreasing byte limits until both hard caps pass: no more than 80 newline-terminated lines and no more than 3,000 bytes. A line over the current byte budget becomes a compact source-route notice rather than being sliced, so Unicode remains valid and output does not depend on locale. If even fixed routes cannot fit, refresh fails instead of emitting an oversized or incomplete digest. No timestamp or random value enters the digest.

Rendering occurs in the temporary directory. If output matches an existing wholly enclosed generated digest byte-for-byte, no target entry or metadata changes. Changed output is copied to a same-directory temporary file and atomically renamed. An unmarked, malformed, or externally extended destination is preserved and gets a content-checksum-named candidate. Thus generated ownership is recognizable without weakening user-file preservation.

The growth test uses 400 Now lines, 400 active tasks, and 60 sessions; it asserts both caps, each selection limit, all source/history retention, all discovery routes, and a metadata-stable no-op refresh.

## Obsidian and Markdown format decision

The active storage boundary is the Obsidian vault itself. Fresh installs create `Memory/Agent Memory/`; recognized uppercase vaults use that same path; existing lowercase vaults use `vault/Agent Memory/` without renaming anything.

Generated and template notes use standard Markdown links because Obsidian, GitHub, generic renderers, and coding agents all resolve them. Existing and human-authored Obsidian wikilinks remain valid and untouched. Wikilinks offer shorter syntax and tighter Obsidian rename behavior, but they are not portable enough for generated cross-tool routes.

YAML Properties are optional. The scripts consume headings, checkbox tasks, session-index links, and generated ownership markers—not a metadata schema. This keeps notes easy to edit in Obsidian and easy for agents to parse without requiring a plugin or validator.

## Migration contract

Migration is additive and deterministic:

| Existing item | Action |
|---|---|
| Existing `vault/` | Preserve established paths, bytes, modes, mtimes, sizes, and symlink targets; add `vault/Agent Memory/` without renaming the vault. |
| Recognized `Memory/` Obsidian vault | Preserve established paths, bytes, modes, mtimes, sizes, symlink targets, `.obsidian/`, attachments, and helpers; add `Memory/Agent Memory/`. |
| No vault | Create `Memory/Agent Memory/`; the user can open `Memory/` directly in Obsidian. |
| Arbitrary `Memory/` directory | Reject unless `.obsidian/`, managed Agent Memory, or enough project-memory signatures identify it as a vault. |
| Existing `AGENTS.md` without markers | Save a content-addressed exact backup, then append one short marked block. |
| Existing complete AGENTS block | Preserve, including user edits; never append twice. |
| Malformed/duplicate AGENTS marker | Preserve and report conflict; stage the proposed block. |
| Existing Agent Memory source/index files | Treat as user-owned and preserve; create only missing peers. |
| Existing `start.md` wholly enclosed by generated markers | Regenerate atomically only if source-derived bytes changed. |
| Existing unmarked, malformed, or externally extended `start.md` | Preserve; stage one checksum-named generated candidate. |
| Existing identical managed helper | Leave unchanged. |
| Existing different managed helper | Preserve; stage one checksum-named incoming candidate. |
| Symlink at a destination | Refuse to follow or replace it; report conflict. |
| Old top-level `memory/` | Preserve and report a layout conflict; helper compatibility permits reads/search but refuses refresh and session writes. |
| Existing project `scripts/` | Treat as unrelated: do not inspect, modify, or install memory helpers there. |
| Exact old managed AGENTS block | Back up and replace only that marked block so it routes to `.obsidian-memory/`; retain all old script files untouched. |

The installer never calls established index scripts because they may truncate user content. It changes modes only on newly installed known helpers, is non-interactive, prints a report, and supports `--strict` for CI. The first installation adds a directory inside the vault and therefore changes the vault root directory's mtime and entry list; established paths, bytes, modes, mtimes, sizes, and symlink targets remain unchanged. Re-running a resolved installation changes neither filesystem contents nor the verified metadata. Ownership, ACLs, and extended attributes are not part of the tested contract.

Migration intentionally does not synthesize a project summary: doing so without an LLM is unreliable, while requiring an LLM/network violates deterministic migration. The migrated state and digest give a compact notice, links to the old state/backlog/decisions/history, and a reconciliation task.

## Known limitations

- Byte/word proxies correlate with prompt size but do not predict a model tokenizer.
- Retrieval is literal text search, not semantic retrieval.
- Section extraction requires the documented exact top-level headings.
- Oversized selected lines become source-route notices in the digest; their complete text remains in source notes.
- Existing custom source/index files are preserved even if incomplete. Refresh reports missing/unsafe required sources rather than repairing them destructively.
- Optional YAML Properties are not validated because no schema is required.
