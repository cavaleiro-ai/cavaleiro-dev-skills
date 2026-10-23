#!/usr/bin/env bash
# Validate the Muse plugin manifest and run its SessionStart hook exactly as
# the manifest declares it.
#
# hooks/session-start is a bash script (pattern substitution, $(<file),
# pipefail). Muse runs the manifest's command array verbatim, so a `sh`
# interpreter breaks the bootstrap wherever /bin/sh is dash — Debian and
# Ubuntu — with "Bad substitution" before any JSON is printed. When dash is
# installed, this test resolves `sh` to dash so the failure reproduces on any
# host, not only on Debian-family Linux.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$REPO_ROOT/.muse-plugin/plugin.json"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "  [PASS] $1"; }
fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

echo "=== Test: Muse plugin ==="

# --- manifest shape and skill list ---------------------------------------
read -r -d '' check_manifest_js <<'JS' || true
const fs = require('fs');
const path = require('path');
const root = process.argv[1];
const problems = [];
const manifest = JSON.parse(fs.readFileSync(path.join(root, '.muse-plugin/plugin.json'), 'utf8'));
JSON.parse(fs.readFileSync(path.join(root, '.muse-plugin/marketplace.json'), 'utf8'));
if (manifest.name !== 'superpowers') problems.push(`plugin name is ${manifest.name}`);
const listed = new Map((manifest.capabilities?.skills ?? []).map((s) => [s.id, s.path]));
const onDisk = fs.readdirSync(path.join(root, 'skills'), { withFileTypes: true })
  .filter((e) => e.isDirectory() && fs.existsSync(path.join(root, 'skills', e.name, 'SKILL.md')))
  .map((e) => e.name);
for (const name of onDisk) {
  if (!listed.has(name)) problems.push(`skill ${name} is not listed in capabilities.skills`);
}
for (const [id, rel] of listed) {
  if (!fs.existsSync(path.join(root, rel))) problems.push(`skill ${id} points at missing ${rel}`);
}
const hooks = manifest.capabilities?.hooks ?? [];
if (!hooks.some((h) => h.event === 'SessionStart')) problems.push('no SessionStart hook');
if (problems.length) {
  console.log(problems.join('\n'));
  process.exit(1);
}
JS
if manifest_report="$(node -e "$check_manifest_js" "$REPO_ROOT" 2>&1)"; then
  pass "manifest parses and lists every skill directory"
else
  fail "manifest parses and lists every skill directory"
  printf '%s\n' "$manifest_report" | sed 's/^/    /'
fi

# --- run the SessionStart hook as declared --------------------------------
shim_dir="$TEST_ROOT/shim-bin"
mkdir -p "$shim_dir"
sh_note="system sh"
if command -v dash >/dev/null 2>&1; then
  dash_bin="$(command -v dash)"
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$dash_bin" > "$shim_dir/sh"
  chmod +x "$shim_dir/sh"
  sh_note="sh resolved to dash"
fi

hook_cmd=()
while IFS= read -r -d '' arg; do
  hook_cmd+=("$arg")
done < <(node -e '
const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const hook = m.capabilities.hooks.find((h) => h.event === "SessionStart");
for (const arg of hook.command) process.stdout.write(arg + "\0");
' "$MANIFEST")

hook_rc=0
hook_out="$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT -u CURSOR_PLUGIN_ROOT -u COPILOT_CLI \
  MUSE_PLUGIN_ROOT="$REPO_ROOT" PATH="$shim_dir:$PATH" "${hook_cmd[@]}" 2>&1)" || hook_rc=$?

if [[ "$hook_rc" -eq 0 ]]; then
  pass "SessionStart hook command exits 0 ($sh_note): ${hook_cmd[*]}"
else
  fail "SessionStart hook command exits 0 ($sh_note): ${hook_cmd[*]}"
  echo "    exit: $hook_rc"
  printf '%s\n' "$hook_out" | head -5 | sed 's/^/    /'
fi

if printf '%s' "$hook_out" | node -e '
const input = require("fs").readFileSync(0, "utf8");
const payload = JSON.parse(input);
const ctx = payload.hookSpecificOutput && payload.hookSpecificOutput.additionalContext;
if (payload.hookSpecificOutput.hookEventName !== "SessionStart") process.exit(1);
if (typeof ctx !== "string" || !ctx.includes("using-superpowers")) process.exit(1);
' 2>/dev/null; then
  pass "SessionStart hook prints the bootstrap as hookSpecificOutput JSON"
else
  fail "SessionStart hook prints the bootstrap as hookSpecificOutput JSON"
fi

echo ""
if [[ "$FAILURES" -ne 0 ]]; then
  echo "FAILED: $FAILURES assertion(s)."
  exit 1
fi
echo "PASS"
