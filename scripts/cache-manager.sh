#!/bin/bash

# Cache Manager with LRU eviction
# Caches Claude responses to save tokens on repeated queries
# Usage: cache-manager.sh get <key>
#        cache-manager.sh set <key> <value> [ttl_seconds]
#        cache-manager.sh stats
#        cache-manager.sh clear

CACHE_DIR="/tmp/claude-cache"
CACHE_INDEX="$CACHE_DIR/index.json"
CACHE_STATS="$CACHE_DIR/stats.json"
MAX_CACHE_ENTRIES=1000
DEFAULT_TTL=3600  # 1 hour

mkdir -p "$CACHE_DIR"

# Initialize stats if not exists
if [ ! -f "$CACHE_STATS" ]; then
    cat > "$CACHE_STATS" <<EOF
{
  "hits": 0,
  "misses": 0,
  "sets": 0,
  "evictions": 0,
  "tokens_saved": 0
}
EOF
fi

# Initialize index if not exists
if [ ! -f "$CACHE_INDEX" ]; then
    echo '{}' > "$CACHE_INDEX"
fi

ACTION="${1:-stats}"

# Generate cache key hash
hash_key() {
    echo -n "$1" | md5sum | cut -d' ' -f1
}

# Get from cache
cache_get() {
    local KEY="$1"
    local KEY_HASH=$(hash_key "$KEY")
    local CACHE_FILE="$CACHE_DIR/$KEY_HASH.json"
    local NOW=$(date +%s)

    if [ ! -f "$CACHE_FILE" ]; then
        # Miss
        jq '.misses += 1' "$CACHE_STATS" > "$CACHE_STATS.tmp"
        mv "$CACHE_STATS.tmp" "$CACHE_STATS"

        echo '{"found": false, "reason": "not_in_cache"}'
        return 1
    fi

    # Read cache entry
    local ENTRY=$(cat "$CACHE_FILE")
    local EXPIRES_AT=$(echo "$ENTRY" | jq -r '.expires_at')
    local VALUE=$(echo "$ENTRY" | jq -r '.value')
    local CREATED_AT=$(echo "$ENTRY" | jq -r '.created_at')
    local TOKENS_SAVED=$(echo "$ENTRY" | jq -r '.estimated_tokens // 3000')

    # Check if expired
    if [ "$EXPIRES_AT" -lt "$NOW" ]; then
        # Expired, remove it
        rm -f "$CACHE_FILE"
        jq "del(.[\"$KEY_HASH\"])" "$CACHE_INDEX" > "$CACHE_INDEX.tmp"
        mv "$CACHE_INDEX.tmp" "$CACHE_INDEX"

        jq '.misses += 1' "$CACHE_STATS" > "$CACHE_STATS.tmp"
        mv "$CACHE_STATS.tmp" "$CACHE_STATS"

        echo '{"found": false, "reason": "expired"}'
        return 1
    fi

    # Hit! Update stats
    jq ".hits += 1 | .tokens_saved += $TOKENS_SAVED" "$CACHE_STATS" > "$CACHE_STATS.tmp"
    mv "$CACHE_STATS.tmp" "$CACHE_STATS"

    # Update access time in index (for LRU)
    jq ".[\"$KEY_HASH\"].last_access = $NOW" "$CACHE_INDEX" > "$CACHE_INDEX.tmp"
    mv "$CACHE_INDEX.tmp" "$CACHE_INDEX"

    local AGE=$((NOW - CREATED_AT))

    cat <<EOF
{
  "found": true,
  "value": $VALUE,
  "age_seconds": $AGE,
  "tokens_saved": $TOKENS_SAVED,
  "cache_hit": true
}
EOF
    return 0
}

# Set cache entry
cache_set() {
    local KEY="$1"
    local VALUE="$2"
    local TTL="${3:-$DEFAULT_TTL}"
    local KEY_HASH=$(hash_key "$KEY")
    local CACHE_FILE="$CACHE_DIR/$KEY_HASH.json"
    local NOW=$(date +%s)
    local EXPIRES_AT=$((NOW + TTL))

    # Estimate tokens (rough estimate based on value length)
    local VALUE_LENGTH=${#VALUE}
    local ESTIMATED_TOKENS=$((VALUE_LENGTH / 4))
    if [ "$ESTIMATED_TOKENS" -lt 100 ]; then
        ESTIMATED_TOKENS=100
    fi

    # Create cache entry
    cat > "$CACHE_FILE" <<EOF
{
  "key_hash": "$KEY_HASH",
  "value": $VALUE,
  "created_at": $NOW,
  "expires_at": $EXPIRES_AT,
  "ttl": $TTL,
  "estimated_tokens": $ESTIMATED_TOKENS
}
EOF

    # Update index
    local INDEX_ENTRY=$(cat <<EOF
{"created_at": $NOW, "last_access": $NOW, "expires_at": $EXPIRES_AT}
EOF
)

    jq ".[\"$KEY_HASH\"] = $INDEX_ENTRY" "$CACHE_INDEX" > "$CACHE_INDEX.tmp"
    mv "$CACHE_INDEX.tmp" "$CACHE_INDEX"

    # Update stats
    jq '.sets += 1' "$CACHE_STATS" > "$CACHE_STATS.tmp"
    mv "$CACHE_STATS.tmp" "$CACHE_STATS"

    # Check if we need to evict (LRU)
    local ENTRY_COUNT=$(jq 'length' "$CACHE_INDEX")
    if [ "$ENTRY_COUNT" -gt "$MAX_CACHE_ENTRIES" ]; then
        evict_lru
    fi

    cat <<EOF
{
  "success": true,
  "key_hash": "$KEY_HASH",
  "ttl": $TTL,
  "expires_at": $EXPIRES_AT,
  "estimated_tokens": $ESTIMATED_TOKENS
}
EOF
}

# Evict least recently used entry
evict_lru() {
    # Find entry with oldest last_access
    local OLDEST_HASH=$(jq -r 'to_entries | sort_by(.value.last_access) | .[0].key' "$CACHE_INDEX")

    if [ "$OLDEST_HASH" != "null" ] && [ -n "$OLDEST_HASH" ]; then
        # Remove file
        rm -f "$CACHE_DIR/$OLDEST_HASH.json"

        # Remove from index
        jq "del(.[\"$OLDEST_HASH\"])" "$CACHE_INDEX" > "$CACHE_INDEX.tmp"
        mv "$CACHE_INDEX.tmp" "$CACHE_INDEX"

        # Update stats
        jq '.evictions += 1' "$CACHE_STATS" > "$CACHE_STATS.tmp"
        mv "$CACHE_STATS.tmp" "$CACHE_STATS"
    fi
}

# Get cache statistics
cache_stats() {
    local STATS=$(cat "$CACHE_STATS")
    local HITS=$(echo "$STATS" | jq -r '.hits')
    local MISSES=$(echo "$STATS" | jq -r '.misses')
    local SETS=$(echo "$STATS" | jq -r '.sets')
    local EVICTIONS=$(echo "$STATS" | jq -r '.evictions')
    local TOKENS_SAVED=$(echo "$STATS" | jq -r '.tokens_saved')

    local TOTAL_REQUESTS=$((HITS + MISSES))
    local HIT_RATE=0
    if [ "$TOTAL_REQUESTS" -gt 0 ]; then
        HIT_RATE=$(echo "scale=1; $HITS * 100 / $TOTAL_REQUESTS" | bc)
    fi

    local ENTRY_COUNT=$(jq 'length' "$CACHE_INDEX")
    local CACHE_SIZE_KB=$(du -sk "$CACHE_DIR" 2>/dev/null | cut -f1)

    cat <<EOF
{
  "cache_stats": {
    "hits": $HITS,
    "misses": $MISSES,
    "sets": $SETS,
    "evictions": $EVICTIONS,
    "total_requests": $TOTAL_REQUESTS,
    "hit_rate_percent": $HIT_RATE,
    "entries": $ENTRY_COUNT,
    "max_entries": $MAX_CACHE_ENTRIES,
    "size_kb": $CACHE_SIZE_KB,
    "tokens_saved": $TOKENS_SAVED,
    "tokens_saved_formatted": "$([ $TOKENS_SAVED -ge 1000000 ] && echo "$(echo "scale=1; $TOKENS_SAVED / 1000000" | bc)M" || echo "$(echo "scale=1; $TOKENS_SAVED / 1000" | bc)K")"
  }
}
EOF
}

# Clear cache
cache_clear() {
    rm -f "$CACHE_DIR"/*.json
    echo '{}' > "$CACHE_INDEX"

    cat > "$CACHE_STATS" <<EOF
{
  "hits": 0,
  "misses": 0,
  "sets": 0,
  "evictions": 0,
  "tokens_saved": 0
}
EOF

    echo '{"success": true, "message": "Cache cleared"}'
}

# Main logic
case "$ACTION" in
    get)
        KEY="${2:-}"
        if [ -z "$KEY" ]; then
            echo '{"error": "key required"}'
            exit 1
        fi
        cache_get "$KEY"
        ;;
    set)
        KEY="${2:-}"
        VALUE="${3:-}"
        TTL="${4:-$DEFAULT_TTL}"
        if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
            echo '{"error": "key and value required"}'
            exit 1
        fi
        cache_set "$KEY" "$VALUE" "$TTL"
        ;;
    stats)
        cache_stats
        ;;
    clear)
        cache_clear
        ;;
    *)
        echo "{\"error\": \"Unknown action: $ACTION. Use: get, set, stats, clear\"}"
        exit 1
        ;;
esac
