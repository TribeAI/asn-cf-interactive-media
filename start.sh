#!/bin/sh
# Start the Tornado annotation API in the background, then nginx in the foreground.
# If no CSV file is present, skip the annotation backend (static-only mode).

if [ -f "${CSV_PATH:-/data/claims.csv}" ]; then
    echo "Starting annotation API (CSV: ${CSV_PATH:-/data/claims.csv})..."
    python3 /app/server.py &
fi

echo "Starting nginx..."
exec nginx -g "daemon off;"
