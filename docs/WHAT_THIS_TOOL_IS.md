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
- **No certificate chain validation** - Certificates are parsed, not validated
- **No trust decisions** - This is inspection, not validation
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

Good companies recognize this as:
- Platform security tooling
- Infrastructure work
- Making systems observable
- Thinking like an auditor

Mediocre companies will ask "why so much output."

Those companies are not your audience.
