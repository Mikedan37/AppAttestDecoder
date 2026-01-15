# iOS Test App Integration

On-device inspection for debugging and development only.

## Purpose

This example shows how to integrate the decoder into an iOS test app for on-device inspection of generated attestations. This is useful for:
- Debugging attestation generation issues
- Understanding what your app is producing
- Development and testing workflows

## Critical Warnings

**This does not verify anything:**
- The decoder only parses structure
- No cryptographic verification is performed
- No trust decisions are made

**Do not gate network requests on this:**
- Inspection results must not be used to accept or reject API calls
- All verification must happen server-side
- This is inspection only, not validation

**This is for debugging only:**
- Use in development and test environments
- Do not use in production to make trust decisions
- Do not expose inspection results to end users

## What This Shows

- SwiftUI view that calls the decoder
- Display of decoded attestation structure
- Safe integration patterns that avoid trust decisions

## Usage

1. Link `AppAttestCore.framework` to your test app target
2. Copy `InspectorIntegration.swift` into your project
3. Use the view in your test app's UI
4. Generate attestations on-device and inspect them

See `docs/IOS_ON_DEVICE_INSPECTION.md` for complete setup instructions.
