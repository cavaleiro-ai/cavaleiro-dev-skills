#!/usr/bin/env bash
# Run shell commands exactly as the skills print them, against fixture
# repositories, and check they answer the question the skill asks them.
#
# An agent copies these lines verbatim, so a command that answers the wrong
# question is a skill bug even when the prose around it is right.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKTREES_SKILL="$REPO_ROOT/skills/using-git-worktrees/SKILL.md"
FINISHING_SKILL="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "  [PASS] $1"; }
fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

# First line inside a fenced code block, after the heading that starts with
# $2, matching the ERE $3.
snippet() {
  awk -v heading="$2" -v pattern="$3" '
    index($0, heading) == 1 { insection = 1; next }
    insection && /^```/ { fence = !fence; next }
    insection && fence && $0 ~ pattern { print; exit }
  ' "$1"
}

new_repo() {
  git init -q -b main "$1"
  git -C "$1" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false \
    commit -q --allow-empty -m init
}

# Exit status of the skill's snippet, evaluated in repo $1 with LOCATION=$2.
ignore_check() {
  local repo="$1" location="$2" rc=0
  (cd "$repo" && export LOCATION="$location" && eval "$check_cmd") >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

echo "=== Test: skill shell snippets ==="

# --- using-git-worktrees: the ignore check (#2515) ---
check_cmd="$(snippet "$WORKTREES_SKILL" "#### Safety Verification" '^git check-ignore')"
if [[ -z "$check_cmd" ]]; then
  fail "using-git-worktrees prints a git check-ignore command"
else
  pass "using-git-worktrees prints a git check-ignore command"

  repo="$TEST_ROOT/only-other-ignored"
  new_repo "$repo"
  mkdir -p "$repo/.worktrees" "$repo/worktrees"
  printf 'worktrees/\n' > "$repo/.gitignore"
  if [[ "$(ignore_check "$repo" .worktrees)" -ne 0 ]]; then
    pass "check fails for .worktrees when only worktrees/ is ignored"
  else
    fail "check fails for .worktrees when only worktrees/ is ignored"
  fi

  repo="$TEST_ROOT/dir-pattern-before-mkdir"
  new_repo "$repo"
  printf '.worktrees/\n' > "$repo/.gitignore"
  if [[ "$(ignore_check "$repo" .worktrees)" -eq 0 ]]; then
    pass "check passes for a .worktrees/ pattern before the directory exists"
  else
    fail "check passes for a .worktrees/ pattern before the directory exists"
  fi

  repo="$TEST_ROOT/nothing-ignored"
  new_repo "$repo"
  mkdir -p "$repo/.worktrees"
  if [[ "$(ignore_check "$repo" .worktrees)" -ne 0 ]]; then
    pass "check fails when nothing is ignored"
  else
    fail "check fails when nothing is ignored"
  fi
fi

# --- finishing-a-development-branch: surviving SDD workspace (#2207) ---
main_repo="$TEST_ROOT/finish"
new_repo "$main_repo"
printf '.worktrees/\n' > "$main_repo/.gitignore"
git -C "$main_repo" worktree add -q "$main_repo/.worktrees/feature" -b feature
wt="$main_repo/.worktrees/feature"
mkdir -p "$wt/.superpowers/sdd/plan"
printf '*\n' > "$wt/.superpowers/sdd/.gitignore"
printf '# SDD ledger — plan: plan.md\nTask 1: Ruling: kept the old API — costs a rename later\n' \
  > "$wt/.superpowers/sdd/plan/progress.md"

if [[ -z "$(git -C "$wt" status --porcelain -uall)" ]]; then
  pass "fixture: git sees the worktree as clean, so removal would not be refused"
else
  fail "fixture: git sees the worktree as clean, so removal would not be refused"
fi

workspace_cmd="$(snippet "$FINISHING_SKILL" "## Step 6: Cleanup Workspace" '[.]superpowers/sdd')"
if [[ -z "$workspace_cmd" ]]; then
  fail "finishing-a-development-branch checks for a surviving .superpowers/sdd workspace"
else
  pass "finishing-a-development-branch checks for a surviving .superpowers/sdd workspace"
  found="$(export WORKTREE_PATH="$wt" && eval "$workspace_cmd")" || true
  if [[ "$found" == *".superpowers/sdd/plan"* ]]; then
    pass "workspace check reports the surviving plan workspace"
  else
    fail "workspace check reports the surviving plan workspace"
    echo "    got: $found"
  fi

  rm -rf "$wt/.superpowers/sdd/plan"
  found="$(export WORKTREE_PATH="$wt" && eval "$workspace_cmd")" || true
  if [[ -z "$found" ]]; then
    pass "workspace check is silent once the workspace was deleted"
  else
    fail "workspace check is silent once the workspace was deleted"
    echo "    got: $found"
  fi

  found="$(export WORKTREE_PATH="$TEST_ROOT/no-such-worktree" && eval "$workspace_cmd")" || true
  if [[ -z "$found" ]]; then
    pass "workspace check is silent for a worktree without .superpowers"
  else
    fail "workspace check is silent for a worktree without .superpowers"
  fi
fi

echo ""
if [[ "$FAILURES" -ne 0 ]]; then
  echo "FAILED: $FAILURES assertion(s)."
  exit 1
fi
echo "PASS"
