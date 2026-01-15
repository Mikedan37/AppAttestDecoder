# Examples

This directory contains practical examples demonstrating realistic, safe usage of the App Attest Decoder for inspection and analysis.

## Quick Navigation

- **End-to-End Workflow:** `end_to_end_inspection_workflow/` - Complete flow from generation to validator handoff

## What These Examples Are

- Inspection workflows for single and multiple attestations
- Comparison patterns for detecting structural differences
- Storage and indexing patterns for managing attestation metadata
- CI/CD integration patterns for artifact analysis
- On-device inspection for debugging

## What These Examples Do Not Do

- Perform cryptographic verification
- Make trust or policy decisions
- Generate attestation objects (assumes you already have them)
- Accept or reject requests based on decoded content
- Claim security guarantees

## Prerequisites

All examples assume you have:
- Real attestation objects (base64-encoded) generated from actual iOS devices
- The decoder CLI built and accessible
- Basic familiarity with App Attest concepts

## Warning

**These examples demonstrate inspection and analysis only.**
**They must not be used to accept or reject requests in production.**

All verification must be implemented separately on your server using the raw materials exposed by the decoder.

## Example Scripts

Each example includes:
- A README explaining when and why to use it
- Shell scripts or Swift code demonstrating the workflow
- Clear boundaries about what conclusions you can and cannot draw

Run the scripts with your own attestation data. They are designed to be copied and modified for your specific needs.
