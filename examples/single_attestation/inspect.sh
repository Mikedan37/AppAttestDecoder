#!/bin/bash
# Single attestation inspection example
# Usage: ./inspect.sh <attestation.b64>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <attestation.b64>"
    exit 1
fi

ATTESTATION_FILE="$1"

if [ ! -f "$ATTESTATION_FILE" ]; then
    echo "Error: File not found: $ATTESTATION_FILE"
    exit 1
fi

echo "=== Semantic View ==="
echo ""
pretty --file "$ATTESTATION_FILE" --no-color

echo ""
echo "=== Forensic View ==="
echo ""
pretty --forensic --file "$ATTESTATION_FILE" --no-color

echo ""
echo "=== Lossless Tree ==="
echo ""
pretty --lossless-tree --file "$ATTESTATION_FILE" --no-color

# Script always exits successfully
# Content analysis is separate from script execution
exit 0
