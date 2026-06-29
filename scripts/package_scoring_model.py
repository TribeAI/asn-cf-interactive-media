#!/usr/bin/env python3
"""Package the /scoring-model/ explorer into a self-contained, shareable zip.

Inlines explorer_data/candidates.json into a single index.html (via a
<script id="scoring-data"> data island the page reads instead of fetching), so
the result opens by double-click in any browser — no server, no network. Bundles
a README with run instructions and zips it.

    python3 scripts/package_scoring_model.py
    -> dist/content-trust-score-explorer.zip
"""
from __future__ import annotations

import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC_HTML = ROOT / "public" / "scoring-model" / "index.html"
SRC_DATA = ROOT / "public" / "scoring-model" / "explorer_data" / "candidates.json"
OUT_DIR = ROOT / "dist"
BUNDLE = OUT_DIR / "content-trust-score-explorer"
ZIP = OUT_DIR / "content-trust-score-explorer.zip"

README = """# Content Trust Score — scoring-model explorer

An interactive view of the candidate content trust score for the Microsoft ASN
Content Freshness run `20260518-mslearn-iter14-modules-combined` (3,366 MS Learn
modules). Re-scoring only — extraction and validation are unchanged.

## How to open it

**Just double-click `index.html`** (or open it in Chrome / Edge / Safari /
Firefox). The data is embedded in the file, so no server and no internet
connection are needed.

If your browser ever refuses to open the local file, serve the folder instead:

```
cd content-trust-score-explorer
python3 -m http.server 8000
# then open http://localhost:8000/
```

## What you can explore

- **Scale by Words or Characters** — switch the content normalization.
- **The exact equation** — see how error density maps to a 0–100 score, with the
  soft floor that keeps only the most error-dense modules near 0.
- **Corpus averages vs production** and the score **histogram** (this model in
  blue vs the production claims+penalty model in red).
- **The "same-score (81)" cluster** — 29 modules production pins to ~81, shown
  spreading out by content length.
- **All 3,366 modules** — sort any column, paginate, and expand featured and
  same-score modules to read the underlying claims.

The model: `score = 100 − 30 × (1.0·major + 0.3·minor) per 1,000 words`, with a
soft floor below 25. Higher is better; a clean module scores 100.
"""


def main() -> int:
    html = SRC_HTML.read_text()
    data = SRC_DATA.read_text()

    # Guard the data island against premature </script> termination.
    safe = data.replace("</", "<\\/")
    island = f'<script id="scoring-data" type="application/json">{safe}</script>\n'
    if "<script>" not in html:
        raise SystemExit("Could not find the main <script> tag to anchor the data island.")
    standalone = html.replace("<script>", island + "<script>", 1)

    if BUNDLE.exists():
        shutil.rmtree(BUNDLE)
    BUNDLE.mkdir(parents=True)
    (BUNDLE / "index.html").write_text(standalone)
    (BUNDLE / "README.md").write_text(README)

    if ZIP.exists():
        ZIP.unlink()
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(BUNDLE.rglob("*")):
            z.write(f, f.relative_to(OUT_DIR))

    mb = ZIP.stat().st_size / 1e6
    html_mb = (BUNDLE / "index.html").stat().st_size / 1e6
    print(f"standalone index.html: {html_mb:.1f} MB")
    print(f"zip: {ZIP}  ({mb:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
