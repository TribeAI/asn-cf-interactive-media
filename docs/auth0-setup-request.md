# #tribe-ops Slack draft — Auth0 client for `asn-cf-interactive-media`

Send the message below in `#tribe-ops`. The production Railway domain has
been filled in already (`asn-cf-interactive-media-production.up.railway.app`).

---

Hey @Jeremy @Andrew @Nick — could one of you provision an Auth0 client for an internal-apps Tier 2 tool I'm standing up? Details:

- **App name**: `asn-cf-interactive-media`
- **App type**: Regular Web Application (it's nginx + Tornado fronted by `oauth2-proxy`, not a Next.js app — OIDC works the same way)
- **Connection**: `tribe-google-workspace` (domain-locked to @tribe.ai)
- **Callback URLs**:
  - `https://asn-cf-interactive-media-production.up.railway.app/oauth2/callback` (production, on Railway)
  - `http://localhost:8080/oauth2/callback` (local development)
- **Allowed Logout URLs**:
  - `https://asn-cf-interactive-media-production.up.railway.app/`
  - `http://localhost:8080/`

Once it's set up, please send me `AUTH0_CLIENT_ID` and `AUTH0_CLIENT_SECRET` via 1Password share — I'll drop them into the Railway env and a local `.env`.

Context: this hosts the interactive visualizations and the human annotation tool for the Microsoft ASN Content Freshness workstream. Replacing an HTTP Basic Auth setup with the standard Tribe SSO pattern so reviewers can sign in with their @tribe.ai Google accounts.

Thanks!
