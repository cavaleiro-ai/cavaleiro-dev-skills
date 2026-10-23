#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_SOURCE="$REPO_ROOT/scripts/bump-version.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_fixture() {
  local repo="$1"
  local yaml_body="$2"

  mkdir -p "$repo/scripts" "$repo/.hermes-plugin"
  cp "$SCRIPT_SOURCE" "$repo/scripts/bump-version.sh"
  cat >"$repo/.version-bump.json" <<'JSON'
{
  "files": [
    { "path": "package.json", "field": "version" },
    { "path": ".hermes-plugin/plugin.yaml", "field": "version" }
  ],
  "audit": { "exclude": [] }
}
JSON
  cat >"$repo/package.json" <<'JSON'
{
  "name": "fixture",
  "version": "1.2.3"
}
JSON
  printf '%s\n' "$yaml_body" >"$repo/.hermes-plugin/plugin.yaml"
}

happy_repo="$TEST_ROOT/happy"
make_fixture "$happy_repo" $'name: superpowers\nversion: 1.2.3'

/bin/bash "$happy_repo/scripts/bump-version.sh" --check >"$TEST_ROOT/check.out"
/bin/bash "$happy_repo/scripts/bump-version.sh" --audit >"$TEST_ROOT/audit.out"
/bin/bash "$happy_repo/scripts/bump-version.sh" 2.3.4 >"$TEST_ROOT/bump.out"

# tr -d '\r': native Windows jq/yq builds end output lines with CRLF.
[[ "$(jq -r '.version' "$happy_repo/package.json" | tr -d '\r')" == "2.3.4" ]] \
  || fail "JSON manifest was not bumped"
[[ "$(yq -r '.version' "$happy_repo/.hermes-plugin/plugin.yaml" | tr -d '\r')" == "2.3.4" ]] \
  || fail "YAML manifest was not bumped"

jq -e '
  any(.files[];
    .path == ".hermes-plugin/plugin.yaml" and .field == "version")
' "$REPO_ROOT/.version-bump.json" >/dev/null \
  || fail "Hermes manifest is not registered"

invalid_repo="$TEST_ROOT/invalid"
make_fixture "$invalid_repo" $'name: superpowers\nversion: 123'
cp "$invalid_repo/package.json" "$TEST_ROOT/package.before"
cp "$invalid_repo/.hermes-plugin/plugin.yaml" "$TEST_ROOT/plugin.before"

if /bin/bash "$invalid_repo/scripts/bump-version.sh" 2.3.4 \
  >"$TEST_ROOT/invalid.out" 2>&1; then
  fail "bump accepted a non-string YAML version"
fi

cmp -s "$TEST_ROOT/package.before" "$invalid_repo/package.json" \
  || fail "JSON manifest changed before YAML validation failed"
cmp -s "$TEST_ROOT/plugin.before" "$invalid_repo/.hermes-plugin/plugin.yaml" \
  || fail "invalid YAML manifest changed"

audit_repo="$TEST_ROOT/audit-boundaries"
make_fixture "$audit_repo" $'name: superpowers\nversion: 1.2.3'
/bin/bash "$audit_repo/scripts/bump-version.sh" 4.0.0 >/dev/null
printf 'host = "10.4.0.0"\n' >"$audit_repo/server.js"
printf 'pin: superpowers.git#v4.0.0\n' >"$audit_repo/INSTALL.md"
/bin/bash "$audit_repo/scripts/bump-version.sh" --audit >"$TEST_ROOT/audit-boundaries.out"

grep -q 'INSTALL.md' "$TEST_ROOT/audit-boundaries.out" \
  || fail "audit missed an undeclared #v4.0.0 pin"
if grep -q 'server.js' "$TEST_ROOT/audit-boundaries.out"; then
  fail "audit flagged 10.4.0.0 as version 4.0.0"
fi

# The version argument is data, never jq program text: a check anchored only
# at the start let `2.3.4" | .name = "pwned` through to rewrite other fields.
strict_repo="$TEST_ROOT/strict-version"
make_fixture "$strict_repo" $'name: superpowers\nversion: 1.2.3'
cp "$strict_repo/package.json" "$TEST_ROOT/strict.package.before"
cp "$strict_repo/.hermes-plugin/plugin.yaml" "$TEST_ROOT/strict.plugin.before"
for bad_version in '2.3.4" | .name = "pwned' '2.3.4 extra' '2.3.4-' 'v2.3.4'; do
  if /bin/bash "$strict_repo/scripts/bump-version.sh" "$bad_version" \
    >"$TEST_ROOT/strict.out" 2>&1; then
    fail "bump accepted a malformed version: $bad_version"
  fi
  cmp -s "$TEST_ROOT/strict.package.before" "$strict_repo/package.json" \
    || fail "malformed version changed package.json: $bad_version"
  cmp -s "$TEST_ROOT/strict.plugin.before" "$strict_repo/.hermes-plugin/plugin.yaml" \
    || fail "malformed version changed plugin.yaml: $bad_version"
done

/bin/bash "$strict_repo/scripts/bump-version.sh" 2.3.4-rc.1+build.5 >/dev/null \
  || fail "bump rejected a SemVer pre-release version"
[[ "$(jq -r '.version' "$strict_repo/package.json" | tr -d '\r')" == "2.3.4-rc.1+build.5" ]] \
  || fail "pre-release version was not written verbatim"
[[ "$(jq -r '.name' "$strict_repo/package.json" | tr -d '\r')" == "fixture" ]] \
  || fail "bump changed a field other than the version"
if [[ -n "$(find "$strict_repo" -name '*.tmp')" ]]; then
  fail "bump left a .tmp file behind"
fi

echo "Version-bump tests passed"
