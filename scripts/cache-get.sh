#!/bin/bash

# Cache Get - Simple wrapper for cache retrieval
# Usage: cache-get.sh <key>

KEY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$KEY" ]; then
    echo '{"error": "key required"}'
    exit 1
fi

"$SCRIPT_DIR/cache-manager.sh" get "$KEY"
