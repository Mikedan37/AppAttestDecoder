#!/bin/bash
# Diffing examples demonstrating normal vs suspicious differences
# Usage: ./diff_examples.sh <attestation1.b64> <attestation2.b64>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <attestation1.b64> <attestation2.b64>"
    exit 1
fi

LEFT_FILE="$1"
RIGHT_FILE="$2"

if [ ! -f "$LEFT_FILE" ]; then
    echo "Error: File not found: $LEFT_FILE"
    exit 1
fi

if [ ! -f "$RIGHT_FILE" ]; then
    echo "Error: File not found: $RIGHT_FILE"
    exit 1
fi

echo "=== Attestation Diff Analysis ==="
echo ""
echo "Comparing:"
echo "  Left:  $LEFT_FILE"
echo "  Right: $RIGHT_FILE"
echo ""

# Run diff
DIFF_OUTPUT=$(diff --left-file "$LEFT_FILE" --right-file "$RIGHT_FILE" --json --no-color)

echo "$DIFF_OUTPUT" | jq '.' 2>/dev/null || echo "$DIFF_OUTPUT"

echo ""
echo "=== Interpretation Guide ==="
echo ""
echo "Review the differences above."
echo ""
echo "Normal differences (expected):"
echo "  - Different credential IDs: Key rotation is normal"
echo "  - Different sign counts: Sign count increases with use"
echo "  - Different certificate serials: Certificates rotate"
echo "  - Different OS versions: Device was upgraded"
echo ""
echo "Suspicious differences (investigate):"
echo "  - Different RP ID hashes: Different apps or misconfiguration"
echo "  - Missing extensions: May indicate parsing issues"
echo "  - Chain structure changes: May indicate infrastructure changes"
echo ""
echo "Remember:"
echo "  - Diff shows what changed, not whether change is acceptable"
echo "  - Acceptability is a policy decision, not an inspection result"
echo "  - Use diffs as signals for human review or policy engines"
