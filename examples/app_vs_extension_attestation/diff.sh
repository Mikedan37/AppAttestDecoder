#!/bin/bash
# App vs extension attestation comparison example
# Usage: ./diff.sh <main_app.b64> <extension.b64>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <main_app.b64> <extension.b64>"
    exit 1
fi

MAIN_FILE="$1"
EXTENSION_FILE="$2"

if [ ! -f "$MAIN_FILE" ]; then
    echo "Error: File not found: $MAIN_FILE"
    exit 1
fi

if [ ! -f "$EXTENSION_FILE" ]; then
    echo "Error: File not found: $EXTENSION_FILE"
    exit 1
fi

echo "=== Main App vs Extension Comparison ==="
echo ""

diff --left-file "$MAIN_FILE" --right-file "$EXTENSION_FILE" --no-color

echo ""
echo "=== Expected Differences ==="
echo ""
echo "Common differences (all normal):"
echo "- Credential ID (each context has its own key)"
echo "- Sign count (independent counters)"
echo "- Certificate serial numbers (may differ)"
echo ""
echo "Common invariants (should match):"
echo "- RP ID hash (same app family)"
echo "- Team ID (same developer)"
echo "- Bundle ID prefix (same app)"
