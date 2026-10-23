#!/usr/bin/env bash
# Fast tests for start-server.sh shell-only platform decisions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
START_SCRIPT="$REPO_ROOT/skills/brainstorming/scripts/start-server.sh"

TEST_DIR="${TMPDIR:-/tmp}/brainstorm-start-test-$$"
passed=0
failed=0

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

pass() {
  echo "  PASS: $1"
  passed=$((passed + 1))
}

fail() {
  echo "  FAIL: $1"
  echo "    $2"
  failed=$((failed + 1))
}

make_fake_uname() {
  local fake_bin="$1"
  cat > "$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-s" ]]; then
  echo "MINGW64_NT-10.0"
else
  /usr/bin/uname "$@"
fi
EOF
  chmod +x "$fake_bin/uname"
}

echo ""
echo "--- start-server.sh platform detection ---"

mkdir -p "$TEST_DIR/fake-bin" "$TEST_DIR/project"
make_fake_uname "$TEST_DIR/fake-bin"

cat > "$TEST_DIR/fake-bin/node" <<'EOF'
#!/usr/bin/env bash
echo "CAPTURED_OWNER_PID=${BRAINSTORM_OWNER_PID:-__UNSET__}"
printf 'CAPTURED_ARGV=%s\n' "$@"
exit 0
EOF
chmod +x "$TEST_DIR/fake-bin/node"

captured=$(
  PATH="$TEST_DIR/fake-bin:$PATH" \
    MSYSTEM="" \
    bash "$START_SCRIPT" --project-dir "$TEST_DIR/project" --foreground 2>/dev/null || true
)
owner_pid_value=$(echo "$captured" | grep "CAPTURED_OWNER_PID=" | head -1 | sed 's/CAPTURED_OWNER_PID=//')

if [[ "$owner_pid_value" == "" || "$owner_pid_value" == "__UNSET__" ]]; then
  pass "clears BRAINSTORM_OWNER_PID when uname reports a Windows-like shell"
else
  fail "clears BRAINSTORM_OWNER_PID when uname reports a Windows-like shell" \
       "expected empty or unset, got '$owner_pid_value'"
fi

if echo "$captured" | grep -Eq '^CAPTURED_ARGV=--brainstorm-server-id=[A-Za-z0-9_-]{32,64}$'; then
  pass "passes shell-safe server instance id argv"
else
  fail "passes shell-safe server instance id argv" \
       "expected exact --brainstorm-server-id=<safe id> argv line, got: $captured"
fi

server_id_file=$(find "$TEST_DIR/project/.superpowers/brainstorm" -name server-instance-id -print 2>/dev/null | head -1)
server_id_value=""
if [[ -n "$server_id_file" ]]; then
  server_id_value="$(tr -d '\r\n' < "$server_id_file")"
fi
if [[ "$server_id_value" =~ ^[A-Za-z0-9_-]{32,64}$ ]]; then
  pass "writes shell-safe server-instance-id state file"
else
  fail "writes shell-safe server-instance-id state file" \
       "expected valid id in state, got '$server_id_value'"
fi

rm -rf "$TEST_DIR/project"/*

cat > "$TEST_DIR/fake-bin/node" <<'EOF'
#!/usr/bin/env bash
echo "FOREGROUND_MODE=true"
exit 0
EOF
chmod +x "$TEST_DIR/fake-bin/node"

captured=$(
  PATH="$TEST_DIR/fake-bin:$PATH" \
    MSYSTEM="" \
    bash "$START_SCRIPT" --project-dir "$TEST_DIR/project" 2>/dev/null || true
)

if echo "$captured" | grep -q "FOREGROUND_MODE=true"; then
  pass "auto-foregrounds when uname reports a Windows-like shell"
else
  fail "auto-foregrounds when uname reports a Windows-like shell" \
       "expected foreground node path, got: $captured"
fi

echo ""
echo "--- start-server.sh relative --project-dir (#2524) ---"

# The script cds into its own directory before starting node, so a relative
# --project-dir must be resolved against the caller's directory first.
rm -rf "$TEST_DIR/project"/* "$TEST_DIR/project"/.superpowers

cat > "$TEST_DIR/fake-bin/node" <<'EOF'
#!/usr/bin/env bash
echo "CAPTURED_DIR=${BRAINSTORM_DIR:-__UNSET__}"
echo "CAPTURED_PORT_FILE=${BRAINSTORM_PORT_FILE:-__UNSET__}"
exit 0
EOF
chmod +x "$TEST_DIR/fake-bin/node"

project_abs="$(cd "$TEST_DIR/project" && pwd)"
captured=$(
  cd "$TEST_DIR" && PATH="$TEST_DIR/fake-bin:$PATH" \
    bash "$START_SCRIPT" --project-dir project --foreground 2>&1 || true
)
captured_dir=$(echo "$captured" | grep "CAPTURED_DIR=" | head -1 | sed 's/CAPTURED_DIR=//')
captured_port_file=$(echo "$captured" | grep "CAPTURED_PORT_FILE=" | head -1 | sed 's/CAPTURED_PORT_FILE=//')

if [[ "$captured_dir" == "$project_abs/.superpowers/brainstorm/"* ]]; then
  pass "relative --project-dir reaches the server as an absolute session dir"
else
  fail "relative --project-dir reaches the server as an absolute session dir" \
       "expected $project_abs/.superpowers/brainstorm/<id>, got '$captured_dir'"
fi

if [[ "$captured_port_file" == "$project_abs/.superpowers/brainstorm/.last-port" ]]; then
  pass "relative --project-dir persists the port file under the project"
else
  fail "relative --project-dir persists the port file under the project" \
       "expected $project_abs/.superpowers/brainstorm/.last-port, got '$captured_port_file'"
fi

pid_file=$(find "$TEST_DIR/project/.superpowers/brainstorm" -name server.pid -print 2>/dev/null | head -1)
if [[ -n "$pid_file" ]] && ! echo "$captured" | grep -q "No such file or directory"; then
  pass "relative --project-dir writes server.pid under the project"
else
  fail "relative --project-dir writes server.pid under the project" \
       "pid file: '${pid_file:-missing}', output: $captured"
fi

echo ""
echo "--- Results: $passed passed, $failed failed ---"
if [[ $failed -gt 0 ]]; then
  exit 1
fi
