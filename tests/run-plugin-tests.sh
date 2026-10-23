#!/usr/bin/env bash
# Run every plugin-infrastructure test suite that needs no LLM session, and
# print one summary line per suite.
#
# Usage: tests/run-plugin-tests.sh [--list] [SUITE_REGEX]
#
# A suite whose required tools are missing is reported as SKIP (with the
# missing tool named) instead of failing, so the same command works on a
# minimal laptop and in CI. The exit status is non-zero only when a suite
# that could run failed. Full output for each suite is kept under
# $TEST_LOG_DIR (default: a temporary directory, printed at the end).
#
# Skill-behavior evals (real LLM sessions) are not run here; see
# docs/testing.md.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${TEST_LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"

list_only=false
filter=""
case "${1:-}" in
  --list) list_only=true ;;
  -h | --help)
    sed -n '2,/^[^#]/{/^#/s/^# \{0,1\}//p;}' "$0"
    exit 0
    ;;
  *) filter="${1:-}" ;;
esac

passed=0
failed=0
skipped=0
failed_names=()

# suite NAME "TOOL ..." COMMAND [ARGS...]
suite() {
  local name="$1" tools="$2"
  shift 2

  if [[ -n "$filter" && ! "$name" =~ $filter ]]; then
    return 0
  fi
  if [[ "$list_only" == true ]]; then
    printf '%-28s needs: %s\n' "$name" "${tools:-(nothing beyond bash)}"
    return 0
  fi

  # A tool named py:<module> is a Python module importable by python3.
  local tool missing=()
  for tool in $tools; do
    case "$tool" in
      py:*) python3 -c "import ${tool#py:}" >/dev/null 2>&1 || missing+=("$tool") ;;
      *) command -v "$tool" >/dev/null 2>&1 || missing+=("$tool") ;;
    esac
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'SKIP  %-28s missing: %s\n' "$name" "${missing[*]}"
    skipped=$((skipped + 1))
    return 0
  fi

  local log="$LOG_DIR/$name.log" start rc=0
  start=$SECONDS
  (cd "$ROOT" && "$@") >"$log" 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    printf 'PASS  %-28s %3ss\n' "$name" "$((SECONDS - start))"
    passed=$((passed + 1))
  else
    printf 'FAIL  %-28s %3ss  exit %s  (log: %s)\n' "$name" "$((SECONDS - start))" "$rc" "$log"
    failed=$((failed + 1))
    failed_names+=("$name")
  fi
}

brainstorm_server_tests() {
  cd tests/brainstorm-server || return 1
  if [[ ! -d node_modules ]]; then
    npm ci --no-audit --no-fund || return 1
  fi
  npm test
}

suite skills                  "node git"         bash tests/skills/run-tests.sh
suite muse                    "node"             bash tests/muse/test-muse-plugin.sh
suite hooks-session-start     "node"             bash tests/hooks/test-session-start.sh
suite hooks-run-hook-windows  ""                 bash tests/hooks/test-run-hook-cmd-windows.sh
suite brainstorm-server       "node npm"         brainstorm_server_tests
suite opencode                "node"             bash tests/opencode/run-tests.sh
suite pi                      "node"             node --test tests/pi/test-pi-extension.mjs
suite hermes                  "python3 py:pytest" python3 -m pytest tests/hermes -q -p no:cacheprovider
suite kimi                    "python3"          bash tests/kimi/run-tests.sh
suite antigravity             "python3"          bash tests/antigravity/run-tests.sh
suite devin                   "python3"          bash tests/devin/test-devin-plugin.sh
suite codex-marketplace       "python3"          bash tests/codex/test-marketplace-manifest.sh
suite codex-package           "python3 zip unzip" bash tests/codex/test-package-codex-plugin.sh
suite codex-plugin-sync       "python3 rsync"    bash tests/codex-plugin-sync/test-sync-to-codex-plugin.sh
suite diagnosing-superpowers  ""                 bash tests/diagnosing-superpowers/test-skill-structure.sh
suite shell-lint              ""                 bash tests/shell-lint/test-lint-shell.sh
suite find-polluter           ""                 bash tests/systematic-debugging/test-find-polluter.sh
suite version-bump            "jq yq"            bash tests/version-bump/test-bump-version.sh
suite render-graphs           "node dot"         bash tests/writing-skills/test-render-graphs.sh
suite executing-plans-scripts "git"              bash tests/claude-code/test-executing-plans-scripts.sh
suite sdd-workspace           "git"              bash tests/claude-code/test-sdd-workspace.sh
suite worktree-path-policy    ""                 bash tests/claude-code/test-worktree-path-policy.sh

if [[ "$list_only" == true ]]; then
  exit 0
fi

echo ""
echo "passed: $passed  failed: $failed  skipped: $skipped  (logs: $LOG_DIR)"
if [[ "$failed" -gt 0 ]]; then
  echo "failed suites: ${failed_names[*]}"
  exit 1
fi
