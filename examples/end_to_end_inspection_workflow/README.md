# End-to-End Inspection Workflow

This example demonstrates a complete workflow for inspecting App Attest artifacts from generation to validation handoff. This is **not** a production validator. It shows how to use the decoder as part of a larger system.

## Workflow Steps

1. **Generate** - App generates attestation on device
2. **Inspect** - Decoder parses structure and fields
3. **Diff** - Compare attestations to detect changes
4. **Archive** - Store decoded output for analysis
5. **Hand Off** - Pass to validator for security decisions

## Step-by-Step

### 1. Generate Attestation (iOS App)

```swift
import DeviceCheck

let service = DCAppAttestService.shared
let keyID = try await service.generateKey()
let challenge = "server-provided-challenge"
let attestationData = try await service.attestKey(keyID, clientDataHash: challenge.data(using: .utf8)!)
```

**Output:** Base64-encoded attestation object

### 2. Inspect Structure

```bash
# Semantic view (human-readable)
pretty --file attestation.b64

# Forensic view (evidence-preserving)
pretty --forensic --file attestation.b64

# JSON export (for tooling)
pretty --json --file attestation.b64 > attestation.json
```

**Purpose:** Understand what Apple produced. Check bundle ID, team ID, environment, certificate chain structure.

### 3. Diff Attestations

```bash
# Compare two attestations
diff attestation1.json attestation2.json

# Or use the built-in diff command
pretty diff --file1 attestation1.b64 --file2 attestation2.b64
```

**Purpose:** Detect changes across iOS versions, devices, or key rotations. Understand what's expected vs unexpected.

### 4. Archive Decoded Output

```bash
# Store for later analysis
mkdir -p archive/$(date +%Y-%m-%d)
pretty --json --file attestation.b64 > archive/$(date +%Y-%m-%d)/attestation-$(date +%s).json

# Index by credential ID
CRED_ID=$(jq -r '.identity.credentialID' archive/*/attestation-*.json | head -1)
mkdir -p archive/by-credential/$CRED_ID
cp attestation.json archive/by-credential/$CRED_ID/
```

**Purpose:** Build a corpus for regression testing, OS upgrade analysis, or incident investigation.

### 5. Hand Off to Validator

```swift
// Your validator (separate from decoder)
struct AttestationValidator {
    func verify(attestation: Data, 
                decoded: AttestationSemanticModel,
                expectedBundleID: String,
                expectedTeamID: String) -> ValidationResult {
        
        // 1. Verify cryptographic signatures
        guard verifySignature(attestation) else {
            return .invalid("Signature verification failed")
        }
        
        // 2. Validate certificate chain
        guard validateCertificateChain(decoded.trustChain) else {
            return .invalid("Certificate chain invalid")
        }
        
        // 3. Check policy constraints
        guard decoded.identity.bundleID == expectedBundleID else {
            return .invalid("Bundle ID mismatch")
        }
        
        guard decoded.identity.teamID == expectedTeamID else {
            return .invalid("Team ID mismatch")
        }
        
        // 4. Check sign count (replay protection)
        let storedCount = getStoredSignCount(for: decoded.identity.credentialID)
        guard decoded.identity.signCount.value > storedCount else {
            return .invalid("Sign count not increasing (replay attack)")
        }
        
        // 5. Update stored sign count
        storeSignCount(for: decoded.identity.credentialID, 
                      value: decoded.identity.signCount.value)
        
        return .valid
    }
}
```

**Purpose:** Make security decisions based on verified evidence. The decoder provides the structure. The validator provides the security.

## What This Workflow Does NOT Do

- **Does not verify signatures** - That's the validator's job
- **Does not make trust decisions** - That's the validator's job
- **Does not prevent replay attacks** - That's the validator's job (with sign count tracking)
- **Does not enforce policies** - That's the validator's job

## What This Workflow Does

- **Parses structure** - Understands what Apple produced
- **Extracts fields** - Makes bundle ID, team ID, etc. accessible
- **Preserves evidence** - Keeps raw bytes alongside decoded values
- **Enables comparison** - Diffs attestations to detect changes
- **Supports analysis** - Archives decoded output for investigation

## Complete Example Script

```bash
#!/bin/bash
# end_to_end.sh - Complete inspection workflow

set -e

ATTESTATION_FILE="$1"
if [ -z "$ATTESTATION_FILE" ]; then
    echo "Usage: $0 <attestation.b64>"
    exit 1
fi

# Step 1: Inspect
echo "=== Inspecting attestation ==="
pretty --forensic --file "$ATTESTATION_FILE" > inspection.txt

# Step 2: Export JSON
echo "=== Exporting JSON ==="
pretty --json --file "$ATTESTATION_FILE" > attestation.json

# Step 3: Extract key fields
echo "=== Extracting key fields ==="
BUNDLE_ID=$(jq -r '.identity.bundleID' attestation.json)
TEAM_ID=$(jq -r '.identity.teamID' attestation.json)
CRED_ID=$(jq -r '.identity.credentialID' attestation.json)

echo "Bundle ID: $BUNDLE_ID"
echo "Team ID: $TEAM_ID"
echo "Credential ID: $CRED_ID"

# Step 4: Archive
echo "=== Archiving ==="
ARCHIVE_DIR="archive/$(date +%Y-%m-%d)"
mkdir -p "$ARCHIVE_DIR"
cp attestation.json "$ARCHIVE_DIR/attestation-$(date +%s).json"
cp inspection.txt "$ARCHIVE_DIR/"

# Step 5: Hand off to validator (your code)
echo "=== Ready for validator ==="
echo "Pass attestation.json to your validator with:"
echo "  - Expected bundle ID: $BUNDLE_ID"
echo "  - Expected team ID: $TEAM_ID"
echo "  - Credential ID: $CRED_ID"
```

## Key Takeaways

1. **Decoder is for inspection** - It parses structure and extracts fields
2. **Validator is for security** - It verifies signatures and enforces policies
3. **Workflow separates concerns** - Inspection first, validation second
4. **Archive enables analysis** - Store decoded output for later investigation
5. **Diff detects changes** - Compare attestations to understand drift

This workflow shows how to use the decoder correctly: as an inspection tool that feeds into a separate validator. The decoder provides clarity. The validator provides security.
