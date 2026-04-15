# ASN Content Freshness — Interactive Media

Static visualizations for the ASN content freshness scoring model, deployed on Railway.

## Visualizations

| Path | Description |
|------|-------------|
| `/scoring-model/` | Per-document scoring explorer: claims, ratings, excerpts, freshness scores |
| `/repro-report/` | Reproducibility report: agreement rates, score deltas across duplicate runs |
| `/repro-report/ethnography.html` | Side-by-side claim comparison for sampled documents |

## Local development

```bash
docker build -t asn-cf-media .
docker run -p 8080:8080 asn-cf-media
# Open http://localhost:8080
```

## Adding a new visualization

1. Create `public/<slug>/index.html` (plus any sibling data files it needs).
2. Add a card link to `public/index.html`.
3. Commit, push. Railway auto-deploys.

No changes to `Dockerfile` or `nginx.conf` are needed — `try_files` serves any new directory automatically.

## Architecture

- **nginx on Alpine** — lightweight (~40 MB image), gzip enabled for HTML/JSON/CSS/JS.
- **Railway** — auto-detects the Dockerfile, builds, and deploys. Listens on port 8080.
- No build step, no JS bundler, no dependencies beyond nginx.
