#!/bin/bash

# Cache Stats - Display cache statistics
# Usage: cache-stats.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/cache-manager.sh" stats
