#!/usr/bin/env bash
# Skill-library checks that need no LLM: static validation of skills and
# manifests, then the skills' own shell snippets against fixture repos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

node "$SCRIPT_DIR/validate-skills.mjs"
bash "$SCRIPT_DIR/test-skill-snippets.sh"
