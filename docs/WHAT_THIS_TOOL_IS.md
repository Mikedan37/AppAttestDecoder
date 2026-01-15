# What This Tool Is (And Isn't)

## What It Is

**Forensic instrumentation for App Attest artifacts.**

This tool provides x-ray vision into App Attest attestation objects and assertions:

- **Lossless inspection** - Every byte visible, nothing hidden
- **Dual-view output** - Raw bytes + decoded values side-by-side
- **Full transparency** - Unknown fields preserved, not guessed
- **Research-grade export** - JSON for diffing, corpus building, audits

### What You Can Inspect

- **Attestation object structure** - Raw CBOR + decoded tree
- **Authenticator data** - RP ID hash, flags, sign count, extensions
- **Certificate chain** - Full x5c with raw DER + parsed fields
- **Apple extensions** - Receipt (bundle ID, team ID), environment, OS version, device class, key purpose
- **Unknown fields** - Preserved exactly, labeled as opaque

### What This Enables

- **Audit** - Review attestation structure without guessing
- **Diff** - Compare attestations across OS versions, devices, contexts
- **Research** - Build corpus, detect platform drift, document invariants
- **Debug** - Understand why attestations differ or fail

## What It Isn't

**This tool does not:**

- Prove a device is "legit" on its own
- Replace Apple's server-side verification
- Bypass App Attest trust rules
- Break crypto or "decode secrets"
- Validate signatures cryptographically
- Make security decisions

### What It Doesn't Do

- **No signature verification** - Signatures are preserved and labeled [OPAQUE]
  - You must verify `attStmt.signature` over `authenticatorData || SHA256(clientDataHash)`
  - You must verify receipt CMS signatures
  - See `docs/VERIFICATION_GUIDE.md` for implementation details

- **No certificate chain validation** - Certificates are parsed, not validated
  - You must verify chain anchors to Apple Root CA G3
  - You must check expiration dates
  - You must validate Extended Key Usage

- **No trust decisions** - This is inspection, not validation
  - You must implement RP ID hash validation
  - You must implement public key consistency checks
  - You must implement replay protection

- **No magic** - Undocumented fields are preserved, not interpreted

## Philosophy

**"Full transparency" does not mean "everything interpreted."**

It means:
- Nothing hidden
- Nothing discarded
- No fake certainty

Some values are cryptographic or Apple-private. They're preserved exactly and labeled as opaque. That's correct behavior.

## Why This Matters

This is **instrumentation**, not a demo.

It's what you use when:
- Reality is messy
- Docs are missing
- You need to understand what actually happened
- You're tired of guessing

This type of tooling is used for:
- Platform security work
- Infrastructure observability
- Forensic analysis
- Audit and compliance

## Architecture: Three Modes, No Overlap

The tool provides three distinct output modes:

1. **Semantic (default)**: What does this attestation claim?
   - Clean, scannable, collapsed hex
   - Human-readable in <10 seconds
   - Zero noise

2. **Forensic**: Prove it.
   - Grouped raw bytes
   - Hex + base64
   - Extension payloads
   - Auditable

3. **Lossless Tree**: Show me literally everything.
   - Every CBOR node
   - Every ASN.1 TLV
   - Paths, offsets, lengths
   - Byte accounting

This separation is intentional. No single view can be both readable and complete.

## Philosophy

For the design philosophy and "why" behind this tool, see `docs/DESIGN_PHILOSOPHY.md`.

## Next Steps

- **For inspection:** Use semantic or forensic modes
- **For on-device inspection in iOS app:** See `docs/IOS_ON_DEVICE_INSPECTION.md`
- **For verification:** See `docs/VERIFICATION_GUIDE.md`
- **For all commands:** See `docs/CLI_Argument_Paths.md`
- **For project status:** See `docs/PROJECT_STATUS.md`