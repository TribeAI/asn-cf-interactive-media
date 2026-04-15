"""
Claim annotation API server — Tornado backend for the annotation tool.

Serves JSON API endpoints for reading/writing claim annotations to a CSV file.
The HTML frontend is served statically by nginx; this server handles only API routes.
"""
from __future__ import annotations

import csv
import json
import os
from pathlib import Path
from typing import Any

import tornado.ioloop
import tornado.web


HUMAN_COLUMNS = [
    "grader",
    "human_reasoning",
    "human_rating",
    "human_severity",
    "agree_with_reasoning",
    "starred",
]

VALID_RATINGS = {
    "no_issue",
    "outdated",
    "inaccurate",
    "inconclusive",
    "trivially_inconclusive",
}
VALID_SEVERITIES = {"major", "minor", "trivial", ""}


# ---------------------------------------------------------------------------
# CSV I/O
# ---------------------------------------------------------------------------

def load_claims(csv_path: Path) -> tuple[list[dict[str, str]], bool]:
    """
    Read the claims CSV into a list of dicts.
    If the human annotation columns don't exist yet, add them.
    Returns (rows, schema_changed) so the caller knows whether to persist.
    """
    with open(csv_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    needs_human_columns = any(
        col not in rows[0]
        for col in HUMAN_COLUMNS
    ) if rows else False

    if needs_human_columns:
        for row in rows:
            row.setdefault("grader", "")
            row.setdefault("human_reasoning", "")
            row.setdefault("human_rating", "")
            row.setdefault("human_severity", "")
            row.setdefault("agree_with_reasoning", "")
            row.setdefault("starred", "")

    return rows, needs_human_columns


def save_claims_to_disk(csv_path: Path, claims: list[dict[str, str]]) -> None:
    """Write the full claims list back to the CSV file."""
    if not claims:
        return

    fieldnames = list(claims[0].keys())
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(claims)


def save_annotation(
    csv_path: Path,
    claims: list[dict[str, str]],
    row_index: int,
    annotation: dict[str, str],
) -> None:
    """
    Update one row's human columns in the in-memory list, then persist
    the entire CSV to disk.
    """
    row = claims[row_index]
    for col in HUMAN_COLUMNS:
        if col in annotation:
            row[col] = annotation[col]

    save_claims_to_disk(csv_path, claims)


# ---------------------------------------------------------------------------
# Shared application state
# ---------------------------------------------------------------------------

class AppState:
    """Holds the in-memory claims list and the path to the CSV file."""

    def __init__(self, csv_path: Path) -> None:
        self.csv_path = csv_path
        self.claims, schema_changed = load_claims(csv_path)

        if schema_changed:
            save_claims_to_disk(csv_path, self.claims)


# ---------------------------------------------------------------------------
# Request handlers
# ---------------------------------------------------------------------------

class ClaimsListHandler(tornado.web.RequestHandler):
    """Return a lightweight index of all claims."""

    def get(self) -> None:
        state: AppState = self.application.state  # type: ignore[attr-defined]
        result = []
        for i, row in enumerate(state.claims):
            has_annotation = bool(row.get("grader", "").strip())
            result.append({
                "index": i,
                "id": row.get("id", ""),
                "title": row.get("title", ""),
                "has_annotation": has_annotation,
                "claim": row.get("claim", ""),
                "rating": row.get("rating", ""),
                "severity": row.get("severity", ""),
                "reasoning": row.get("reasoning", ""),
                "human_rating": row.get("human_rating", ""),
                "human_severity": row.get("human_severity", ""),
                "human_reasoning": row.get("human_reasoning", ""),
                "starred": row.get("starred", ""),
            })
        self.set_header("Content-Type", "application/json")
        self.write(json.dumps(result))


class ClaimDetailHandler(tornado.web.RequestHandler):
    """Return or update a single claim by its row index."""

    def get(self, index_str: str) -> None:
        state: AppState = self.application.state  # type: ignore[attr-defined]
        index = int(index_str)

        if index < 0 or index >= len(state.claims):
            self.set_status(404)
            self.write({"error": "Claim not found"})
            return

        row = dict(state.claims[index])
        row["index"] = index
        row["has_annotation"] = bool(row.get("human_rating", "").strip())

        self.set_header("Content-Type", "application/json")
        self.write(json.dumps(row))

    def post(self, index_str: str) -> None:
        state: AppState = self.application.state  # type: ignore[attr-defined]
        index = int(index_str)

        if index < 0 or index >= len(state.claims):
            self.set_status(404)
            self.write({"error": "Claim not found"})
            return

        body = json.loads(self.request.body)
        annotation: dict[str, str] = {}

        grader = str(body.get("grader", "")).strip()
        annotation["grader"] = grader

        human_rating = str(body.get("human_rating", "")).strip()
        if human_rating and human_rating not in VALID_RATINGS:
            self.set_status(400)
            self.write({"error": f"Invalid rating: {human_rating}"})
            return
        annotation["human_rating"] = human_rating

        human_severity = str(body.get("human_severity", "")).strip()
        if human_severity not in VALID_SEVERITIES:
            self.set_status(400)
            self.write({"error": f"Invalid severity: {human_severity}"})
            return
        annotation["human_severity"] = human_severity

        annotation["human_reasoning"] = str(body.get("human_reasoning", ""))

        agree = str(body.get("agree_with_reasoning", "")).strip()
        if agree not in ("true", "false", ""):
            self.set_status(400)
            self.write({"error": f"Invalid agree_with_reasoning value: {agree}"})
            return
        annotation["agree_with_reasoning"] = agree

        save_annotation(state.csv_path, state.claims, index, annotation)

        self.set_header("Content-Type", "application/json")
        self.write({"ok": True})


class ProgressHandler(tornado.web.RequestHandler):
    """Return annotation progress counts."""

    def get(self) -> None:
        state: AppState = self.application.state  # type: ignore[attr-defined]
        total = len(state.claims)
        annotated = sum(
            1 for row in state.claims
            if row.get("grader", "").strip()
        )
        self.set_header("Content-Type", "application/json")
        self.write(json.dumps({
            "total": total,
            "annotated": annotated,
            "remaining": total - annotated,
        }))


class ExportHandler(tornado.web.RequestHandler):
    """Download the CSV file as an attachment."""

    def get(self) -> None:
        state: AppState = self.application.state  # type: ignore[attr-defined]
        filename = state.csv_path.name
        self.set_header("Content-Type", "text/csv; charset=utf-8")
        self.set_header(
            "Content-Disposition",
            f"attachment; filename=\"{filename}\""
        )
        with open(state.csv_path, "r", encoding="utf-8") as f:
            self.write(f.read())


class StarToggleHandler(tornado.web.RequestHandler):
    """Toggle the starred state of a claim."""

    def post(self, index_str: str) -> None:
        state: AppState = self.application.state  # type: ignore[attr-defined]
        index = int(index_str)

        if index < 0 or index >= len(state.claims):
            self.set_status(404)
            self.write({"error": "Claim not found"})
            return

        row = state.claims[index]
        current = row.get("starred", "")
        new_value = "" if current == "*" else "*"
        row["starred"] = new_value

        save_claims_to_disk(state.csv_path, state.claims)

        self.set_header("Content-Type", "application/json")
        self.write(json.dumps({"starred": new_value}))


# ---------------------------------------------------------------------------
# Application factory
# ---------------------------------------------------------------------------

def make_app(csv_path: Path) -> tornado.web.Application:
    """Build the Tornado application with all API routes."""
    app = tornado.web.Application([
        (r"/api/claims", ClaimsListHandler),
        (r"/api/claims/(\d+)", ClaimDetailHandler),
        (r"/api/claims/(\d+)/star", StarToggleHandler),
        (r"/api/progress", ProgressHandler),
        (r"/api/export", ExportHandler),
    ])
    app.state = AppState(csv_path)  # type: ignore[attr-defined]
    return app


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    csv_path = Path(os.environ.get("CSV_PATH", "/data/claims.csv")).resolve()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    port = int(os.environ.get("PORT", "8888"))

    app = make_app(csv_path)
    app.listen(port, address="0.0.0.0")

    print(f"Annotation API listening on 0.0.0.0:{port}")
    print(f"CSV: {csv_path}")

    tornado.ioloop.IOLoop.current().start()


if __name__ == "__main__":
    main()
