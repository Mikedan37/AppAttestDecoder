# Xcode Scheme Arguments — Recommended Setup

This document lists the **minimal, correct test set** for Xcode scheme arguments. These are the four commands you need to fully exercise the tool.

## Recommended Scheme Arguments

Add these **one at a time** in Xcode: **Edit Scheme** → **Run** → **Arguments** → **Arguments Passed On Launch**

### A. Default Semantic View (Baseline)

```
pretty --file /tmp/attestation.b64 --no-color
```

**Purpose:**
- Sanity check
- Confirms decoding works
- Confirms output is readable
- Confirms no raw data leaks unintentionally

**If this ever looks ugly or confusing, everything else is doomed.**

---

### B. Forensic Mode (Evidence + Meaning)

```
pretty --forensic --file /tmp/attestation.b64 --no-color
```

**Purpose:**
- Verifies raw + semantic alignment
- Confirms no data loss between layers
- Confirms interpretation doesn't lie

**This is your "security reviewer" path.**

---

### C. Forensic Full (Max Human-Readable Depth)

```
pretty --forensic --full --file /tmp/attestation.b64 --no-color
```

**Purpose:**
- Confirms all decoded bytes are reachable
- Confirms extension decoding paths
- Confirms receipt parsing attempts

**This is where bugs show up.**

---

### D. Lossless Tree (Truth Serum)

```
pretty --lossless-tree --file /tmp/attestation.b64 --no-color
```

**Purpose:**
- Proves nothing is hidden
- Proves determinism
- Proves byte accounting

**This is not for users. This is for you, audits, and future-you at 3am.**

---

## What NOT to Include

Do **not** add these as primary scheme entries:
- Multiple `--json` variants
- Repeated `--forensic --json` combos
- Slight flag permutations
- Interpretation flags (`--explain`, `--backend-ready`, `--security`)

**Why:** These belong in docs, not checkboxes. Xcode schemes are for testing, not marketing.

---

## Environment Variables (Optional)

If you want lossless tree output to go to a file:

**Environment Variables:**
- `AA_OUTPUT_PATH=/tmp/appattest_report.txt`

---

## See Also

- `docs/CLI_QUICK_START.md` - Which command to run for your use case
- `docs/MODES_AND_LAYERS.md` - Why these modes exist
- `docs/CLI_Argument_Paths.md` - Complete command reference
