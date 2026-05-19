# ASN Content Freshness — Interactive Media

Static visualizations and annotation tools for the ASN content freshness scoring model, deployed on Railway.

## Visualizations

| Path | Description |
|------|-------------|
| `/scoring-model/` | Per-document scoring explorer: claims, ratings, excerpts, freshness scores |
| `/repro-report/` | Reproducibility report: agreement rates, score deltas across duplicate runs |
| `/repro-report/ethnography.html` | Side-by-side claim comparison for sampled documents |
| `/annotation/` | Claim annotation tool: human QA interface for grading AI claim assessments |

## Local development

The annotation tool requires a Python/Tornado backend, so local development uses Docker Compose. The app now sits behind Auth0 (Google SSO via `oauth2-proxy`) — you'll need an Auth0 client and a few env vars before it can start. See the [Auth0](#auth0) section below.

```bash
# One-time: copy the example env file and fill in secrets from 1Password.
cp .env.example .env
# edit .env — fill in AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET, OAUTH2_PROXY_COOKIE_SECRET

# Place a claims CSV in the annotation data directory (optional —
# if absent, the Tornado annotation backend is skipped).
cp /path/to/claims.csv annotation/data/claims.csv

# Build and run.
docker compose up --build

# Open http://localhost:8080 — first hit redirects you to Google via Auth0.
```

### Static-only (no annotation backend, no auth)

If you just want to preview the static visualizations without going through Auth0:

```bash
# Serve the public/ directory directly with anything you like.
python3 -m http.server -d public 8080
```

This bypasses both nginx and oauth2-proxy and is only useful for previewing static HTML.

## Auth0

This app uses the Tribe internal-apps Auth0 standard. Architecture:

```
Internet → oauth2-proxy (port $PORT) → nginx (127.0.0.1:8081) → Tornado (127.0.0.1:8888)
```

`oauth2-proxy` enforces Google SSO via the `tribe-google-workspace` Auth0 connection (domain-locked to `@tribe.ai` accounts). Nginx and Tornado are never reachable from the internet directly.

### Requesting Auth0 setup

This app is Tier 2 (internal, shared with specific users). To provision the Auth0 client, post in `#tribe-ops` cc-ing Jeremy / Andrew / Nick. A ready-to-send Slack draft lives at [`docs/auth0-setup-request.md`](docs/auth0-setup-request.md).

You'll receive `AUTH0_CLIENT_ID` and `AUTH0_CLIENT_SECRET` back via 1Password share.

### Required environment variables

| Variable | Where it goes | Notes |
|----------|---------------|-------|
| `AUTH0_ISSUER` | Railway + `.env` | Always `https://auth.tribe.ai` |
| `AUTH0_CLIENT_ID` | Railway + `.env` | From #tribe-ops / 1Password |
| `AUTH0_CLIENT_SECRET` | Railway + `.env` | From #tribe-ops / 1Password |
| `AUTH0_CONNECTION` | Railway + `.env` | `tribe-google-workspace` |
| `OAUTH2_PROXY_COOKIE_SECRET` | Railway + `.env` | `openssl rand -hex 32`; unique per env |
| `OAUTH2_PROXY_REDIRECT_URL` | Railway + `.env` | `https://asn-cf-interactive-media-production.up.railway.app/oauth2/callback` in prod; `http://localhost:8080/oauth2/callback` locally |

`start.sh` translates `AUTH0_*` into the `OAUTH2_PROXY_*` names oauth2-proxy expects, so the same `.env` file works for any future migration to NextAuth or `express-openid-connect`.

### Callback URLs to register

When requesting the Auth0 client, register **both** of these callback URLs:

- `https://asn-cf-interactive-media-production.up.railway.app/oauth2/callback` — production
- `http://localhost:8080/oauth2/callback` — local development

### Testing locally without a real Auth0 client

Right now there's no mock-provider mode wired in. If you need to iterate on a static visualization without going through Auth0, use the `python3 -m http.server -d public 8080` shortcut above. (oauth2-proxy supports `--skip-auth-routes` for specific path regexes — if static-page-only auth bypass becomes useful, we can add it.)

## Adding a new visualization

1. Create `public/<slug>/index.html` (plus any sibling data files it needs).
2. Add a card link to `public/index.html`.
3. Commit, push. Railway auto-deploys.

No changes to `Dockerfile`, `nginx.conf`, or `oauth2-proxy.cfg` are needed — `try_files` serves any new directory automatically, and oauth2-proxy gates the whole site.

## Architecture

- **oauth2-proxy** — terminates the public-facing port (`$PORT` on Railway, 8080 locally), enforces Auth0 (Google SSO), forwards authenticated requests to nginx.
- **nginx on Alpine** — listens on `127.0.0.1:8081`. Serves static HTML/JS and reverse-proxies `/annotation/api/*` to the Tornado backend. Keeps a 15 req/min per-IP rate limit as a belt-and-suspenders defense.
- **Tornado** — Python API server for the annotation tool. Listens on `127.0.0.1:8888`. Reads/writes claim annotations to a CSV file mounted at `/data/claims.csv`. Only started when a CSV is present.
- **Docker Compose** — single-service local orchestration; all three processes run inside one container via `start.sh`.
- **Railway** — auto-detects the Dockerfile, builds, and deploys. Sets `$PORT`; oauth2-proxy binds to it.
