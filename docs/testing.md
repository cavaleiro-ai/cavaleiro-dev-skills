# Testing Cavaleiro Dev Skills

Cavaleiro Dev Skills has two distinct kinds of tests, each in its own directory:

- **`tests/`** — does the plugin's non-LLM code work? Bash + node + python integration tests for brainstorm-server JS, OpenCode plugin loading, codex-plugin sync, and analysis utilities.
- **`evals/`** — do agents behave correctly on real LLM sessions? Python harness driving real tmux sessions of Claude Code / Codex / Gemini CLI, with an LLM actor and verifier judging skill compliance.

## Plugin tests

Live in `tests/`. Currently:

- `tests/brainstorm-server/` — node test suite for the brainstorm server JS code.
- `tests/opencode/` — bash tests for OpenCode plugin loading, bootstrap caching, and tool registration.
- `tests/codex-plugin-sync/` — bash sync verification.
- `tests/kimi/` — bash/Python checks for Kimi plugin manifest wiring.
- `tests/claude-code/test-helpers.sh`, `analyze-token-usage.py` — utilities used by remaining bash tests.
- `tests/claude-code/test-subagent-driven-development.sh` — agent-can-describe-SDD test (no quorum counterpart; tests description-recall, not behavior).
- `tests/claude-code/test-subagent-driven-development-integration.sh` — extended SDD integration with token analysis (quorum covers the YAGNI subset; bash adds commit-count, Claude Code task-tracking, and token telemetry assertions).
- `tests/claude-code/test-worktree-native-preference.sh` — RED-GREEN-REFACTOR validation for worktree skill (quorum covers the PRESSURE phase; bash also covers RED/GREEN baselines).
- `tests/explicit-skill-requests/` — Haiku-specific, multi-turn, and skill-name-prompted tests not covered by quorum.
- `tests/diagnosing-superpowers/test-skill-structure.sh` — structural checks for the diagnosing-superpowers skill (frontmatter, referenced files, leak scan, word budget); behavior-scenario eval records are kept by the maintainer outside the repo.
- `tests/skills/` — `validate-skills.mjs` (static checks for every skill and manifest: frontmatter names, `superpowers:<skill>` references, relative links, helper-script paths, manifest paths, plugin ids, the Muse skill list and hook interpreter, version sync) and `test-skill-snippets.sh` (runs shell commands exactly as skills print them against fixture repositories).
- `tests/muse/test-muse-plugin.sh` — Muse manifest checks, and the SessionStart hook run exactly as the manifest declares it (with `sh` resolved to dash when dash is installed).

Run every plugin test suite with one command — suites whose optional tools are missing are reported as SKIP:

```bash
bash tests/run-plugin-tests.sh            # all suites
bash tests/run-plugin-tests.sh --list     # suites and the tools each needs
bash tests/run-plugin-tests.sh 'skills|sdd'   # a subset, by name regex
```

Or run one suite via the relevant directory's `run-*.sh` or `npm test`. The same runner backs `.github/workflows/test.yml`.

## Skill behavior evals

Live in `evals/` (the [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals/) eval lab, since renamed from Drill). Quorum is the harness CLI — one part of the system: it drives real coding-agent CLIs through a Gauntlet QA agent and grades them against each scenario's acceptance criteria plus deterministic post-checks. Scenarios live at `evals/scenarios/<name>/`. See `evals/README.md` for setup, the container runtime, and the safety model. Quick start (local break-glass run):

```bash
cd evals
bun install
export SUPERPOWERS_ROOT=/path/to/superpowers
bun run quorum run scenarios/triggering-test-driven-development --coding-agent claude
bun run quorum show <run-dir>
```

Quorum scenarios are slow (3-30+ minutes each) and run real LLM sessions in permissive modes — read `evals/README.md`'s Live Eval Risk section first. Only the static gates (`bun run check`, `bun run quorum check`) are safe for public CI; the natural follow-up remains a tiered model (static gates on PR, live sweep nightly + on-demand).
