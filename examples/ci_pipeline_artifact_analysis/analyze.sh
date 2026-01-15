#!/bin/bash
# CI pipeline artifact analysis example
# Usage: ./analyze.sh <attestation.b64> <output_dir>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <attestation.b64> <output_dir>"
    exit 1
fi

ATTESTATION_FILE="$1"
OUTPUT_DIR="$2"

if [ ! -f "$ATTESTATION_FILE" ]; then
    echo "Error: File not found: $ATTESTATION_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
PREFIX="${OUTPUT_DIR}/attestation_${TIMESTAMP}"

echo "Analyzing attestation: $ATTESTATION_FILE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Semantic summary
echo "Generating semantic summary..."
pretty --file "$ATTESTATION_FILE" --no-color > "${PREFIX}_semantic.txt"

# Forensic archive (JSON)
echo "Generating forensic archive..."
pretty --forensic --json --file "$ATTESTATION_FILE" > "${PREFIX}_forensic.json"

# Lossless tree dump
echo "Generating lossless tree dump..."
pretty --lossless-tree --file "$ATTESTATION_FILE" --no-color > "${PREFIX}_lossless.txt"

echo ""
echo "Analysis complete. Outputs:"
echo "  - ${PREFIX}_semantic.txt"
echo "  - ${PREFIX}_forensic.json"
echo "  - ${PREFIX}_lossless.txt"
echo ""
echo "Exit code: 0 (success, regardless of content)"

exit 0
