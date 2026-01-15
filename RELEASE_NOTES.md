# Release Notes

## Why This Exists

This tool exists because:

1. App Attest artifacts are CBOR-encoded binary blobs that are difficult to inspect without specialized tooling.

2. Server-side validation requires parsing CBOR, ASN.1, X.509, and COSE structures, which is non-trivial to implement correctly.

3. Debugging attestation failures requires visibility into certificate extensions, platform claims, and receipt structures.

4. Apple's documentation describes what to verify but not how to parse the structures to extract the data needed for verification.

5. Certificate extensions contain important metadata (environment, OS version, device class) that must be extracted for policy decisions.

6. Receipts are CMS/PKCS#7 containers that require ASN.1 parsing to understand their structure.

7. Extensions and main apps generate separate attestations, which is often misunderstood without structural inspection.

8. OS upgrades can change attestation structure, and distinguishing "change" from "breakage" requires comparison tools.

9. Incident response and forensic analysis require complete visibility into all fields, not just a boolean verdict.

10. This tool provides the parsing layer so you can focus on implementing verification and policy logic.

## What This Is Not

This tool is not:
- A replacement for server-side verification
- A security validator or trust authority
- A simple "valid/invalid" checker
- An attempt to reverse-engineer Apple's private fields

It is an inspection and parsing tool that exposes raw materials for downstream validation.

## Version 0.1.0

Initial release. Core functionality complete. Scope locked. Ready for production use with appropriate server-side validation.
