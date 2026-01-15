#!/bin/bash
# End-to-end inspection workflow example
# This demonstrates the complete flow from attestation to validator handoff

set -e

ATTESTATION_FILE="$1"
if [ -z "$ATTESTATION_FILE" ]; then
    echo "Usage: $0 <attestation.b64>"
    echo ""
    echo "This script demonstrates the complete inspection workflow:"
    echo "  1. Inspect attestation structure"
    echo "  2. Export JSON for tooling"
    echo "  3. Extract key fields"
    echo "  4. Archive for analysis"
    echo "  5. Prepare for validator handoff"
    exit 1
fi

echo "=== Step 1: Inspecting attestation structure ==="
pretty --forensic --file "$ATTESTATION_FILE" > inspection.txt
echo "Inspection complete. Output saved to inspection.txt"
echo ""

echo "=== Step 2: Exporting JSON for tooling ==="
pretty --json --file "$ATTESTATION_FILE" > attestation.json
echo "JSON export complete. Output saved to attestation.json"
echo ""

echo "=== Step 3: Extracting key fields ==="
if command -v jq &> /dev/null; then
    BUNDLE_ID=$(jq -r '.identity.bundleID' attestation.json 2>/dev/null || echo "N/A")
    TEAM_ID=$(jq -r '.identity.teamID' attestation.json 2>/dev/null || echo "N/A")
    CRED_ID=$(jq -r '.identity.credentialID' attestation.json 2>/dev/null || echo "N/A")
    
    echo "Bundle ID: $BUNDLE_ID"
    echo "Team ID: $TEAM_ID"
    echo "Credential ID: $CRED_ID"
else
    echo "jq not found. Install jq to extract fields automatically."
    echo "Fields are available in attestation.json"
fi
echo ""

echo "=== Step 4: Archiving for analysis ==="
ARCHIVE_DIR="archive/$(date +%Y-%m-%d)"
mkdir -p "$ARCHIVE_DIR"
TIMESTAMP=$(date +%s)
cp attestation.json "$ARCHIVE_DIR/attestation-$TIMESTAMP.json"
cp inspection.txt "$ARCHIVE_DIR/inspection-$TIMESTAMP.txt"
echo "Archived to $ARCHIVE_DIR/"
echo ""

echo "=== Step 5: Ready for validator handoff ==="
echo ""
echo "The decoder has completed inspection. Next steps:"
echo ""
echo "1. Verify cryptographic signatures (your validator)"
echo "2. Validate certificate chain (your validator)"
echo "3. Check policy constraints (your validator)"
echo "4. Track sign counts for replay protection (your validator)"
echo ""
echo "Files ready for validator:"
echo "  - attestation.json (decoded structure)"
echo "  - $ATTESTATION_FILE (original attestation)"
echo ""
echo "See examples/end_to_end_inspection_workflow/README.md for validator integration."
