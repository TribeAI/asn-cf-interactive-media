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

The annotation tool requires a Python/Tornado backend, so local development uses Docker Compose:

```bash
# Place a claims CSV in the annotation data directory
cp /path/to/claims.csv annotation/data/claims.csv

# Build and run both services
docker compose up --build

# Open http://localhost:8080
```

### Static-only (no annotation backend)

If you only need the static visualizations:

```bash
docker build -t asn-cf-media .
docker run -p 8080:8080 asn-cf-media
```

## Adding a new visualization

1. Create `public/<slug>/index.html` (plus any sibling data files it needs).
2. Add a card link to `public/index.html`.
3. Commit, push. Railway auto-deploys.

No changes to `Dockerfile` or `nginx.conf` are needed — `try_files` serves any new directory automatically.

## Architecture

- **nginx on Alpine** — serves static HTML/JS and reverse-proxies `/annotation/api/*` to the Tornado backend.
- **Tornado** — Python API server for the annotation tool. Reads/writes claim annotations to a CSV file mounted at `/data/claims.csv`.
- **Docker Compose** — orchestrates both services locally. nginx depends on the annotation service.
- **Railway** — auto-detects the Dockerfile, builds, and deploys. Listens on port 8080.
