# Single Attestation Inspection

Inspect a single attestation object using semantic, forensic, and lossless output modes.

## When to Use Each Mode

**Semantic view** (default):
- Quick orientation and debugging
- Human-readable decoded fields
- Use when you need to understand what's present

**Forensic view**:
- Evidence-preserving analysis
- Includes raw bytes alongside decoded fields
- Use when you need to verify structure or archive evidence

**Lossless tree**:
- Complete CBOR and ASN.1 structure dump
- Every byte and node accounted for
- Use when you need to verify nothing was missed

## What This Answers

- Certificate extensions present and their OIDs
- Receipt presence and container format
- Certificate chain structure
- Platform claims (environment, OS version, device class)
- Authenticator data flags and sign count
- COSE public key parameters

## What This Does Not Answer

- Whether the attestation is cryptographically valid
- Whether the certificate chain is trusted
- Whether the RP ID hash matches your expected value
- Whether the nonce is correct
- Whether the attestation should be accepted

## Usage

```bash
./inspect.sh /path/to/attestation.b64
```

The script runs all three modes sequentially. Use semantic for quick review, forensic for detailed analysis, lossless tree for complete verification.
