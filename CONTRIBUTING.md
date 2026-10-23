# Contributing to Cavaleiro Dev Skills

Thanks for helping improve Cavaleiro Dev Skills. It is a library of
**skills** (Markdown that shapes how coding agents work), plus the small
amount of code that loads them into each harness: hooks, plugin manifests,
helper scripts, and the brainstorming visual companion.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
Report vulnerabilities privately, as described in the [security policy](SECURITY.md).

## Where to report

Open issues and pull requests **here**, in this repository's
[issue tracker](https://github.com/cavaleiro-ai/cavaleiro-dev-skills/issues).
If a problem also exists unchanged in the original project, say so in your
description. Never send this repository's changes (syncs, rebranding, or
fork-specific work) as pull requests to the original project.

## Ground rules

These carry over from the original project because they are what makes the
skills work.

1. **Skills are code.** Skill text shapes agent behavior. Do not reword,
   restructure, or "tidy" behavior-shaping content (Red Flags tables,
   rationalization lists, "your human partner" language) without evidence
   that the change improves outcomes.
2. **Identifiers are a contract.** The plugin id (`superpowers`), skill names,
   `superpowers:<skill>` references, script names, environment variables, and
   file layout are what harnesses and users depend on. Keep them unchanged;
   the [Compatibility](README.md#compatibility) section explains why.
3. **Zero dependencies.** The plugin has no runtime dependencies. Changes that
   need an external tool or service belong in their own plugin.
4. **General purpose.** Skills must help someone working on a completely
   different kind of project. Domain-, team-, or tool-specific skills belong
   in a separate plugin.
5. **Every harness.** A change to a skill or hook must keep working across the
   supported harnesses (Claude Code, Codex, Cursor, Gemini, OpenCode, Pi,
   Hermes, Kimi, Muse, and the others in the [README](README.md#installation)).
6. **Evidence over claims.** A bug fix comes with a regression test that fails
   before the fix and passes after it. Never weaken or delete an existing
   check to get a green run.
7. **Disclose how the change was made.** Say which model, harness, and
   plugins produced a contribution, or that it was written by hand. Agent
   work is welcome; hiding it is not.

## Run the tests

Plugin-infrastructure tests need no LLM session. One command runs them all and
skips (with the missing tool named) any suite whose optional tools you lack:

```bash
bash tests/run-plugin-tests.sh            # everything
bash tests/run-plugin-tests.sh --list     # suites and the tools each needs
bash tests/run-plugin-tests.sh 'skills|sdd'   # a subset, by name regex
```

Requirements: Bash (Git Bash on Windows), Git, Node.js 24 or newer. Optional,
per suite: Python 3 with `pytest`, `jq` and `yq` (mikefarah), Graphviz `dot`,
`rsync`, `zip`/`unzip`, and ShellCheck for `scripts/lint-shell.sh`.

When you change skill text, also run the static checks and the skill-snippet
tests directly — they are fast:

```bash
node tests/skills/validate-skills.mjs
bash tests/skills/test-skill-snippets.sh
```

Lint the shell scripts you changed:

```bash
bash scripts/lint-shell.sh path/to/changed-script
```

Skill-behavior evals run real coding-agent sessions and live in a separate
eval lab; see [docs/testing.md](docs/testing.md). They are slow, cost money,
and run agents in permissive modes — read that page before running them.

## Pull requests

- Target `main`. Keep each pull request focused on one problem.
- Fill in the [pull request template](.github/PULL_REQUEST_TEMPLATE.md),
  ticking only the checks you actually ran and pasting relevant output.
- Describe what you could not test, such as harnesses you do not have.
- Add a line under **Unreleased** in the [changelog](CHANGELOG.md).
- Before the first commit of a fresh copy on Windows, see
  [Executable bits](docs/cavaleiro/ENGINEERING.md#7-executable-bits): scripts must
  keep mode `100755` in Git.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE) of this repository.
