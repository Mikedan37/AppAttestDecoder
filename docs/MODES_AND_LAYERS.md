# App Attest Decoder — Modes and Layers

This document explains why the tool has multiple output modes and how they relate to each other.

## The Three-Layer Architecture

The tool separates **decoding**, **interpretation**, and **presentation** into distinct layers:

1. **Decoding Layer** (always active)
   - Parses CBOR, ASN.1, X.509, CMS
   - Extracts all fields
   - Preserves raw bytes
   - Never discards data

2. **Interpretation Layer** (opt-in)
   - Adds semantic meaning
   - Provides usage guidance
   - Assesses trust posture
   - Explains opaque fields

3. **Presentation Layer** (mode-dependent)
   - Semantic: Clean, scannable, collapsed
   - Forensic: Decoded + grouped raw evidence
   - Lossless: Every byte, every node, every path

## Output Modes

### Semantic (Default)

**Command:** `pretty`

**What it shows:**
- Decoded meaning only
- Collapsed hex (first 12 + last 12 bytes)
- No raw bytes unless they add meaning
- Human-readable in <10 seconds

**What it hides:**
- Full hex/base64 (use `--forensic` for that)
- ASN.1 TLV trees (use `--lossless-tree` for that)
- Raw CBOR structure (use `--lossless-tree` for that)

**Use when:** Quick scan, understanding what the attestation claims

---

### Semantic + Interpretation

**Command:** `pretty --explain` or `pretty --backend-ready` or `pretty --security`

**What it adds:**
- Explanations of opaque fields
- Usage guidance (what to store, verify, rotate)
- Trust posture assessment (non-authoritative)
- Backend readiness checklist

**Use when:** Building backend, understanding implications, security review

---

### Forensic

**Command:** `pretty --forensic`

**What it shows:**
- Everything from semantic view
- Plus grouped raw evidence:
  - Full hex and base64
  - Raw DER bytes
  - Extension payloads
  - Receipt structure analysis

**What it preserves:**
- All decoded fields first
- Raw bytes grouped at the end
- No data loss between layers

**Use when:** Analysis, debugging, proving claims, security review

---

### Lossless Tree

**Command:** `pretty --lossless-tree`

**What it shows:**
- Every CBOR node (map/array/int/string/bytes)
- Every ASN.1 TLV (tag, class, length, offset)
- All byte strings (length, SHA256, full base64)
- Full certificate DER + parsed fields
- Receipt deep dump
- Losslessness proof (counters)

**What it guarantees:**
- Nothing is hidden
- Nothing is discarded
- Deterministic output
- Byte accounting

**Use when:** Forensic audit, corpus building, proving no data loss

---

## Why "Unknown" ≠ "Undecoded"

The tool distinguishes between:

- **Decoded but opaque:** Field is parsed, structure is known, but semantics are Apple-private
  - Example: Apple App Attest environment extension
  - Status: "Apple-private"
  - Action: Preserve for audit, treat as integrity-bound

- **Unknown extension:** OID is not recognized
  - Example: Future Apple extension or third-party extension
  - Status: "Unknown origin"
  - Action: Preserve for audit, do not reject attestation

- **Decoding failure:** Structure could not be parsed
  - Example: Malformed ASN.1 or CBOR
  - Status: "Decode error: [reason]"
  - Action: Preserve raw bytes, show error details

The tool **never** silently discards data, even if it can't decode it.

---

## Why Verification is Separate

The decoder provides the **inspection layer**. You build the **verification layer** on top.

**What the decoder does:**
- Parses structures
- Extracts fields
- Preserves raw bytes
- Provides interpretation (opt-in)

**What you must do:**
- Verify attestation signature
- Validate certificate chain
- Check RP ID hash
- Verify receipt CMS signature
- Enforce replay protection
- Implement rotation policies

See `docs/VERIFICATION_GUIDE.md` for implementation details.

---

## Why Interpretation is Opt-In

Interpretation adds meaning but does not claim truth. It's:
- Best-effort reasoning
- Non-authoritative
- Confidence-leveled
- Safe-operation guidance

**Default mode (semantic):** Shows decoded facts only.

**Interpretation modes (`--explain`, `--backend-ready`, `--security`):** Adds reasoning and guidance.

This separation ensures:
- Default output is factual
- Interpretation is explicit
- Users can choose their level of guidance

---

## Mode Selection Guide

**"I just want to see what's inside"**
→ `pretty` (default semantic)

**"I want to understand what this means"**
→ `pretty --explain`

**"I'm building a backend"**
→ `pretty --backend-ready`

**"I'm doing a security review"**
→ `pretty --security`

**"I need to prove nothing is hidden"**
→ `pretty --lossless-tree`

**"I'm debugging a parsing issue"**
→ `pretty --forensic`

---

## Design Principles

1. **No data loss:** Every byte is surfaced somewhere
2. **No fake certainty:** Opaque fields are labeled, not guessed
3. **No mode overlap:** Each mode serves a distinct purpose
4. **No hidden complexity:** Interpretation is opt-in, not default

This architecture ensures the tool is:
- **Useful** for quick scans (semantic)
- **Complete** for analysis (forensic)
- **Provable** for audits (lossless)
- **Guided** for implementation (interpretation)

---

## See Also

- `docs/CLI_QUICK_START.md` - Which command to run
- `docs/VERIFICATION_GUIDE.md` - What to verify server-side
- `docs/WHAT_THIS_TOOL_IS.md` - What the tool is and isn't
