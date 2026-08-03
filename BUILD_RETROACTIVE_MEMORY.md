# Build Retroactive Project Memory

Use this optional agent workflow after the deterministic installer creates `Agent Memory/` inside the active Obsidian vault. Installation itself never invokes an LLM or network and never infers summaries.

## Safety boundary

- Honor all project-specific exclusion rules before inspection. Prefer the tracked-file list and explicit paths over broad filesystem traversal.
- Do not move, rewrite, normalize, or index established `vault/` or uppercase `Memory/` files.
- Do not replace existing `Agent Memory/*.md` source content without reviewing it.
- Treat code, tests, version history, and existing documentation as evidence; mark uncertainty explicitly.
- Add YAML Properties only when they have a real human or tool consumer.
- Never edit marked `Agent Memory/start.md` directly; it is generated.

## Evidence pass

Inspect only sources permitted by the project:

1. Read `.obsidian-memory/SKILL.md`; run `bash .obsidian-memory/scripts/memory.sh startup`, then `bash .obsidian-memory/scripts/memory.sh list`.
2. Search memory for the project goal, current state, blockers, and next action:

   ```bash
   bash .obsidian-memory/scripts/memory.sh search -- "relevant phrase"
   ```

3. Inspect the repository README, tracked manifests, entry points, tests, and recent version-control history.
4. Resolve contradictions in favor of executable code/tests and newer reviewed evidence; record unresolved conflicts as risks.

## Write pass

Update `state.md` in the active vault's `Agent Memory/` directory with evidence-based content under:

- `# Now` — current goal and implementation state;
- `# Constraints` — active rules and boundaries;
- `# Risks` — blockers, uncertainty, or technical risk;
- `# Detail` — longer context that should remain out of the cold-start digest.

Update unchecked work under `Agent Memory/backlog.md`’s `# Active`. Add durable decisions to `Agent Memory/decisions.md`. Put architecture or runbook detail in separate Markdown notes and add a one-sentence standard Markdown link to `Agent Memory/index.md`. Do not reproduce exhaustive file trees, transcripts, or git logs.

Create one handoff after reconstruction:

```bash
bash .obsidian-memory/scripts/memory.sh new-session
```

Fill its outcome, decisions, files/tests, next action, and detail links. The command refreshes the digest. Finish by running:

```bash
bash .obsidian-memory/scripts/memory.sh startup
```

Verify the generated output is accurate and sufficient to orient a new agent without opening history. Correct source notes and refresh again if needed.
