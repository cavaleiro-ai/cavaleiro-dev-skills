<!--
Read every section. Pull requests that leave sections blank, bundle unrelated
changes, or show no evidence of human review are closed without review.
Target `main`. If the problem also exists unchanged in the original project,
say so below — see CONTRIBUTING.md.
-->

## Who is submitting this PR? (required)

<!-- Agent-written contributions are welcome; hiding the authoring environment
     is not. If you wrote it by hand with no agent, say so. -->

| Field | Value |
|-------|-------|
| Model + version | |
| Harness + version | |
| All plugins installed | |
| Human who reviewed the complete diff | |

## What problem does this solve?

<!-- The specific problem someone actually hit: what they were doing, what went
     wrong, the exact failure. Link the issue: "Closes #123". "Improving"
     something is not a problem statement. -->

## What changed

<!-- 1-3 sentences, plus the files and contracts touched. Call out anything
     that touches identifiers other tools rely on (plugin id, skill names,
     script names, environment variables) — those normally must not change. -->

-

## Does the original project have this problem too?

- [ ] Only affects Cavaleiro Dev Skills
- [ ] Also affects the original project

## How it was verified

<!-- Paste the relevant output. Tick only what you actually ran. -->

- [ ] `bash tests/run-plugin-tests.sh` (or the suites listed here: …)
- [ ] `node tests/skills/validate-skills.mjs` and `bash tests/skills/test-skill-snippets.sh` (skill or manifest changes)
- [ ] Bug fix: a regression test that fails before the change and passes after it (name it)
- [ ] `bash scripts/lint-shell.sh <changed shell files>`
- [ ] `git diff --check`
- [ ] Exercised in a real harness session (harness, model, and what happened, below)

## Skill changes: evaluation

<!-- Skills are code that shapes agent behavior. If you changed skill text:
     what prompt started the session, how many sessions you ran after the
     change, and how outcomes differed from before. "It works" is not an
     evaluation. Do not modify carefully-tuned content (Red Flags tables,
     rationalization lists, "your human partner" language) without evidence. -->

## Risks and follow-ups

<!-- What could break, which harnesses you could not test, what remains. -->

## Checklist

- [ ] One problem per pull request.
- [ ] Line added under **Unreleased** in `CHANGELOG.md`.
- [ ] `README.md` and `README.pt-BR.md` kept aligned when the README changed.
- [ ] No secrets, private paths, personal settings, or caches added.
- [ ] Identifiers unchanged (plugin id `superpowers`, skill names, script and environment-variable names), or the change is explained above.
