#!/bin/bash
# Compare two attestation artifacts from different sources
# Usage: ./diff.sh <artifact1.b64> <artifact2.b64>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <artifact1.b64> <artifact2.b64>"
    exit 1
fi

ARTIFACT1="$1"
ARTIFACT2="$2"

if [ ! -f "$ARTIFACT1" ]; then
    echo "Error: File not found: $ARTIFACT1"
    exit 1
fi

if [ ! -f "$ARTIFACT2" ]; then
    echo "Error: File not found: $ARTIFACT2"
    exit 1
fi

echo "=== Comparing Two Attestation Artifacts ==="
echo ""

diff --left-file "$ARTIFACT1" --right-file "$ARTIFACT2" --no-color

echo ""
echo "=== Common Differences ==="
echo ""
echo "Structural differences you may see:"
echo "- Credential ID (different keys have different IDs)"
echo "- Sign count (independent counters)"
echo "- Certificate serial numbers (may differ)"
echo ""
echo "Structural similarities you may see:"
echo "- RP ID hash (if from same app family)"
echo "- Team ID (if from same developer)"
echo "- Bundle ID prefix (if from same app)"
echo ""
echo "Note: The tool shows structural differences only."
echo "You decide what those differences mean for your use case."
