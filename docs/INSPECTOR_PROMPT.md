# Copy-Paste Prompt: On-Device App Attest Inspection UI

This is a clean, detailed, copy-pasteable prompt you can drop into Cursor / ChatGPT / Claude to wire the inspector into your iOS test app correctly, without turning it into security theater.

---

## The Problem You're Solving (Framed Correctly)

Most App Attest implementations fail because people:
- Treat attestation as a boolean
- Hide the evidence
- Mix inspection, verification, and policy
- Assume undocumented == invalid
- Have zero visibility when things drift

Your tool does the opposite. So the prompt has to enforce boundaries or people will misuse it anyway.

---

## COPY-PASTE PROMPT

```
"Enable on-device App Attest inspection UI (inspection only, no verification)"

You are adding an on-device inspection UI to an iOS test app that already generates App Attest attestations.

The goal is developer inspection only, not verification, trust decisions, or security enforcement.

Constraints (non-negotiable)
- Do NOT verify signatures, certificates, or assertions on device
- Do NOT show trust indicators (no green checks, no "valid/invalid" labels)
- Do NOT make security decisions in the UI
- Treat all output as diagnostic evidence, not authority

Architecture
- The app already generates an attestation object using DCAppAttestService
- The attestation object is available as a Base64 string
- A shared Swift framework named AppAttestCore exists that:
  - Decodes CBOR, ASN.1, X.509
  - Provides three output modes:
    - Semantic (human-readable)
    - Forensic (semantic + raw evidence)
    - Lossless Tree (every byte, every node)

Task

Implement a SwiftUI screen that:
1. Accepts a Base64-encoded attestation object
2. Uses AppAttestCore to decode it
3. Displays the decoded output in three selectable modes:
   - Semantic
   - Forensic
   - Lossless Tree
4. Performs decoding off the main thread
5. Handles errors gracefully (no force unwraps, no crashes)
6. Allows copying the decoded output as text

UI requirements
- Plain, utilitarian SwiftUI
- No animations
- No badges or icons implying trust
- Clear section headers
- Scrollable monospaced text output

Implementation details
- Create AttestationInspectorView
- Use a segmented control or picker to switch modes
- Decode once per mode change
- Display decoding errors inline as text

Security boundaries (must be documented in code comments)
- This view is inspection only
- Verification must occur on the server
- Output may include Apple-private or undocumented fields
- Decoded does not mean stable or safe to rely on

Integration
- Add a navigation entry from the main test app screen: "Inspect Attestation"
- Pass the Base64 attestation string into the inspector

Final check

If this UI were accidentally shipped, it should:
- Reveal no secrets beyond what the app already has
- Make no trust claims
- Cause no security regression

Implement the view and provide the SwiftUI code.
```

---

## Why This Works (And Why People Will Respect It)

This prompt:
- Forces inspection ≠ verification
- Encodes the trust boundaries in writing
- Prevents misuse by construction
- Teaches by example instead of lectures

Anyone reading the code will immediately see:

"Oh. This person actually understands App Attest."

---

## About "Managing Multiple Attestations"

Yes. This tool absolutely enables that.

The moment you:
- Store multiple decoded semantic models
- Diff public keys
- Diff counters
- Diff certificate chains
- Diff receipts over time

You've built:
- Replay detection visibility
- Device churn analysis
- Key rotation auditing
- Fraud investigation tooling

This enables analysis without making false claims about App Attest guarantees.

---

## Implementation Status

The inspector has been implemented in:
- `AppAttestDecoderTestApp/AttestationInspectorView.swift`

It follows all constraints:
- ✅ Inspection only (no verification)
- ✅ No trust indicators
- ✅ Graceful error handling
- ✅ Security boundary comments
- ✅ Plain, utilitarian UI

See `docs/IOS_INSPECTOR_SETUP.md` for setup instructions.
