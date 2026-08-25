#!/usr/bin/env bash
set -euo pipefail

# Banana Image Generation Extension Installer for Codex SEO
# Wraps everything in main() to prevent partial execution on network failure

main() {
    CODEX_ROOT="${CODEX_HOME:-${HOME}/.codex}"
    SKILLS_ROOT="${CODEX_ROOT}/skills"
    SKILL_DIR="${SKILLS_ROOT}/seo-image-gen"
    AGENT_DIR="${CODEX_ROOT}/agents"
    SEO_SKILL_DIR="${SKILLS_ROOT}/seo"
    SETTINGS_FILE="${CODEX_ROOT}/settings.json"

    echo "════════════════════════════════════════"
    echo "║  Banana Image Gen - SEO Extension    ║"
    echo "║  For Codex SEO                      ║"
    echo "════════════════════════════════════════"
    echo ""

    # Check prerequisites
    if [ ! -d "${SEO_SKILL_DIR}" ]; then
        echo "✗ Codex SEO is not installed."
        echo "  Install it first: curl -fsSL https://raw.githubusercontent.com/pdmonetization/codex-seo/main/install.sh | bash"
        exit 1
    fi
    echo "✓ Codex SEO detected"

    if ! command -v node >/dev/null 2>&1; then
        echo "✗ Node.js is required but not installed."
        echo "  Install Node.js 20+: https://nodejs.org/"
        exit 1
    fi

    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "${NODE_VERSION}" -lt 20 ]; then
        echo "✗ Node.js 20+ required (found v${NODE_VERSION})."
        echo "  Update: https://nodejs.org/"
        exit 1
    fi
    echo "✓ Node.js v$(node -v | sed 's/v//') detected"

    if ! command -v npx >/dev/null 2>&1; then
        echo "✗ npx is required but not found (comes with npm)."
        exit 1
    fi
    echo "✓ npx detected"

    # Determine script directory (works for both ./install.sh and repo-relative paths)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if running from the repo, from an installed Codex SEO suite, or standalone.
    if [ -f "${SCRIPT_DIR}/../../skills/seo-image-gen/SKILL.md" ]; then
        REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
        SKILL_SOURCE="${REPO_ROOT}/skills/seo-image-gen/SKILL.md"
        AGENT_SOURCE="${REPO_ROOT}/agents/seo-image-gen.toml"
        ASSET_SOURCE="${SCRIPT_DIR}"
    elif [ -f "${SCRIPT_DIR}/../../../seo-image-gen/SKILL.md" ]; then
        SKILL_SOURCE="$(cd "${SCRIPT_DIR}/../../../seo-image-gen" && pwd)/SKILL.md"
        AGENT_SOURCE="${AGENT_DIR}/seo-image-gen.toml"
        ASSET_SOURCE="${SCRIPT_DIR}"
    elif [ -f "${SCRIPT_DIR}/skills/seo-image-gen/SKILL.md" ]; then
        SKILL_SOURCE="${SCRIPT_DIR}/skills/seo-image-gen/SKILL.md"
        AGENT_SOURCE="${SCRIPT_DIR}/agents/seo-image-gen.toml"
        ASSET_SOURCE="${SCRIPT_DIR}"
    else
        echo "✗ Cannot find extension source files."
        echo "  Run this script from the codex-seo repo: ./extensions/banana/install.sh"
        exit 1
    fi

    # Check if nanobanana-mcp is already configured
    MCP_CONFIGURED=false
    if [ -f "${SETTINGS_FILE}" ]; then
        if python3 - "${SETTINGS_FILE}" <<'PY' 2>/dev/null; then
import json, sys
settings_path = sys.argv[1]
with open(settings_path, 'r') as f:
    settings = json.load(f)
if 'mcpServers' in settings and 'nanobanana-mcp' in settings['mcpServers']:
    sys.exit(0)
else:
    sys.exit(1)
PY
            MCP_CONFIGURED=true
            echo "✓ nanobanana-mcp already configured in settings.json"
        fi
    fi

    # If MCP not configured, prompt for API key
    if [ "${MCP_CONFIGURED}" = false ]; then
        echo ""
        echo "Google AI API key required for image generation."
        echo "Get a free key at: https://aistudio.google.com/apikey"
        echo ""

        read -rsp "Google AI API key (GOOGLE_AI_API_KEY): " GOOGLE_AI_API_KEY
        echo ""
        if [ -z "${GOOGLE_AI_API_KEY}" ]; then
            echo "✗ API key cannot be empty."
            exit 1
        fi

        # Configure MCP server
        echo "→ Configuring nanobanana-mcp server..."
        # Credentials are passed as argv (never interpolated into the source string)
        # and the settings file is written atomically with 0600 permissions.
        python3 - "${SETTINGS_FILE}" "${GOOGLE_AI_API_KEY}" <<'PY'
import json, os, sys, tempfile

settings_path, api_key = sys.argv[1:3]

if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except json.JSONDecodeError:
        settings = {}
else:
    settings = {}

settings.setdefault('mcpServers', {})['nanobanana-mcp'] = {
    'command': 'npx',
    'args': ['-y', '@ycse/nanobanana-mcp@1.1.1'],
    'env': {
        'GOOGLE_AI_API_KEY': api_key,
    },
}

os.makedirs(os.path.dirname(settings_path) or '.', exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(settings_path) or '.', prefix='.settings.', suffix='.json')
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(settings, f, indent=2)
    os.chmod(tmp, 0o600)
    os.replace(tmp, settings_path)
except Exception:
    if os.path.exists(tmp):
        os.unlink(tmp)
    raise

print('  ✓ nanobanana-mcp configured in settings.json')
PY
        if [ $? -ne 0 ]; then
            echo "✗ Could not auto-configure MCP server."
            echo "  See: extensions/banana/docs/BANANA-SETUP.md"
            exit 1
        fi
    fi

    # Install skill
    echo ""
    echo "→ Installing seo-image-gen skill..."
    mkdir -p "${SKILL_DIR}"
    cp "${SKILL_SOURCE}" "${SKILL_DIR}/SKILL.md"

    # Install agent
    echo "→ Installing seo-image-gen agent..."
    mkdir -p "${AGENT_DIR}"
    if [ -f "${AGENT_SOURCE}" ] && [ "${AGENT_SOURCE}" != "${AGENT_DIR}/seo-image-gen.toml" ]; then
        cp "${AGENT_SOURCE}" "${AGENT_DIR}/seo-image-gen.toml"
    elif [ -f "${AGENT_DIR}/seo-image-gen.toml" ]; then
        echo "  ✓ Codex TOML agent already installed"
    else
        echo "  ⚠  Codex TOML agent not found; reinstall the core Codex SEO suite if delegation is unavailable."
    fi

    # Copy scripts and references to the installed skill directory.
    echo "→ Installing scripts and references..."
    mkdir -p "${SKILL_DIR}/scripts" "${SKILL_DIR}/references"
    cp "${ASSET_SOURCE}/scripts/"*.py "${SKILL_DIR}/scripts/"
    cp "${ASSET_SOURCE}/references/"*.md "${SKILL_DIR}/references/"

    # Rewrite only files copied by this extension install. Manual installs do
    # not receive plugin bin/ PATH injection.
    for installed_doc in "${SKILL_DIR}/SKILL.md" "${SKILL_DIR}/references/"*.md "${AGENT_DIR}/seo-image-gen.md"; do
        [ -f "${installed_doc}" ] || continue
        temp_doc="${installed_doc}.codex-seo-tmp"
        sed -e 's#codex-seo run#"$HOME/.codex/skills/seo/bin/codex-seo" run#g' \
            -e 's#codex-seo setup#"$HOME/.codex/skills/seo/bin/codex-seo" setup#g' \
            -e 's#codex-seo doctor#"$HOME/.codex/skills/seo/bin/codex-seo" doctor#g' \
            "${installed_doc}" > "${temp_doc}"
        mv "${temp_doc}" "${installed_doc}"
    done

    # Pre-warm npm package without starting the MCP server binary.
    echo "→ Pre-downloading nanobanana-mcp..."
    npx --yes --package=@ycse/nanobanana-mcp@1.1.1 -- node -e "" >/dev/null 2>&1 || true

    echo ""
    echo "✓ Banana Image Generation extension installed successfully!"
    echo ""
    echo "Usage:"
    echo "  1. Restart Codex CLI"
    echo "  2. Run commands:"
    echo "     /seo image-gen og \"Professional SaaS dashboard\""
    echo "     /seo image-gen hero \"Dramatic sunset over city skyline\""
    echo "     /seo image-gen product \"Wireless headphones on marble\""
    echo "     /seo image-gen infographic \"SEO ranking factors 2026\""
    echo "     /seo image-gen custom \"Any creative concept\""
    echo "     /seo image-gen batch \"Product variations\" 3"
    echo ""
    echo "Full docs: extensions/banana/README.md"
    echo "To uninstall: ./extensions/banana/uninstall.sh"
}

main "$@"
