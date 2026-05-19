#!/bin/sh
# Container entrypoint. Three processes:
#
#   1. Tornado annotation API   — 127.0.0.1:8888  (background, only if CSV present)
#   2. nginx                    — 127.0.0.1:8081  (background, serves static + API)
#   3. oauth2-proxy             — 0.0.0.0:$PORT   (foreground, Auth0 / Google SSO)
#
# oauth2-proxy runs in the foreground so its exit terminates the container —
# Railway treats that as the lifecycle signal for the whole app.

set -e

# Railway injects $PORT; default to 8080 for local docker runs.
PORT="${PORT:-8080}"

# ---------------------------------------------------------------------------
# 1. Tornado annotation API (skip if no CSV is mounted — static-only mode).
# ---------------------------------------------------------------------------
if [ -f "${CSV_PATH:-/data/claims.csv}" ]; then
    echo "Starting annotation API (CSV: ${CSV_PATH:-/data/claims.csv})..."
    python3 /app/server.py &
fi

# ---------------------------------------------------------------------------
# 2. nginx on 127.0.0.1:8081 (behind oauth2-proxy).
# ---------------------------------------------------------------------------
echo "Starting nginx on 127.0.0.1:8081..."
nginx -g "daemon off;" &

# ---------------------------------------------------------------------------
# 3. oauth2-proxy on $PORT — handles Auth0 / Google SSO, proxies to nginx.
#
# Required env vars (fail fast if missing):
#   OAUTH2_PROXY_OIDC_ISSUER_URL   (e.g. https://auth.tribe.ai)
#   OAUTH2_PROXY_CLIENT_ID
#   OAUTH2_PROXY_CLIENT_SECRET
#   OAUTH2_PROXY_COOKIE_SECRET     (openssl rand -hex 32)
#   OAUTH2_PROXY_REDIRECT_URL      (https://<host>/oauth2/callback)
#
# We accept the friendlier AUTH0_* names from the Tribe internal-apps guide
# and translate them here so the env in Railway / .env stays consistent
# across NextAuth / express-openid-connect / oauth2-proxy stacks.
# ---------------------------------------------------------------------------
: "${OAUTH2_PROXY_OIDC_ISSUER_URL:=${AUTH0_ISSUER:-}}"
: "${OAUTH2_PROXY_CLIENT_ID:=${AUTH0_CLIENT_ID:-}}"
: "${OAUTH2_PROXY_CLIENT_SECRET:=${AUTH0_CLIENT_SECRET:-}}"
export OAUTH2_PROXY_OIDC_ISSUER_URL OAUTH2_PROXY_CLIENT_ID OAUTH2_PROXY_CLIENT_SECRET

for var in \
    OAUTH2_PROXY_OIDC_ISSUER_URL \
    OAUTH2_PROXY_CLIENT_ID \
    OAUTH2_PROXY_CLIENT_SECRET \
    OAUTH2_PROXY_COOKIE_SECRET \
    OAUTH2_PROXY_REDIRECT_URL; do
    eval "val=\${$var:-}"
    if [ -z "$val" ]; then
        echo "FATAL: required env var $var is not set" >&2
        exit 1
    fi
done

# Force the Auth0 "tribe-google-workspace" connection so users land directly
# on the Google account chooser instead of the Auth0 universal login.
# Only injected if AUTH0_CONNECTION is set (defaults to tribe-google-workspace
# via .env.example / Railway).
if [ -n "${AUTH0_CONNECTION:-}" ]; then
    export OAUTH2_PROXY_LOGIN_URL="${OAUTH2_PROXY_OIDC_ISSUER_URL%/}/authorize?connection=${AUTH0_CONNECTION}"
fi

echo "Starting oauth2-proxy on 0.0.0.0:${PORT}..."
exec oauth2-proxy \
    --config=/etc/oauth2-proxy/oauth2-proxy.cfg \
    --http-address="0.0.0.0:${PORT}"
