# Cavaleiro Dev Skills — engineering notes

Release **Cavaleiro Dev Skills 1.0.0** (2026-10-17), based on the original
project at release 7.0.0, commit `bb92a77741419a4ab5f06e711a283343f1ada0c3`
(MIT License).

This document records how the project is built, the baseline measured before
any change, every finding and how it was verified, and what was deliberately
left alone. User-facing changes are in the [changelog](../../CHANGELOG.md).

## 1. Architecture map

Cavaleiro Dev Skills is not an application. It is a **skills library** (Markdown that
shapes agent behavior) plus thin, per-harness glue that (a) registers the
skills and (b) injects one bootstrap skill, `using-superpowers`, at session
start so the other skills trigger on their own.

```text
                         ┌──────────────────────────────────────────────┐
                         │ skills/<name>/SKILL.md  (+ prompts, scripts) │
                         │ 15 skills; using-superpowers = bootstrap     │
                         └───────────────▲──────────────────────────────┘
                                         │ read at session start / on demand
      ┌──────────────────────────────────┼───────────────────────────────────┐
      │ shell hook path                  │ in-process plugin path            │ manifest-only path
      │                                  │                                   │
 hooks/hooks.json (Claude Code,     .opencode/plugins/superpowers.js     .kimi-plugin (sessionStart.skill)
 Copilot CLI, Qwen, Droid)          (OpenCode V1+V2; index.js,           gemini-extension.json → GEMINI.md
 hooks/hooks-cursor.json (Cursor)    package.json "main")                 .antigravity-plugin, .codex-plugin,
 .muse-plugin hooks (Muse)          .pi/extensions/superpowers.ts (Pi)    .devin-plugin (skills dir only)
      │                             .hermes-plugin/__init__.py (Hermes)
      ▼                                  │
 hooks/run-hook.cmd  (cmd+bash polyglot; finds Git Bash on Windows)
      ▼                                  ▼
 hooks/session-start ──► JSON on stdout: additionalContext / additional_context /
                         hookSpecificOutput.additionalContext, chosen per harness env
```

**Components and responsibilities**

| Component | Responsibility | Entry point |
|-----------|----------------|-------------|
| `skills/` | 15 skills. Process skills (brainstorming → using-git-worktrees → writing-plans → subagent-driven-development / executing-plans → test-driven-development → requesting-code-review → finishing-a-development-branch), debugging skills, meta skills | `SKILL.md` frontmatter `name`/`description` drive discovery |
| `skills/subagent-driven-development/scripts/` | `sdd-workspace` (per-plan, self-ignoring workspace under `.superpowers/sdd/`), `task-brief` (extract one task from a plan), `review-package` (commit list + stat + diff for a reviewer) | run by the agent from the project worktree |
| `skills/executing-plans/scripts/` | `task-start` / `task-done`: brief + BASE in one call; run tests and append the ledger line | same |
| `skills/brainstorming/scripts/` | Visual companion: zero-dependency HTTP+WebSocket server (`server.cjs`), `start-server.sh` / `stop-server.sh`, browser helper and frame template | `start-server.sh` |
| `skills/writing-skills/render-graphs.js` | Render a skill's ```dot``` flowcharts to SVG with Graphviz | CLI |
| `hooks/` | SessionStart bootstrap for shell-hook harnesses | `run-hook.cmd session-start` |
| `.opencode/`, `index.js` | OpenCode plugin: registers skills (V1 config hook, V2 `ctx.skill.transform`) and injects the bootstrap into the first user message of top-level sessions only | default export `{id, server, setup}` |
| `.pi/extensions/superpowers.ts` | Pi extension: skill discovery path + bootstrap message, re-injected after compaction | `package.json` `pi` field |
| `.hermes-plugin/` | Hermes plugin: registers each skill with its description; `pre_llm_call` hook returns the bootstrap on the first turn | `register(ctx)` |
| Manifests | Per-harness metadata: plugin id `superpowers`, version, skills dir, hooks, display data | read by each harness |
| `scripts/` | Maintainer tooling: `bump-version.sh` (+ `.version-bump.json`), `lint-shell.sh`, `package-codex-plugin.sh`, `sync-to-codex-plugin.sh`, `render-antigravity-logo.sh` | manual |
| `tests/` | Plugin-infrastructure tests (bash/node/python, no LLM) and LLM-driven skill tests (`tests/claude-code`, `tests/explicit-skill-requests`) | per-directory runners; `tests/run-plugin-tests.sh` (new) |

**Control flow of a session.** The harness starts → the hook or plugin reads
`skills/using-superpowers/SKILL.md` → wraps it in `<EXTREMELY_IMPORTANT>` and
injects it (as hook JSON, a user message, or a system context, depending on
the harness) → the model follows `using-superpowers`, which tells it to check
for and load relevant skills before any response → process skills chain into
each other (`superpowers:<skill>` references) and call helper scripts.

**Extension points.** New skills are directories under `skills/` (and an
entry in `.muse-plugin/plugin.json`); new harnesses add a manifest and, if the
harness has no skills/hook support, a plugin module (see
[porting-to-a-new-harness.md](../porting-to-a-new-harness.md)). Per-harness
tool-name mappings live in `skills/using-superpowers/references/*-tools.md`.

**Configuration.** No config files. Environment variables:
`SUPERPOWERS_DISABLE_TELEMETRY` (and Claude Code's `DISABLE_TELEMETRY`,
`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`), `BRAINSTORM_*` for the visual
companion, and the harness variables the hook reads to pick an output shape
(`CLAUDE_PLUGIN_ROOT`, `CURSOR_PLUGIN_ROOT`, `COPILOT_CLI`, `MUSE_PLUGIN_ROOT`).

**Tests.** `tests/<area>/` per harness or script; `tests/brainstorm-server`
is the only one with a dependency (`ws`, test-only). Skill-behavior evals live
in a separate repository (`superpowers-evals`, cloned into `evals/`).

**Release pipeline (upstream).** `scripts/bump-version.sh X.Y.Z` updates
every manifest listed in `.version-bump.json` and audits for missed version
strings; Claude Code users install through a separate marketplace repository;
`scripts/package-codex-plugin.sh` builds the Codex package and
`scripts/sync-to-codex-plugin.sh` opens a sync PR in a Codex marketplace fork.
There are no GitHub Actions workflows upstream.

## 2. Baseline (before any change)

Environment: Windows 10, Git Bash 5.2.37, Node 24.15.0, Python 3.12, a
scratch virtualenv with `pytest` and `shellcheck-py` (ShellCheck 0.11.0),
jq 1.7.1 and mikefarah yq 4.44.3 (native Windows builds), and a portable
Graphviz 12.2.1 — all outside the repository, none installed globally. `dash`
ships with Git for Windows. Not available: `rsync`, `zip`, `opencode`, `agy`,
Docker. Commands were run on a byte-identical copy of the upstream tree.

| Suite (command) | Result | Notes |
|---|---|---|
| `bash tests/hooks/test-session-start.sh` | pass (13) | |
| `bash tests/hooks/test-run-hook-cmd-windows.sh` | pass (12) | runs only on Windows |
| `cd tests/brainstorm-server && npm ci && npm test` | **fail** | 109 node assertions pass; `lifecycle.test.js` 12/13 — "idle shutdown closes an open WebSocket" is timing-sensitive and flaky on this loaded machine (a later run also flaked "--idle-timeout-minutes sets the timeout", on unmodified upstream too). The `&&` chain then skips `start-server.test.sh`/`stop-server.test.sh`, which pass when run directly |
| `bash tests/brainstorm-server/windows-lifecycle.test.sh` | pass (13) | |
| `bash tests/opencode/run-tests.sh` | **fail** (2/4) | environment: `ln -s` in Git Bash copies instead of linking, so the plugin copy cannot find `../../skills` |
| `node --test tests/pi/test-pi-extension.mjs` | pass (6) | |
| `python -m pytest tests/hermes -q` | pass (25) | |
| `bash tests/kimi/run-tests.sh`, `tests/antigravity/run-tests.sh`, `tests/devin/test-devin-plugin.sh`, `tests/codex/test-marketplace-manifest.sh` | pass | `agy` validation skipped (not installed) |
| `bash tests/codex/test-package-codex-plugin.sh` | **fail** | environment: needs `zip`; Windows Python also cannot open the MSYS-style paths the test passes |
| `bash tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` | **fail** | environment: needs `rsync` |
| `bash tests/diagnosing-superpowers/test-skill-structure.sh` | pass (46) | |
| `bash tests/shell-lint/test-lint-shell.sh` | pass (18) | |
| `bash tests/systematic-debugging/test-find-polluter.sh` | pass (5) | |
| `bash tests/version-bump/test-bump-version.sh` | **fail** | real bug: CRLF from native Windows jq/yq (finding F9) |
| `bash tests/writing-skills/test-render-graphs.sh` | fail without Graphviz; pass (8) with it | |
| `bash tests/claude-code/test-executing-plans-scripts.sh` | pass (12) | |
| `bash tests/claude-code/test-sdd-workspace.sh` | pass (25) | |
| `bash tests/claude-code/test-worktree-path-policy.sh` | pass (9) | |
| `bash scripts/lint-shell.sh --all` | fail | 11 pre-existing ShellCheck warnings, all in `tests/claude-code/` LLM test helpers (not touched) |

LLM-driven suites (`tests/claude-code/run-skill-tests.sh`,
`tests/explicit-skill-requests/`) and the `superpowers-evals` quorum scenarios
were **not** run: they drive paid model sessions.

## 3. Findings

Sources: careful reading of every script, hook, plugin module, and manifest;
the original project's issue tracker (open issues labelled bug and recent reports with
reproductions); ShellCheck; a security pass over shell use, paths, and
network defaults; and fork-safety review.

| # | Finding | Severity | Status | Evidence / test |
|---|---------|----------|--------|-----------------|
| F1 | Muse hook runs bash-only `hooks/session-start` with `sh`; dies with "Bad substitution" where `sh` is dash (#2528) | High (bootstrap never loads on Debian/Ubuntu) | Fixed | `tests/muse/test-muse-plugin.sh`; validator rule `hook` |
| F2 | `task-brief` for Task 6 includes Task 6b (#2175) | Medium | Fixed | `test-sdd-workspace.sh` "stops before a sibling Task 6b" |
| F3 | SDD helpers die with git's bare fatal before `git init` (#2242) | Medium | Fixed | `test-sdd-workspace.sh` greenfield cases |
| F4 | Skills tell the agent to run git-dependent helpers "from this skill's directory" (#2525) | Medium (wrong repo diffed, or failure) | Fixed | validator rule `helper-path` (15 violations before, 0 after) |
| F5 | `using-git-worktrees` ignore check: false pass and false negative (#2515) | Medium (worktree contents committable) | Fixed | `test-skill-snippets.sh` |
| F6 | `finishing-a-development-branch` silently deletes a surviving `.superpowers/sdd/` workspace (#2207) | Medium (data loss) | Fixed | `test-skill-snippets.sh` |
| F7 | `start-server.sh` breaks with a relative `--project-dir` (#2524) | Low | Fixed | `start-server.test.sh` |
| F8 | `render-graphs.js` misses CRLF fences and exits 0 on failure (#2519) | Low | Fixed | `test-render-graphs.sh` |
| F9 | `bump-version.sh` broken with native Windows jq/yq (CRLF) | Low (maintainer tool) | Fixed | existing `test-bump-version.sh` fails before, passes after |
| F10 | `bump-version.sh` accepts `2.3.4" \| .name = "x` and splices it into jq | Low (local tool, input injection) | Fixed | `test-bump-version.sh` strict-version block |
| F11 | `lint-shell.sh --help` truncated (#2529) | Low | Fixed | `test-lint-shell.sh` |
| F12 | `task-start`/`task-done` exec sibling scripts directly; break when exec bits are stripped (#2040 class) | Low | Fixed | `test-executing-plans-scripts.sh` (discriminating on Linux/macOS only) |
| F13 | `sync-to-codex-plugin.sh` defaults to pushing and opening PRs in the original maintainers' fork | Fork safety | Fixed | scenario run with fake `gh`/`rsync` (§4) |
| F14 | `diagnosing-superpowers` files issues on the original project's tracker | Fork safety | Fixed | text change; `test-skill-structure.sh` still passes |
| F15 | Visual companion loads a logo from the original authors' site with the version (telemetry, on by default) | Info | Documented, unchanged | README "Visual companion telemetry" |
| F16 | Scripts lose their `100755` mode when this tree is first committed from Windows | Packaging | Documented | §7 |
| F17 | `hooks.json` has no `powershell` variant for VS Code Copilot on Windows (#2189) | Low | Not done | §5 |
| F18 | Pi's `stripFrontmatter` ignores CRLF (OpenCode's parser handles it) | Low | Not done | §5 |
| F19 | OpenCode/brainstorm/codex tests that fail only on Windows (symlinks, timing, MSYS paths) | Test infra | Not done | §2, §5 |

## 4. Improvements and how each was verified

Every fix has a regression test that fails on the original code and passes on
this tree. "Before" runs used the upstream scripts with the new tests copied
in; logs are summarized here.

1. **Muse hook interpreter** — `.muse-plugin/plugin.json:80` (`"sh"` → `"bash"`).
   Before: `test-muse-plugin.sh` → `sh hooks/session-start` exits 2, "hooks/session-start: 32: Bad substitution", 2 failures.
   After: exits 0 and prints `hookSpecificOutput` JSON containing the bootstrap; 3/3 pass.
2. **task-brief whole-id match** — `skills/subagent-driven-development/scripts/task-brief:30-41`: the heading's task id (`[0-9A-Za-z.]*[0-9A-Za-z]`) is compared to `TASK_NUMBER` as a string (portable awk: `sub`, `match`, `substr`).
   Before: the Task 6 brief contained "Six-b-only requirement text". After: Task 6 and Task 6b briefs are disjoint; Task 1 still does not match Task 12.
3. **Greenfield SDD** — `sdd-workspace:53` falls back to `pwd -P` with a stderr note; `review-package:25` checks `git rev-parse --git-dir` first and exits 2 with an actionable message.
   Before: stderr was git's "fatal: not a git repository"; `review-package` printed the fatal plus "bad BASE". After: 6 new assertions pass; all 25 earlier ones still pass (31 total + PASS line).
4. **Helper paths in skills** — `subagent-driven-development/SKILL.md:136-142, 257, 295, 322, 401, 453, 468, 515`, `executing-plans/SKILL.md:126-131, 177, 229, 241`, `re-review-prompt.md:112`, `task-reviewer-prompt.md:192, 203`: helpers are `bash <skill-dir>/scripts/<helper>`, run from the project worktree.
   Before: `validate-skills.mjs` reports 15 `helper-path` violations (plus the Muse hook). After: 167 checks pass.
5. **Worktree ignore check** — `using-git-worktrees/SKILL.md:80-84`: `git check-ignore -q "${LOCATION%/}/"`.
   Measured truth table (old → new exit status; 0 = ignored): only `worktrees/` ignored, LOCATION `.worktrees` → 0 → 1 (false pass fixed); `.worktrees/` pattern, directory absent → 1 → 0 (false negative fixed); `/.worktrees/` → 1 → 0; nothing ignored → 1 → 1.
   `test-skill-snippets.sh` extracts the command from the skill and runs it: 2 failures before, 0 after.
6. **Surviving SDD workspace** — `finishing-a-development-branch/SKILL.md:169-183`: `find "$WORKTREE_PATH/.superpowers/sdd" -mindepth 1 -maxdepth 1 -type d` before `git worktree remove`; anything printed is handled like a refused removal.
   The snippet test first proves the gap (`git status --porcelain -uall` is empty for a worktree holding a ledger), then that the skill's command reports the workspace and is silent once it is gone.
7. **Relative `--project-dir`** — `skills/brainstorming/scripts/start-server.sh:65-74`.
   Before: `BRAINSTORM_DIR=project/.superpowers/…` and "line 173: …/state/server.pid: No such file or directory"; 3 failures. After: 7/7 pass.
8. **render-graphs.js** — `skills/writing-skills/render-graphs.js:23` (`\r?\n`) and `:152, :165` (`process.exitCode = 1`).
   Before: 4 of 6 new assertions fail. After: 14/14 pass.
9. **bump-version.sh on Windows** — `scripts/bump-version.sh:24-31` (`no_cr`), applied to every jq/yq read.
   Before: `test-bump-version.sh` stops at `--check` with "Error: no matches found". After: passes with native (CRLF) jq/yq and with LF-mode jq (`jq -b`, which behaves like Linux/macOS builds).
10. **Strict version and `--arg`** — `scripts/bump-version.sh:43-53, 246-252`.
    Before (LF-mode jq): "FAIL: bump accepted a malformed version: 2.3.4" | .name = "pwned"". After: four malformed versions rejected with files byte-identical; `2.3.4-rc.1+build.5` accepted verbatim; no `.tmp` left behind.
11. **lint-shell.sh --help** — `scripts/lint-shell.sh:13-17`.
    Before: missing "baseline, or pass files explicitly to lint a smaller set." After: 4 new assertions pass.
12. **executing-plans exec bits** — `task-start:25`, `task-done:27`. Test copies the scripts, `chmod -x`, and runs through `bash`. On NTFS `chmod -x` has no effect, so this test passes before and after on Windows; it discriminates on Linux/macOS, where the identical SDD test (#2040) already guards the same failure.
13. **Codex sync fork guard** — `scripts/sync-to-codex-plugin.sh:36-41, 181-183, 238, 418`.
    Scenario (`git` + fake `gh` and `rsync`, local destination with a bare remote): the original, with nothing configured, pushed a branch and called `gh pr create` against the original maintainers' Codex marketplace fork with a commit link to the original repository. This tree's dry run prints `Fork: (unset …)`; the apply run stops with "CODEX_PLUGIN_FORK is not set" before creating a branch (0 remote branches, 0 gh calls); with `CODEX_PLUGIN_FORK=example-org/codex-plugins` it pushes and opens the PR there, linking `cavaleiro-ai/cavaleiro-dev-skills`. The suite `tests/codex-plugin-sync` (needs `rsync`) exercises only dry runs and the no-op apply, both of which exit before the guard.
14. **Test runner, validator, snippet test, CI** — `tests/run-plugin-tests.sh`, `tests/skills/`, `tests/muse/`, `.github/workflows/test.yml`. The validator was mutation-checked: renaming a skill's frontmatter, breaking a link, referencing a skill that does not exist, bumping one manifest version, and pointing a logo at a missing file each produced exactly one report.

**Final run on this tree** (same environment, `bash tests/run-plugin-tests.sh`):
see the results recorded in §8.

## 5. What was not done, and why

- **No LLM evals.** Skill-text changes (F4–F6, F14) were verified with static and
  snippet tests, not with live agent sessions; upstream's bar for behavior-shaping
  text is eval evidence. The changes are limited to commands and paths that were
  mechanically wrong, plus one added check before a destructive step; no
  rationalization tables or "human partner" language were touched.
- **#2189 (`powershell` key in `hooks.json`)**: could not verify which hook
  schema VS Code Copilot accepts on Windows; a wrong key could break Claude Code
  hook parsing.
- **#2247 (Antigravity hooks)**: agy has no session-start event; nothing to fix
  in this repository without a harness change.
- **Pi CRLF frontmatter (F18)**: `.gitattributes` forces LF for `*.md` and
  `git archive` honors it, so no supported install path produces CRLF; left as is.
- **OpenCode/brainstorm/codex Windows test failures (F19)**: environment-specific
  (symlinks, process timing, `zip`/`rsync`, MSYS paths in embedded Python). Not
  product bugs; changing the tests' structure was out of scope.
- **In-product branding**: app icons, the visual companion header, and the
  "You have superpowers." bootstrap line are unchanged, to avoid changing agent
  behavior and because the icons are upstream artwork.
- **Telemetry**: unchanged and documented; it was not repointed.
- **The original project's `dev` branch, marketplace, and eval repositories**:
  not mirrored; install instructions use this repository.

## 6. Known limitations

- Install commands for harnesses not available here (Codex local marketplaces,
  Cursor local install, Droid, Copilot CLI, Qwen, Muse, Hermes, Kimi, Pi) follow
  the upstream patterns with this repository's URL but were not exercised.
- Installing both the original project and this derivative in the same harness
  registers the same plugin id and skills twice; the README says to pick one.
- On Windows, `tests/run-plugin-tests.sh` reports `opencode` as FAIL (Git Bash
  `ln -s` copies instead of linking) and `brainstorm-server` intermittently
  (two timing-sensitive lifecycle tests), for the environment reasons in §2.
- The CI workflow was written to run on `ubuntu-latest` but could not be run
  from this machine.

## 7. Executable bits

Git for Windows checks out with `core.filemode=false`, so a tree copied on
Windows and committed from there records every file as `100644`. Upstream
tracks 55 files as `100755`, among them `hooks/run-hook.cmd` and
`hooks/session-start`, which Claude Code on Linux/macOS executes directly.
Upstream's executable set is exactly "every file that starts with `#!`, plus
the polyglot `hooks/run-hook.cmd`" (three shebang test scripts upstream leaves
at `100644` are the only exceptions; marking them too is harmless). Before the
first commit of this tree, restore the bits:

```bash
git add -A
{ git ls-files | while IFS= read -r f; do
    head -c2 "$f" | grep -q '#!' && printf '%s\0' "$f"
  done
  printf '%s\0' hooks/run-hook.cmd
} | xargs -0 git update-index --chmod=+x
git ls-files -s | grep -c '^100755'   # expect 63: upstream's 55, its 3 shebang test scripts, 5 new scripts
```

## 8. Final results

Recorded after all changes, same environment as the baseline, with
`bash tests/run-plugin-tests.sh` (PATH extended with the scratch jq, yq,
ShellCheck/pytest virtualenv, and portable Graphviz):

| Suite | Baseline | Final |
|---|---|---|
| skills (new: validator + snippets) | — (fails on upstream: 16 validator problems, 3 snippet failures) | pass (169 checks; 9 snippet assertions) |
| muse (new) | — (fails on upstream: 2 of 3) | pass (3) |
| hooks-session-start | pass | pass |
| hooks-run-hook-windows | pass | pass |
| brainstorm-server (`npm test`) | fail (flaky lifecycle timing; chain skipped the shell tests) | pass in the final run: 109 node assertions, lifecycle 13/13, `start-server.test.sh` 7/7 (3 new), `stop-server.test.sh` 7/7. The two lifecycle timing tests also flaked once on this tree and once on unmodified upstream under load |
| opencode | fail (symlinks) | fail (symlinks) |
| pi, hermes, kimi, antigravity, devin, codex-marketplace | pass | pass |
| codex-package, codex-plugin-sync | fail (no `zip`/`rsync`) | SKIP (missing `zip` / `rsync`) |
| diagnosing-superpowers | pass | pass |
| shell-lint | pass (18) | pass (22) |
| find-polluter | pass | pass |
| version-bump | **fail** (CRLF bug) | pass |
| render-graphs (with Graphviz) | pass (8) | pass (14) |
| executing-plans-scripts | pass (12) | pass (14) |
| sdd-workspace | pass (25) | pass (31) |
| worktree-path-policy | pass | pass |

ShellCheck (`--severity=warning`) is clean on every shell file this release
added or changed.
