#!/usr/bin/env bash
#
# setup.sh — Build social media MCP Docker images and register them
#             in the Docker MCP Gateway.
#
# Only builds/enables servers that have credentials in .env.
# Re-run after adding new credentials to activate more platforms.
#
# Usage:
#   1. Fill in .env with your platform credentials
#   2. Run: bash setup.sh
#
# Prerequisites:
#   - Docker Desktop with MCP Gateway support
#   - An existing Docker MCP Gateway setup
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_NAME="social-media"
ENV_FILE="${SCRIPT_DIR}/.env"

# =========================================================================
# Helper functions
# =========================================================================

build_image() {
  local name="$1"
  local context="$2"
  echo "  Building ${name}..."
  docker build -t "${name}" "${context}" --quiet
  echo "  ✓ ${name}"
}

set_secrets_for_server() {
  # The secret name in the store must exactly match the "name" field in the
  # catalog YAML.  Our catalog uses "servername.lowercase_var" format
  # (e.g. substack.substack_publication_url) matching the Docker MCP
  # convention (like github.personal_access_token).
  local server_name="$1"
  shift
  local var_names=("$@")

  for var in "${var_names[@]}"; do
    local val="${!var:-}"
    if [[ -n "${val}" ]]; then
      local secret_key
      secret_key="${server_name}.$(echo "${var}" | tr '[:upper:]' '[:lower:]')"
      printf '%s' "${val}" | docker mcp secret set "${secret_key}"
      echo "    ✓ ${secret_key}"
    fi
  done
}

# Returns 0 (true) if ANY of the listed env vars have a non-empty value
has_credentials() {
  local var_names=("$@")
  for var in "${var_names[@]}"; do
    if [[ -n "${!var:-}" ]]; then
      return 0
    fi
  done
  return 1
}

# =========================================================================
# Load environment variables
# =========================================================================

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found."
  echo "Copy .env.example to .env and fill in your credentials first."
  exit 1
fi

# Source the env file (skip comments and empty lines)
set -a
while IFS='=' read -r key value; do
  [[ -z "${key}" || "${key}" =~ ^[[:space:]]*# ]] && continue
  # Strip quotes
  value="${value%\"}" ; value="${value#\"}"
  value="${value%\'}" ; value="${value#\'}"
  export "${key}=${value}"
done < "${ENV_FILE}"
set +a

# =========================================================================
# Define which env vars belong to each server
# =========================================================================

CROSSPOST_VARS=(
  TWITTER_API_CONSUMER_KEY TWITTER_API_CONSUMER_SECRET
  TWITTER_ACCESS_TOKEN_KEY TWITTER_ACCESS_TOKEN_SECRET
  MASTODON_HOST MASTODON_ACCESS_TOKEN
  BLUESKY_HOST BLUESKY_IDENTIFIER BLUESKY_PASSWORD
  LINKEDIN_ACCESS_TOKEN
  DISCORD_BOT_TOKEN DISCORD_CHANNEL_ID DISCORD_WEBHOOK_URL
  DEVTO_API_KEY
  TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
  SLACK_TOKEN SLACK_CHANNEL
  NOSTR_PRIVATE_KEY NOSTR_RELAYS
)

SUBSTACK_VARS=(SUBSTACK_PUBLICATION_URL SUBSTACK_SESSION_TOKEN SUBSTACK_USER_ID)
MEDIUM_VARS=(MEDIUM_TOKEN)
REDDIT_VARS=(REDDIT_CLIENT_ID REDDIT_CLIENT_SECRET REDDIT_USERNAME REDDIT_PASSWORD REDDIT_USER_AGENT)
FACEBOOK_VARS=(FACEBOOK_ACCESS_TOKEN FACEBOOK_PAGE_ID)
TWITTER_ENH_VARS=(TWITTER_API_KEY TWITTER_API_SECRET TWITTER_ACCESS_TOKEN TWITTER_ACCESS_TOKEN_SECRET TWITTER_BEARER_TOKEN)
BLUESKY_ENH_VARS=(BLUESKY_IDENTIFIER BLUESKY_APP_PASSWORD BLUESKY_SERVICE_URL)

echo "============================================================"
echo "  Social Media MCP Gateway Setup"
echo "============================================================"
echo ""

# =========================================================================
# Detect which servers have credentials
# =========================================================================

echo "=== Checking which platforms have credentials ==="

ENABLED_SERVERS=()

if has_credentials "${CROSSPOST_VARS[@]}"; then
  echo "  ✓ crosspost (at least one platform configured)"
  ENABLED_SERVERS+=(crosspost)
else
  echo "  ⊘ crosspost (no credentials — skipping)"
fi

if has_credentials "${SUBSTACK_VARS[@]}"; then
  echo "  ✓ substack"
  ENABLED_SERVERS+=(substack)
else
  echo "  ⊘ substack (no credentials — skipping)"
fi

if has_credentials "${MEDIUM_VARS[@]}"; then
  echo "  ✓ medium"
  ENABLED_SERVERS+=(medium)
else
  echo "  ⊘ medium (no credentials — skipping)"
fi

if has_credentials "${REDDIT_VARS[@]}"; then
  echo "  ✓ reddit"
  ENABLED_SERVERS+=(reddit)
else
  echo "  ⊘ reddit (no credentials — skipping)"
fi

if has_credentials "${FACEBOOK_VARS[@]}"; then
  echo "  ✓ facebook"
  ENABLED_SERVERS+=(facebook)
else
  echo "  ⊘ facebook (no credentials — skipping)"
fi

if has_credentials "${TWITTER_ENH_VARS[@]}"; then
  echo "  ✓ twitter-enhanced"
  ENABLED_SERVERS+=(twitter-enhanced)
else
  echo "  ⊘ twitter-enhanced (no credentials — skipping)"
fi

if has_credentials "${BLUESKY_ENH_VARS[@]}"; then
  echo "  ✓ bluesky-enhanced"
  ENABLED_SERVERS+=(bluesky-enhanced)
else
  echo "  ⊘ bluesky-enhanced (no credentials — skipping)"
fi

echo ""

if [[ ${#ENABLED_SERVERS[@]} -eq 0 ]]; then
  echo "No credentials found in ${ENV_FILE}."
  echo "Fill in at least one platform's credentials and re-run."
  exit 1
fi

echo "  → ${#ENABLED_SERVERS[@]} server(s) will be set up"
echo ""

# =========================================================================
# Step 1: Build only the Docker images we need
# =========================================================================

echo "=== Step 1: Building Docker images ==="

for srv in "${ENABLED_SERVERS[@]}"; do
  case "${srv}" in
    crosspost)
      build_image "crosspost-mcp:latest" "${SCRIPT_DIR}" ;;
    substack)
      build_image "substack-enhanced-mcp:latest" "${SCRIPT_DIR}/substack-enhanced" ;;
    medium)
      build_image "medium-mcp:latest" "${SCRIPT_DIR}/medium" ;;
    reddit)
      build_image "reddit-mcp:latest" "${SCRIPT_DIR}/reddit" ;;
    facebook)
      build_image "facebook-mcp:latest" "${SCRIPT_DIR}/facebook" ;;
    twitter-enhanced)
      build_image "twitter-enhanced-mcp:latest" "${SCRIPT_DIR}/twitter-enhanced" ;;
    bluesky-enhanced)
      build_image "bluesky-enhanced-mcp:latest" "${SCRIPT_DIR}/bluesky-enhanced" ;;
  esac
done

echo ""

# =========================================================================
# Step 2: (Re-)create catalog (delete first to clear stale entries)
# =========================================================================

echo "=== Step 2: Creating catalog ==="
docker mcp catalog rm "${CATALOG_NAME}" 2>/dev/null || true
docker mcp catalog create "${CATALOG_NAME}" 2>/dev/null \
  || echo "  (catalog '${CATALOG_NAME}' already exists)"
echo ""

# =========================================================================
# Step 3: Register enabled servers in catalog
# =========================================================================

echo "=== Step 3: Registering servers in catalog ==="

for srv in "${ENABLED_SERVERS[@]}"; do
  docker mcp catalog add "${CATALOG_NAME}" "${srv}" "${SCRIPT_DIR}/social-media-catalog.yaml" 2>/dev/null || true
  echo "  ✓ ${srv}"
done

echo ""

# =========================================================================
# Step 3b: Clean up stale secrets from previous runs
# =========================================================================

echo "=== Cleaning stale secrets ==="
# Remove old unprefixed secrets from previous runs (e.g. bare substack_publication_url)
ALL_KNOWN_VARS=(
  "${CROSSPOST_VARS[@]}" "${SUBSTACK_VARS[@]}" "${MEDIUM_VARS[@]}"
  "${REDDIT_VARS[@]}" "${FACEBOOK_VARS[@]}" "${TWITTER_ENH_VARS[@]}"
  "${BLUESKY_ENH_VARS[@]}"
)
for var in "${ALL_KNOWN_VARS[@]}"; do
  local_lower=$(echo "${var}" | tr '[:upper:]' '[:lower:]')
  docker mcp secret rm "${local_lower}" 2>/dev/null || true
done
# Remove old "-mcp" prefixed secrets from previous naming convention
OLD_PREFIXED_SERVERS=("substack-mcp" "medium-mcp" "reddit-mcp" "facebook-mcp")
for old_srv in "${OLD_PREFIXED_SERVERS[@]}"; do
  for var in "${ALL_KNOWN_VARS[@]}"; do
    local_lower=$(echo "${var}" | tr '[:upper:]' '[:lower:]')
    docker mcp secret rm "${old_srv}.${local_lower}" 2>/dev/null || true
  done
done
echo "  ✓ done"
echo ""

# =========================================================================
# Step 4: Configure secrets per server
# =========================================================================

echo "=== Step 4: Configuring secrets ==="

for srv in "${ENABLED_SERVERS[@]}"; do
  echo "  [${srv}]"
  case "${srv}" in
    crosspost)
      set_secrets_for_server "crosspost" "${CROSSPOST_VARS[@]}" ;;
    substack)
      set_secrets_for_server "substack" "${SUBSTACK_VARS[@]}" ;;
    medium)
      set_secrets_for_server "medium" "${MEDIUM_VARS[@]}" ;;
    reddit)
      set_secrets_for_server "reddit" "${REDDIT_VARS[@]}" ;;
    facebook)
      set_secrets_for_server "facebook" "${FACEBOOK_VARS[@]}" ;;
    twitter-enhanced)
      set_secrets_for_server "twitter-enhanced" "${TWITTER_ENH_VARS[@]}" ;;
    bluesky-enhanced)
      set_secrets_for_server "bluesky-enhanced" "${BLUESKY_ENH_VARS[@]}" ;;
  esac
done

echo ""

# =========================================================================
# Step 5: Enable servers
# =========================================================================

echo "=== Step 5: Enabling servers ==="

for srv in "${ENABLED_SERVERS[@]}"; do
  docker mcp server enable "${srv}" 2>/dev/null || true
  echo "  ✓ ${srv}"
done

echo ""

# =========================================================================
# Step 6: Restart the gateway so it picks up changes
# =========================================================================

echo "=== Step 6: Restarting Docker MCP Gateway ==="
brew services restart docker-mcp 2>/dev/null && echo "  ✓ gateway restarted" \
  || echo "  ⚠ could not restart via brew (restart manually if needed)"
echo ""

# =========================================================================
# Done
# =========================================================================

echo "============================================================"
echo "  Setup complete!"
echo "============================================================"
echo ""
echo "  Servers enabled: ${#ENABLED_SERVERS[@]}"
echo "  Catalog name:    ${CATALOG_NAME}"
echo ""
echo "  Active servers:"
for srv in "${ENABLED_SERVERS[@]}"; do
  echo "    ✓ ${srv}"
done
echo ""
echo "  To run the gateway with your existing servers:"
echo "    docker mcp gateway run --catalog docker-mcp --catalog ${CATALOG_NAME}"
echo ""
echo "  To verify tools are available:"
echo "    docker mcp tools ls"
echo ""
echo "  Add more credentials to .env and re-run this script"
echo "  to activate additional platforms."
echo ""
