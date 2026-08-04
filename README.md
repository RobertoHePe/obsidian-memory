# Obsidian Memory

Durable, token-conscious project memory for AI coding agents. Markdown remains the canonical format; a deterministic cold-start digest stays small while editable state, tasks, decisions, and session history remain discoverable on demand.

## Install or migrate

Requirements: Linux/WSL, Bash, and GNU coreutils/find/grep/awk. No language runtime or package installation is required.

From an existing checkout of this installer:

```bash
bash /path/to/obsidian-memory/init.sh --strict /path/to/project
```

For a one-time installation without keeping a separate installer checkout:

```bash
installer_dir=$(mktemp -d)
git clone --depth 1 https://github.com/RobertoHePe/obsidian-memory.git "$installer_dir/obsidian-memory"
if bash "$installer_dir/obsidian-memory/init.sh" --strict /path/to/project; then
    rm -rf -- "$installer_dir"
else
    printf 'Installer retained for conflict review: %s\n' "$installer_dir" >&2
fi
```

The clone uses the network; `init.sh` itself is offline, non-interactive, and deterministic. It does not invoke an LLM, delete files, modify the target repository's `scripts/`, or replace user-authored memory. Review the report before removing the temporary installer checkout when conflicts are reported.

Installation result:

```text
/path/to/project/
├── .obsidian-memory/
│   ├── SKILL.md
│   └── scripts/memory.sh
├── AGENTS.md                         # created or safely merged
└── Memory/Agent Memory/              # fresh or recognized uppercase vault
```

Vault selection is fail-closed:

| Existing project layout | Installer behavior |
|---|---|
| Recognized `Memory/` vault | Preserve it and add `Memory/Agent Memory/`. |
| No `Memory/` or `vault/` | Create `Memory/Agent Memory/`; open `Memory/` in Obsidian when desired. |
| Recognized lowercase `vault/` | Preserve it and add `vault/Agent Memory/`. |
| Unrelated directory merely named `Memory/` | Report a conflict; do not partially install. |
| Both recognized `Memory/` and `vault/` | Report ambiguity; do not partially install. |
| Old outside-vault `memory/` | Preserve it and require explicit reconciliation before canonical installation. |

`Memory/` recognition requires `.obsidian/`, an existing managed `Agent Memory/.format-version`, or at least two known legacy signatures. A directory name alone is insufficient.

Useful options:

```bash
# Explicit CI spelling; operation is always non-interactive.
bash init.sh --non-interactive /path/to/project

# Also save the report; this explicit path authorizes replacing the report file.
bash init.sh --strict --report /tmp/memory-migration.txt /path/to/project
```

`--strict` is recommended: it exits 2 when an unsafe path or preserved conflict is found. Without it, conflicts are still preserved and reported, but the installer returns zero.

Every run prints a report with `CREATED`, `BACKUP`, `MERGED`, `MIGRATED`, `REFRESHED`, `PRESERVED`, `UNCHANGED`, and `CONFLICT` entries. Managed skill-resource conflicts and user-owned `start.md` conflicts are staged once as checksum-named `.incoming-*` files; installed and user-owned files remain untouched. After a conflict-free installation, start with:

```bash
cd /path/to/project
bash .obsidian-memory/scripts/memory.sh startup
bash .obsidian-memory/scripts/memory.sh status
```

## What belongs in `AGENTS.md`

The installer manages this automatically. An installing agent should run `init.sh`, review its report, and verify that `AGENTS.md` contains exactly one marked memory block. It should not invent a different block, paste the complete skill into `AGENTS.md`, or edit text between existing memory markers.

- If `AGENTS.md` is absent, the installer creates it with the block below.
- If `AGENTS.md` exists without memory markers, the installer saves an exact content-addressed backup and appends the block without changing the existing text.
- If an exact prior installer-managed block is present, the installer backs up `AGENTS.md` and migrates only that marked span.
- If the marked span was user-edited, malformed, or duplicated, the installer preserves it and reports a conflict instead of guessing.

The managed block contains the **when-to** triggers because repository instructions are injected continuously by supporting agents. The repository-local skill contains the **how-to** procedure: target files, commands, refresh mechanics, search, and handoff format.

```markdown
<!-- obsidian-memory:start v2 -->
## Project memory

At the start of each agent session, from the repository root:

1. Read `.obsidian-memory/SKILL.md`; it is the authoritative memory procedure.
2. Run `bash .obsidian-memory/scripts/memory.sh startup`.
3. Retrieve additional memory only when the current task requires it, following the skill's progressive-disclosure workflow.

Update durable project memory during work whenever any of these changes:

- the current goal, verified implementation state, active constraint, blocker, or risk;
- concrete next actions or priorities;
- an accepted decision that constrains future work;
- stable architecture, runbook, or domain knowledge that a future agent would otherwise need to rediscover.

Before a meaningful handoff—session end, context switch, blocker, or completed milestone—update the relevant memory and create a compact handoff using the skill's procedure. If no durable information changed, do not write memory merely because files changed or commands ran.

Treat the active Obsidian vault as canonical durable memory. Never hand-edit the generated `start.md`, preload the complete vault, or copy transcripts, secrets, or large command outputs into memory. Use `.obsidian-memory/SKILL.md` for where and how to write, refresh, search, and create handoffs.

If the skill, helper, or validated startup digest is missing or refused, report the problem instead of bypassing the memory safeguards.
<!-- obsidian-memory:end v2 -->
```

The `v2` marker identifies the managed-block protocol; it is not the runtime skill version. Keep both marker lines unchanged so reruns can recognize ownership safely.

## Default agent workflow

At startup:

1. The tool reads `AGENTS.md` as repository instructions, where supported.
2. Read `.obsidian-memory/SKILL.md`, then run `bash .obsidian-memory/scripts/memory.sh startup`; it prints only a valid bounded generated digest.
3. Run `bash .obsidian-memory/scripts/memory.sh status` for the active vault path and a concise handoff/tracked-change signal.
4. Run `bash .obsidian-memory/scripts/memory.sh list` or search only when the task needs more context.

During work and at a meaningful handoff:

1. Edit `state.md` and `backlog.md` inside the vault's `Agent Memory/` directory.
2. Append durable choices to its `decisions.md`.
3. Run `bash .obsidian-memory/scripts/memory.sh new-session` for a compact history note; it indexes the handoff and refreshes the digest.
4. After source edits without a handoff, run `bash .obsidian-memory/scripts/memory.sh refresh`.

Do not hand-edit a marked `Agent Memory/start.md`; it is generated. Link to source code, issues, or detail notes instead of copying transcripts and command output.

Agents that do not automatically load `AGENTS.md` should be configured to read it, or told to read `.obsidian-memory/SKILL.md`. Files and commands are tool-neutral for Codex-, Claude-, Cursor-, and similar workflows; the installer does not modify tool-specific user configuration.

## Memory update contract

`AGENTS.md` is authoritative for **when** an update is required: when durable project state, next work, accepted decisions, reusable knowledge, or meaningful handoff state changes. `.obsidian-memory/SKILL.md` is authoritative for **how** to perform that update safely.

| When this changes | What the agent updates |
|---|---|
| Current goal, verified state, constraint, blocker, or risk | `Agent Memory/state.md`; stale statements are corrected or removed. |
| Concrete next action or priority | `Agent Memory/backlog.md`; completed/stale tasks do not become a progress diary. |
| Accepted choice that constrains future work | Append a short choice and rationale to `Agent Memory/decisions.md`. |
| Stable architecture, runbook, or domain detail | A focused note plus a short route in `Agent Memory/index.md`. |
| Meaningful handoff: session end, context switch, blocker, or completed milestone | Update the sources first, then run `new-session` and fill its compact outcome/evidence/next-action fields. |

The skill maps each trigger to the appropriate source and command. Run `refresh` after durable source edits when continuing work without a handoff. Do nothing when no durable information changed. Never store secrets, transcripts, large command output, exhaustive diffs, temporary hypotheses, or facts that are cheap to recover from code and version control.

## Progressive disclosure

```text
project/
├── AGENTS.md                    # compact router; existing instructions retained
├── .obsidian-memory/            # namespaced repo-local skill bundle
│   ├── SKILL.md
│   └── scripts/
│       └── memory.sh            # unified runtime helper
├── Memory/                      # active Obsidian vault (fresh/uppercase layout)
│   ├── .obsidian/               # existing settings, when present
│   ├── existing notes...        # never rewritten by installation
│   └── Agent Memory/
│       ├── start.md             # GENERATED: <=80 lines and <=3000 bytes
│       ├── state.md             # editable Now, Constraints, Risks, detail
│       ├── backlog.md           # editable checkbox tasks
│       ├── index.md             # routes to optional detail
│       ├── decisions.md         # durable rationale
│       ├── vault.md             # routes to established vault notes, when present
│       └── sessions/
│           ├── index.md
│           └── YYYYMMDD_HHMMSS_session.md
└── scripts/                      # existing project scripts; never touched
```

Commands:

```bash
bash .obsidian-memory/scripts/memory.sh startup
bash .obsidian-memory/scripts/memory.sh status
bash .obsidian-memory/scripts/memory.sh list
bash .obsidian-memory/scripts/memory.sh search -- "literal phrase"
bash .obsidian-memory/scripts/memory.sh refresh
bash .obsidian-memory/scripts/memory.sh new-session
```

Fresh installs use `Memory/Agent Memory/`. Existing lowercase `vault/` projects use `vault/Agent Memory/` without renaming the vault. `search` covers the complete active vault, so established notes and compact agent notes are both reachable without being loaded wholesale. Session filenames include seconds and add a numeric suffix on collision; an existing note is never truncated.

## Deterministic digest bounds

`refresh` derives `Agent Memory/start.md` from editable sources in a fixed order:

- up to 12 nonblank lines from `state.md`’s `# Now`;
- up to 5 unchecked tasks from `backlog.md`’s `# Active`;
- the last 5 appended entries from `sessions/index.md`, shown newest-first;
- up to 3 lines each from `# Constraints` and `# Risks`;
- fixed links to index, state, backlog, decisions, sessions, and established vault routes when present.

Selected lines are admitted against decreasing byte budgets; an oversized line is replaced by a compact notice pointing back to its source. This keeps Unicode source intact and makes output locale-independent while holding the digest to no more than 80 lines and 3,000 bytes. It contains no generated timestamp. Refresh first renders outside the hierarchy, compares bytes, and only performs a same-directory atomic replacement when content changed; an unchanged refresh does not alter target contents or metadata.

## Migration guarantees

- Existing `vault/` or recognized uppercase `Memory/` paths, file bytes, modes, mtimes, sizes, and symlink targets are preserved. Obsidian settings, attachments, indexes, odd filenames, and helper scripts are not rewritten or relocated. Adding `Agent Memory/` necessarily changes the vault root directory's entry list and mtime; ownership, ACLs, and extended attributes are outside the verified contract.
- Uppercase `Memory/` is recognized by `.obsidian/`, an existing managed `Agent Memory/`, or at least two project-memory signatures among `00_Index.md`, `13_Current_State.md`, `14_Backlog.md`, and `sessions/`. Arbitrary directories named `Memory` are rejected. If both vault layouts exist, migration reports a conflict instead of choosing silently.
- Existing `AGENTS.md` content is saved to a content-addressed exact backup, retained as the exact prefix, and followed by one marked block. Re-runs never append it twice.
- `state.md`, `backlog.md`, `index.md`, `decisions.md`, `vault.md`, and session indexes are user-owned: existing files are preserved.
- A `start.md` whose generated markers envelope the entire file is refreshed only from source files. Unmarked, malformed, or externally extended starts are preserved and receive a deterministic incoming candidate.
- Managed helpers are replaced only when absent. Differing helpers are preserved with one deterministic incoming candidate.
- The target repository's generic `scripts/` directory is unrelated and never modified. Only `.obsidian-memory/` is managed; the benchmark helper remains development-only in this installer repository.
- An exact previous installer-managed `AGENTS.md` block that calls root scripts is backed up and migrated to the skill command. User-edited blocks are preserved. Existing old scripts are left untouched and are no longer referenced after that exact migration; remove them manually only after verifying they are not project-owned.
- Symlinked target roots, parent paths, destinations, and malformed AGENTS markers fail closed. `--strict` makes preserved conflicts exit 2 for CI.
- Old top-level `memory/` remains readable through the helper for transition purposes, but `refresh` and `new-session` refuse to write there. Reconcile it into one vault-native canonical store before installing.
- A second resolved run changes no files, modes, mtimes, directories, symlinks, or entry counts.
- Quoted paths and literal search handle spaces and ordinary shell metacharacters. Tests include brackets, dollar signs, semicolons, ampersands, backticks, and literal `$()` text.

Migration is additive rather than destructive. The compact layer is created inside the active vault and links to established notes; deterministic code does not pretend to infer which existing note is authoritative.

## Measured startup reduction

Run the reproducible local comparison:

```bash
bash tests/measure.sh
```

Against the checked-in fixture representing the previous installer’s mandatory six-file startup:

| Proxy | Legacy | New | Reduction |
|---|---:|---:|---:|
| Exact bytes | 5,264 | 2,322 | 55.9% |
| Newline count | 209 | 52 | 75.1% |
| `wc` whitespace-delimited words | 764 | 314 | 58.9% |

These are deterministic size proxies, **not tokenizer-exact token counts**. The tool prints the exact file set and fails unless the new digest retains routes to the detail index and session history. Runtime `status` output is excluded because it is a small repository-dependent signal rather than static file context.

## Markdown links and Obsidian wikilinks

New generated and template files use standard Markdown links such as `[State](state.md)`. Obsidian supports these links, and they also work in GitHub, generic editors, renderers, and agent tooling. Human-authored notes may use Obsidian wikilinks such as `[[13_Current_State]]`; existing wikilinks are preserved. Wikilinks are shorter and integrate tightly with Obsidian rename handling, but many non-Obsidian tools do not resolve them, so they are not the generated default.

| Capability | Standard Markdown | Obsidian wikilink |
|---|---|---|
| Note link with display text | `[Current state](state.md)` | `[[state\|Current state]]` |
| Heading link | `[Constraints](state.md#constraints)` | `[[state#Constraints]]` |
| Embed | `![Diagram](assets/diagram.png)` | `![[diagram.png]]` |
| Obsidian block reference | No standard equivalent | `[[state#^block-id]]` |
| Backlinks and graph in Obsidian | Yes | Yes |
| Rename updates in Obsidian | Supported when automatic link updates are enabled | Native and usually more ergonomic |
| Outside Obsidian | Broadly portable | Often rendered as plain text |
| Duplicate filenames | Explicit relative paths avoid ambiguity | Name-only resolution can be ambiguous |

Both syntaxes provide display aliases (`[label](path)` versus `[[note\|label]]`). Obsidian supports heading links and embeds in both styles, but its block-reference syntax is wikilink-specific. Generated files therefore use explicit relative Markdown paths; user-authored vault notes may use either form.

No external knowledge-format schema is imposed. YAML properties are optional for human-authored notes and are not required by the scripts.

## Development

No third-party dependencies are required. Runtime scripts currently target Bash plus GNU coreutils, `find`, `grep`, and `awk` (Linux/WSL); stock BSD/macOS userland is not supported without GNU tools.

```bash
bash -n init.sh scripts/*.sh tests/*.sh
bash tests/run.sh
bash tests/measure.sh
git diff --check
```

The suite covers clean installation, `Agent Memory/` placement inside fresh and existing Obsidian vaults, established-note preservation, arbitrary `Memory/` rejection, existing instructions and modified helpers, user-owned generated-output conflicts, true second-run filesystem idempotency, special-character paths/content, symlink refusal, malformed markers, same-second handoffs, locale-independent Unicode budgeting, deterministic measurement, and growth to 400 state lines, 400 backlog tasks, and 60 sessions behind the fixed digest cap.

## Obsidian

Open `Memory/` as the Obsidian vault for fresh or uppercase layouts, or keep opening an existing lowercase `vault/`. `Agent Memory/` appears directly inside that vault. All content is ordinary Markdown; no plugin is required.

## License

MIT — use it, fork it, adapt it.
