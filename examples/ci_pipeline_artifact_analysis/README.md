# CI Pipeline Artifact Analysis

Demonstrate safe, non-invasive CI usage for attestation artifact analysis.

## Why CI Should Inspect, Not Enforce

CI pipelines should:
- Archive attestation artifacts for audit trails
- Generate structured metadata for analysis
- Detect structural changes for review
- Never make trust decisions or reject based on content

## What This Helps With

- Building audit trails for incident response
- Tracking attestation structure over time
- Generating metadata for analysis tools
- Detecting unexpected changes for human review

## Why Failing CI on Attestation Content is Dangerous

Attestation structure can change due to:
- iOS version upgrades (OS version in platform claims changes)
- Apple infrastructure changes (certificate chain structure evolves)
- Extension vs main app differences (different execution contexts)
- Key rotation (new credential IDs are expected)

Failing CI on these changes creates false positives and blocks legitimate deployments. CI should archive and analyze, not enforce policy.

## Usage

```bash
./analyze.sh attestation.b64 output_dir/
```

The script generates:
- Semantic summary (human-readable)
- Forensic archive (evidence-preserving JSON)
- Lossless tree dump (complete structure)

All outputs are written to the specified directory. The script exits successfully regardless of content. Use the outputs for analysis, not enforcement.
