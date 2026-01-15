#!/bin/bash
# Compare multiple stored attestations
# Usage: ./compare.sh <attestation1.b64> <attestation2.b64> [attestation3.b64] ...

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <attestation1.b64> <attestation2.b64> [attestation3.b64] ..."
    exit 1
fi

ATTESTATIONS=("$@")

echo "=== Comparing \(#ATTESTATIONS[@]) Attestations ==="
echo ""

# Compare each pair
for i in "${!ATTESTATIONS[@]}"; do
    for j in "${!ATTESTATIONS[@]}"; do
        if [ $i -lt $j ]; then
            LEFT="${ATTESTATIONS[$i]}"
            RIGHT="${ATTESTATIONS[$j]}"
            
            echo "=== Comparing $(basename "$LEFT") vs $(basename "$RIGHT") ==="
            diff --left-file "$LEFT" --right-file "$RIGHT" --no-color
            echo ""
        fi
    done
done

echo "=== Comparison Complete ==="
echo ""
echo "Review differences above."
echo "Normal differences include:"
echo "- Different credential IDs (key rotation)"
echo "- Different sign counts (usage)"
echo "- Different certificate serial numbers (certificate rotation)"
echo ""
echo "Suspicious differences include:"
echo "- Different RP ID hashes (different apps)"
echo "- Missing expected extensions"
echo "- Certificate chain structure changes (may indicate infrastructure changes)"
