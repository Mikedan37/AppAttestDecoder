# Multiple Attestations Management

Store and index multiple attestations to track key lifecycle and device history.

## Why This Matters

Each attestation represents:
- A key lifecycle event (generation, rotation, replacement)
- A device state at a point in time
- A trust surface that may be revoked or rotated

Managing multiple attestations enables:
- Tracking key rotation history
- Detecting unexpected changes
- Building audit trails
- Understanding device attestation patterns

## What This Stores

The example stores metadata only:
- Credential ID (unique per key)
- Device identifier (if available)
- Timestamp
- Decoded fields (extensions, platform claims, etc.)

## What This Does Not Store

- Trust decisions
- Validation results
- Policy verdicts
- Cryptographic verification outcomes

## Key Rotation

Key rotation is expected and normal. The example indexes by credential ID to track:
- When keys were generated
- When keys were rotated
- Which keys are currently active

Rotation is policy-driven, not determined by this tool.

## Usage

```bash
# Store multiple attestations
swift store_and_index.swift attestation1.b64 attestation2.b64 attestation3.b64

# Compare stored attestations
./compare.sh
```

The Swift example demonstrates safe storage patterns that preserve metadata without making trust decisions.
