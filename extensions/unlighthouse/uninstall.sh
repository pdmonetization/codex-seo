#!/usr/bin/env bash
set -euo pipefail
CODEX_ROOT="${CODEX_HOME:-${HOME}/.codex}"
SKILL_DIR="${CODEX_ROOT}/skills/seo-unlighthouse"
[ -d "${SKILL_DIR}" ] && rm -rf "${SKILL_DIR}" && echo "✓ Removed ${SKILL_DIR}"
echo "Done. (Nothing to remove from settings.json — Unlighthouse has no keys.)"
