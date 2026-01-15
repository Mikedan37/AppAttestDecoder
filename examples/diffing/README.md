# Attestation Diffing

Compare two attestations to identify structural differences.

## What Diffing Shows

- Field-level differences (RP ID hash, flags, sign count)
- Certificate chain differences (count, subjects, serials)
- Platform claim differences (OS version, environment, device class)
- Receipt differences (presence, container type, size)
- Credential differences (AAGUID, credential ID, public key)

## Normal Differences

These differences are expected and do not indicate problems:
- Different credential IDs (key rotation)
- Different sign counts (increases with use)
- Different certificate serial numbers (certificate rotation)
- Different OS versions (device upgraded)
- Different timestamps (different generation times)

## Suspicious Differences

These differences may warrant investigation:
- Different RP ID hashes (indicates different relying parties)
- Missing expected extensions (may indicate parsing issues)
- Certificate chain structure changes (may indicate Apple infrastructure changes)
- Receipt presence/absence changes (may indicate environment changes)

## Important Boundaries

**Diff does not equal verdict:**
- A diff shows what changed, not whether the change is acceptable
- Acceptability is a policy decision, not an inspection result

**Diff does not equal fraud:**
- Differences may be legitimate (key rotation, OS upgrade)
- Differences may be expected (extension vs main app)
- Fraud detection requires additional signals beyond structure

**Diff equals signal:**
- Use diffs as input to human review or policy engines
- Do not automate trust decisions based solely on diffs
- Combine with other signals (timestamps, device history, etc.)

## Usage

```bash
./diff_examples.sh attestation1.b64 attestation2.b64
```

The script demonstrates various diff scenarios and explains what each difference means.
