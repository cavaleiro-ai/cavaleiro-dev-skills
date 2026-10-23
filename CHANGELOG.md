# Changelog

All notable changes to Cavaleiro Dev Skills are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use [Semantic Versioning](https://semver.org/). Plugin manifests keep the original release version they are built on (see [Compatibility](README.md#compatibility)).

The original project's own release history, up to the 7.0.0 release this project is built on, is kept unchanged in [RELEASE-NOTES.md](RELEASE-NOTES.md).

## [Unreleased]

## Cavaleiro Dev Skills 1.0.0 — 2026-10-17

First release of Cavaleiro Dev Skills, based on the original project's release 7.0.0 (commit `bb92a77`). Evidence for every fix — failing-before and passing-after runs — is summarized in [docs/cavaleiro/ENGINEERING.md](docs/cavaleiro/ENGINEERING.md).

### Added

- `tests/run-plugin-tests.sh`: runs every plugin-infrastructure suite that needs no LLM session, prints one line per suite, and reports a suite whose optional tools are missing as SKIP instead of failing.
- `tests/skills/validate-skills.mjs`: zero-dependency static checks for every skill and manifest — frontmatter name matches its directory, description present and within 1024 characters, every `superpowers:<skill>` reference names a skill, relative links resolve, SDD/executing-plans helpers are referenced by `<skill-dir>` path, manifest paths exist, plugin ids stay `superpowers`, the Muse manifest lists every skill and runs bash hooks with bash, and declared versions are in sync.
- `tests/skills/test-skill-snippets.sh`: runs the shell commands that `using-git-worktrees` and `finishing-a-development-branch` print, exactly as printed, against fixture repositories.
- `tests/muse/test-muse-plugin.sh`: Muse manifest checks, and the SessionStart hook run exactly as the manifest declares it, with `sh` resolved to dash when dash is installed.
- Regression tests for each fix below, in the existing suites (`test-sdd-workspace.sh`, `test-executing-plans-scripts.sh`, `start-server.test.sh`, `test-render-graphs.sh`, `test-lint-shell.sh`, `test-bump-version.sh`).
- GitHub Actions workflow `.github/workflows/test.yml` (read-only token, commit-pinned actions) running the test runner, ShellCheck on shipped scripts, and a whitespace check; Dependabot for the actions and the test-only `ws` dependency.
- Community files: issue forms (bug, feature, harness support), pull request template, [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) with private reporting, and a Contributor Covenant 2.1 [code of conduct](CODE_OF_CONDUCT.md).
- Documentation: Portuguese README ([README.pt-BR.md](README.pt-BR.md)), a complete Portuguese guide ([docs/cavaleiro/GUIA-PT-BR.md](docs/cavaleiro/GUIA-PT-BR.md)), and engineering notes ([docs/cavaleiro/ENGINEERING.md](docs/cavaleiro/ENGINEERING.md)).

### Changed

- Rebranded the project as **Cavaleiro Dev Skills**: README, install instructions, inherited documentation, manifest `displayName`/`developerName`/author/homepage/repository fields, marketplace owners, and repository links now name Cavaleiro AI and point to `cavaleiro-ai/cavaleiro-dev-skills`. Plugin ids, skill names, script names, environment variables, file layout, and manifest versions are unchanged (see [Compatibility](README.md#compatibility)); the codex marketplace test now expects the new marketplace display name.
- `subagent-driven-development` and `executing-plans` (and the reviewer prompt templates) name their helpers as `bash <skill-dir>/scripts/<helper>` and say to run them from the project worktree, never from the skill's own directory. The old wording ("run `bash scripts/review-package …` from this skill's directory") pointed git at the plugin's own checkout (original issue #2525).
- `diagnosing-superpowers` searches and files issues in this repository instead of the original project's, so reports about this project do not land on the original tracker.
- `AGENTS.md` keeps the original project's contributor guidelines, adapted for this repository (pull requests target `main` here; never send fork changes to the original project).
- `docs/testing.md` documents the new runner and suites.

### Fixed

- **Muse:** the SessionStart hook ran the bash-only `hooks/session-start` with `sh`; where `/bin/sh` is dash (Debian, Ubuntu) it failed with "Bad substitution" and the bootstrap was never injected. The manifest now runs it with `bash` (original issue #2528).
- **task-brief:** the brief for Task 6 ran on into a following "Task 6b" section; the heading's whole task id is now compared as a string, so `6` and `6b` (and `1` and `1.2`) are distinct and regex characters in the task number are not patterns (original issue #2175).
- **sdd-workspace / review-package on greenfield projects:** before Task 1 ran `git init`, the helpers died with git's bare "fatal: not a git repository" (or silently used the current directory, depending on the bash version). `sdd-workspace` now uses the current directory and says so; `review-package` exits 2 with an actionable message (original issue #2242).
- **using-git-worktrees:** the ignore check passed when only the *other* candidate directory was ignored, and failed for a correctly configured `.worktrees/` pattern before the directory existed, prompting a needless `.gitignore` commit. It now checks the selected location with a trailing slash (original issue #2515).
- **finishing-a-development-branch:** worktree cleanup relied on `git worktree remove` refusing when unique files exist, but git ignores ignored files — so a surviving `.superpowers/sdd/` plan workspace (ledger, reports, rulings) was deleted without a prompt. The skill now checks for one first and asks (original issue #2207).
- **Visual companion:** `start-server.sh --project-dir <relative path>` failed ("No such file or directory" for `server.pid`/`server.log`, then "Server failed to start") because paths were used after the script changed directory; the project directory is now made absolute first (original issue #2524).
- **render-graphs.js:** a `SKILL.md` with CRLF line endings reported "No ```dot blocks found", and a diagram that failed to render still exited 0; CRLF fences are matched and render failures set exit status 1 (original issue #2519).
- **lint-shell.sh:** `--help` dropped the last line of the usage text; it now prints the whole header comment (original issue #2529).
- **bump-version.sh on Windows:** native Windows builds of jq and yq end lines with CRLF, so field names and versions carried a `\r` and even `--check` failed ("Error: no matches found"); tool output is now stripped of CR.
- **executing-plans:** `task-start` and `task-done` executed the sibling SDD helpers directly, so a marketplace package unpacked without exec bits broke them; they now run the helpers through bash, as the SDD scripts already did (same failure class as original issue #2040).

### Security

- **bump-version.sh:** the version argument was validated only at its start and then spliced into a jq program, so `2.3.4" | .name = "x` rewrote other manifest fields. It must now be a complete `X.Y.Z[-pre][+build]` version and is passed to jq with `--arg`; a failed write no longer leaves a `.tmp` file behind.
- **Fork safety — Codex sync:** `scripts/sync-to-codex-plugin.sh` hard-coded the original maintainers' fork of the Codex plugin marketplace and commit URLs of the original repository, so a full run from this repository would push a branch and open a pull request there. The target now comes from `CODEX_PLUGIN_FORK` (no default; dry runs still work without it) and PR bodies link this repository (`SOURCE_REPO_URL`).
- **Fork safety — original project infrastructure:** removed `.github/FUNDING.yml` and the original project's chat link from the issue chooser; the community files and security policy point to this repository.
- Documented that the visual companion's default logo request goes to the original authors' website with the plugin version, and how to opt out ([README](README.md#visual-companion-telemetry)).

[Unreleased]: https://github.com/cavaleiro-ai/cavaleiro-dev-skills/compare/v1.0.0...HEAD
