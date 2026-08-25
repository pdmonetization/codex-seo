#!/usr/bin/env bash
set -euo pipefail

# DataForSEO Extension Installer for Codex SEO
# Wraps everything in main() to prevent partial execution on network failure

main() {
    CODEX_ROOT="${CODEX_HOME:-${HOME}/.codex}"
    SKILLS_ROOT="${CODEX_ROOT}/skills"
    SKILL_DIR="${SKILLS_ROOT}/seo-dataforseo"
    AGENT_DIR="${CODEX_ROOT}/agents"
    SEO_SKILL_DIR="${SKILLS_ROOT}/seo"
    SETTINGS_FILE="${CODEX_ROOT}/settings.json"

    echo "════════════════════════════════════════"
    echo "║   DataForSEO Extension - Installer   ║"
    echo "║   For Codex SEO                     ║"
    echo "════════════════════════════════════════"
    echo ""

    # Support both traditional (curl|bash → ~/.codex/skills/seo) and marketplace
    # (plugin install → ~/.codex/plugins/cache/.../skills/seo) installations.
    # Resolve early using BASH_SOURCE so it works even when run from the plugin cache.
    _EARLY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _PLUGIN_SEO_DIR="$(cd "${_EARLY_SCRIPT_DIR}/../.." 2>/dev/null && pwd)/skills/seo"
    if [ ! -d "${SEO_SKILL_DIR}" ] && [ -d "${_PLUGIN_SEO_DIR}" ]; then
        SEO_SKILL_DIR="${_PLUGIN_SEO_DIR}"
    fi
    if [ ! -d "${SEO_SKILL_DIR}" ]; then
        _GLOB_MATCH=$(ls -d "${HOME}/.codex/plugins/cache/*/codex-seo/"*/skills/seo 2>/dev/null | tail -n1 || true)
        [ -n "${_GLOB_MATCH}" ] && [ -d "${_GLOB_MATCH}" ] && SEO_SKILL_DIR="${_GLOB_MATCH}"
    fi

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

    # Prompt for credentials
    echo ""
    echo "DataForSEO API credentials required."
    echo "Sign up at: https://app.dataforseo.com/register"
    echo ""

    read -rp "DataForSEO username (email): " DFSE_USERNAME
    if [ -z "${DFSE_USERNAME}" ]; then
        echo "✗ Username cannot be empty."
        exit 1
    fi

    read -rsp "DataForSEO password: " DFSE_PASSWORD
    echo ""
    if [ -z "${DFSE_PASSWORD}" ]; then
        echo "✗ Password cannot be empty."
        exit 1
    fi

    # Determine script directory (works for both ./install.sh and curl|bash)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if running from the repo, from an installed Codex SEO suite, or standalone.
    if [ -f "${SCRIPT_DIR}/../../skills/seo-dataforseo/SKILL.md" ]; then
        REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
        SKILL_SOURCE="${REPO_ROOT}/skills/seo-dataforseo/SKILL.md"
        AGENT_SOURCE="${REPO_ROOT}/agents/seo-dataforseo.toml"
        FIELD_CONFIG_SOURCE="${SCRIPT_DIR}/field-config.json"
    elif [ -f "${SCRIPT_DIR}/../../../seo-dataforseo/SKILL.md" ]; then
        SKILL_SOURCE="$(cd "${SCRIPT_DIR}/../../../seo-dataforseo" && pwd)/SKILL.md"
        AGENT_SOURCE="${AGENT_DIR}/seo-dataforseo.toml"
        FIELD_CONFIG_SOURCE="${SCRIPT_DIR}/field-config.json"
    elif [ -f "${SCRIPT_DIR}/skills/seo-dataforseo/SKILL.md" ]; then
        SKILL_SOURCE="${SCRIPT_DIR}/skills/seo-dataforseo/SKILL.md"
        AGENT_SOURCE="${SCRIPT_DIR}/agents/seo-dataforseo.toml"
        FIELD_CONFIG_SOURCE="${SCRIPT_DIR}/field-config.json"
    else
        echo "✗ Cannot find extension source files."
        echo "  Run this script from the codex-seo repo: ./extensions/dataforseo/install.sh"
        exit 1
    fi

    # Install skill
    echo ""
    echo "→ Installing DataForSEO skill..."
    mkdir -p "${SKILL_DIR}"
    cp "${SKILL_SOURCE}" "${SKILL_DIR}/SKILL.md"

    # Install agent
    echo "→ Installing DataForSEO agent..."
    mkdir -p "${AGENT_DIR}"
    if [ -f "${AGENT_SOURCE}" ] && [ "${AGENT_SOURCE}" != "${AGENT_DIR}/seo-dataforseo.toml" ]; then
        cp "${AGENT_SOURCE}" "${AGENT_DIR}/seo-dataforseo.toml"
    elif [ -f "${AGENT_DIR}/seo-dataforseo.toml" ]; then
        echo "  ✓ Codex TOML agent already installed"
    else
        echo "  ⚠  Codex TOML agent not found; reinstall the core Codex SEO suite if delegation is unavailable."
    fi

    # Install field config
    echo "→ Installing field config..."
    cp "${FIELD_CONFIG_SOURCE}" "${SEO_SKILL_DIR}/dataforseo-field-config.json"

    # Merge MCP config into settings.json
    echo "→ Configuring MCP server..."
    FIELD_CONFIG_PATH="${SEO_SKILL_DIR}/dataforseo-field-config.json"

    # Credentials are passed as argv (never interpolated into the source string)
    # and the settings file is written atomically with 0600 permissions.
    python3 - "${SETTINGS_FILE}" "${DFSE_USERNAME}" "${DFSE_PASSWORD}" "${FIELD_CONFIG_PATH}" <<'PY'
import json, os, sys, tempfile

settings_path, username, password, field_config = sys.argv[1:5]

if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except json.JSONDecodeError:
        settings = {}
else:
    settings = {}

settings.setdefault('mcpServers', {})['dataforseo'] = {
    'command': 'npx',
    'args': ['-y', 'dataforseo-mcp-server@2.8.10'],
    'env': {
        'DATAFORSEO_USERNAME': username,
        'DATAFORSEO_PASSWORD': password,
        'ENABLED_MODULES': 'SERP,KEYWORDS_DATA,ONPAGE,DATAFORSEO_LABS,BACKLINKS,DOMAIN_ANALYTICS,BUSINESS_DATA,CONTENT_ANALYSIS,AI_OPTIMIZATION',
        'FIELD_CONFIG_PATH': field_config,
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

print('  ✓ MCP server configured in settings.json')
PY
    if [ $? -ne 0 ]; then
        echo "  ⚠  Could not auto-configure MCP server."
        echo "  Add the dataforseo server manually to ~/.codex/settings.json"
        echo "  See: extensions/dataforseo/docs/DATAFORSEO-SETUP.md"
    fi

    # Pre-warm npm package without starting the MCP server binary.
    echo "→ Pre-downloading dataforseo-mcp-server..."
    npx --yes --package=dataforseo-mcp-server@2.8.10 -- node -e "" >/dev/null 2>&1 || true

    echo ""
    echo "✓ DataForSEO extension installed successfully!"
    echo ""
    echo "Usage:"
    echo "  1. Restart Codex CLI"
    echo "  2. Run commands:"
    echo "     /seo dataforseo serp best coffee shops"
    echo "     /seo dataforseo keywords seo tools"
    echo "     /seo dataforseo backlinks example.com"
    echo "     /seo dataforseo ai-mentions your brand"
    echo ""
    echo "All 23 commands: see extensions/dataforseo/README.md"
    echo "To uninstall: ./extensions/dataforseo/uninstall.sh"
}

main "$@"
