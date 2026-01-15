# JSON Export Contract

This document describes the JSON output format for semantic and diff operations. It defines which fields are stable, which are best-effort, and which are explicitly unstable.

## Semantic Output (`pretty --json`)

The semantic JSON output follows this structure:

```json
{
  "summary": {
    "format": "apple-appattest",
    "hasCredential": true,
    "hasReceipt": true,
    "certificateCount": 3
  },
  "identity": {
    "rpIdHash": {
      "hex": "a1b2c3...",
      "length": 32
    },
    "flags": {
      "rawByte": 65,
      "userPresent": true,
      "userVerified": true,
      "attestedCredentialData": true,
      "extensionsIncluded": true
    },
    "signCount": {
      "value": 0,
      "formatted": "0",
      "significance": "Initial attestation"
    }
  },
  "credential": {
    "aaguid": {
      "uuid": "00000000-0000-0000-0000-000000000000",
      "hex": "...",
      "length": 16
    },
    "credentialId": {
      "hex": "...",
      "length": 64
    },
    "publicKey": {
      "keyType": "EC2",
      "algorithm": "ES256",
      "curve": "P-256",
      "xCoordinate": { "hex": "...", "length": 32 },
      "yCoordinate": { "hex": "...", "length": 32 }
    }
  },
  "trustChain": {
    "chainStructure": "leaf → intermediate → root",
    "certificates": [
      {
        "index": 0,
        "role": "leaf",
        "subject": { "fullDN": "...", "attributes": [...] },
        "issuer": { "fullDN": "...", "attributes": [...] },
        "serialNumber": "...",
        "signatureAlgorithm": { "oid": "...", "name": "..." },
        "publicKey": { "algorithm": "...", "type": "...", "curve": "...", "keySize": 256 },
        "validity": {
          "notBefore": "2024-01-01T00:00:00Z",
          "notAfter": "2025-01-01T00:00:00Z",
          "durationDays": 365
        },
        "extensions": [...]
      }
    ]
  },
  "platformClaims": {
    "environment": "production",
    "osVersion": "17.2.1",
    "deviceClass": "iphoneos",
    "keyPurpose": "..."
  },
  "receipt": {
    "containerType": "CMS SignedData (PKCS#7, RFC 5652)",
    "structure": { ... },
    "rawData": { "base64": "...", "length": 1234 }
  }
}
```

### Field Stability

**Stable fields** (safe to rely on):
- `summary.format` - Always "apple-appattest" for App Attest
- `identity.rpIdHash.hex` - RP ID hash (32 bytes)
- `identity.flags.rawByte` - Flags byte value
- `identity.signCount.value` - Sign count (UInt32)
- `credential.aaguid.hex` - AAGUID (16 bytes)
- `credential.credentialId.hex` - Credential ID
- `trustChain.certificates[].subject.fullDN` - Certificate subject DN
- `trustChain.certificates[].issuer.fullDN` - Certificate issuer DN
- `trustChain.certificates[].serialNumber` - Certificate serial number

**Best-effort fields** (may change with iOS versions):
- `platformClaims.environment` - May change encoding
- `platformClaims.osVersion` - Format may change
- `platformClaims.deviceClass` - May change values
- `receipt.structure` - Receipt format may evolve
- Extension decoded fields - Apple may change encoding

**Explicitly unstable fields** (do not rely on):
- `receipt.structure` details - Apple-private, may change
- Apple extension decoded fields - Undocumented, may drift
- Unknown extension fields - Structure not guaranteed

## Diff Output (`diff --json`)

The diff JSON output follows this structure:

```json
{
  "identity": {
    "status": "different",
    "changes": [
      {
        "field": "rpIdHash",
        "left": "a1b2c3...",
        "right": "f6e5d4..."
      }
    ]
  },
  "credential": {
    "status": "different",
    "changes": [
      {
        "field": "credentialId",
        "left": "...",
        "right": "..."
      }
    ]
  },
  "trustChain": {
    "status": "identical",
    "changes": []
  },
  "platformClaims": {
    "status": "different",
    "changes": [
      {
        "field": "osVersion",
        "left": "17.2.1",
        "right": "17.3.0"
      }
    ]
  },
  "receipt": {
    "status": "identical",
    "changes": []
  },
  "hasDifferences": true
}
```

### Field Stability

**Stable fields** (safe to rely on):
- `status` - "identical" or "different" (enum)
- `changes[].field` - Field name (string)
- `changes[].left` - Left value (string)
- `changes[].right` - Right value (string)
- `hasDifferences` - Boolean indicating if any differences exist

**Best-effort fields**:
- `changes[].left` and `changes[].right` values - Format may vary by field type
- Field names may change if semantic model evolves

## Integration Guidelines

**For stable fields:**
- Safe to use in production integrations
- Can be relied upon for indexing, storage, comparison
- Format is guaranteed to remain consistent

**For best-effort fields:**
- Use with version checks
- Handle missing or changed fields gracefully
- Do not hardcode expectations

**For unstable fields:**
- Use for debugging and analysis only
- Do not rely on structure or semantics
- Treat as opaque if needed for audit

## Versioning

JSON output format versioning:
- **v1.0** - Current format (stable fields only)
- Format changes will increment major version
- Best-effort fields may change without version bump
- Unstable fields may change at any time

## Examples

See `examples/` directory for integration examples:
- `examples/multiple_attestations/store_and_index.swift` - Storage patterns
- `examples/ci_pipeline/analyze.sh` - CI integration
- `examples/diffing/diff_examples.sh` - Diff usage
