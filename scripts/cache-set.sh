#!/bin/bash

# Cache Set - Simple wrapper for cache storage
# Usage: cache-set.sh <key> <value> [ttl_seconds]

KEY="${1:-}"
VALUE="${2:-}"
TTL="${3:-3600}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
    echo '{"error": "key and value required"}'
    exit 1
fi

"$SCRIPT_DIR/cache-manager.sh" set "$KEY" "$VALUE" "$TTL"
