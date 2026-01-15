# App Attest Verification Guide

This document explains what verification steps are required beyond decoding. The decoder provides the **inspection layer**; you build the **verification layer** on top.

## Quick Reference

**What to store:**
- Credential ID → Public Key mapping
- Attestation timestamp
- Sign count (for replay protection)

**What to verify:**
- RP ID hash matches bundle ID
- Attestation signature over authenticatorData || clientDataHash
- Certificate chain anchors to Apple Root CA G3
- Receipt CMS signature (if present)

**What to monitor:**
- Sign count (must be monotonic for assertions)
- Environment changes (sandbox vs production)
- Key rotation events

**What to reject:**
- RP ID hash mismatch
- Invalid certificate chain
- Invalid attestation signature
- Invalid receipt signature (if present)
- Replay attacks (signCount <= last seen)

## What the Decoder Provides

The decoder gives you:
- Parsed structures (authenticatorData, certificates, extensions)
- Raw bytes (for signature verification)
- Decoded fields (RP ID hash, flags, public key, etc.)

## What You Must Verify

### 1. Attestation Signature Verification

**What to verify:**
```
attStmt.signature over (authenticatorData || SHA256(clientDataHash))
```

**Using:**
- Leaf certificate public key from `x5c[0]`
- Algorithm from `attStmt.alg` (or implicit ES256)

**How:**
1. Extract public key from leaf certificate
2. Reconstruct signed data: `authenticatorData || SHA256(clientDataHash)`
3. Verify signature using public key and algorithm

**If verification fails:** Reject attestation

---

### 2. Certificate Chain Trust

**What to verify:**
- Chain validity: `leaf → intermediate → root`
- Anchor against Apple Root CA G3
- Certificate expiration (notBefore, notAfter)
- Extended Key Usage (EKU) matches App Attest expectations

**How:**
1. Build certificate chain from `x5c`
2. Validate each certificate signature
3. Check validity windows
4. Verify chain anchors to trusted Apple root
5. Check EKU extensions

**If verification fails:** Reject attestation

---

### 3. RP ID Hash Validation

**What to verify:**
```
SHA256(bundleID) == authenticatorData.rpIdHash
```

**How:**
1. Compute SHA256 of your app's bundle identifier
2. Compare with `authenticatorData.rpIdHash`
3. Must match exactly

**If verification fails:** Reject attestation (wrong app)

---

### 4. Receipt CMS Signature Verification

**What to verify:**
- CMS SignedData signature
- Signing certificate is Apple Fraud Receipt Signing
- Receipt timestamps vs attestation timestamps

**How:**
1. Parse receipt as CMS/PKCS#7 SignedData
2. Verify CMS signature
3. Check signing certificate is Apple Fraud Receipt Signing
4. Validate receipt timestamps

**If verification fails:** Reject attestation (receipt invalid)

---

### 5. Public Key Consistency

**What to verify:**
- COSE public key == leaf certificate public key
- Credential ID == SHA256(leaf public key DER) (if applicable)

**How:**
1. Extract public key from COSE structure
2. Extract public key from leaf certificate
3. Compare (must match)
4. Optionally verify credential ID derivation

**If verification fails:** Reject attestation (key mismatch)

---

### 6. Replay Protection

**What to verify:**
- Sign count is monotonic (for assertions)
- First attestation has signCount == 0

**How:**
1. Store signCount per credential ID
2. For assertions, verify signCount > last seen
3. For first attestation, verify signCount == 0

**If verification fails:** Reject (replay attack)

---

## Implementation Notes

### Using the Decoder Output

The decoder provides all the data you need:

```swift
// From semantic model or direct access
let attestation = try decoder.decodeAttestationObject(data)

// Get what you need for verification
let rpIdHash = attestation.authenticatorData.rpIdHash
let signature = attestation.attestationStatement.signature
let leafCert = attestation.attestationStatement.x5c[0]
let publicKey = // extract from COSE or certificate
```

### Verification Order

1. **Parse first** (decoder does this)
2. **RP ID hash** (fast, fail early)
3. **Certificate chain** (trust anchor)
4. **Attestation signature** (cryptographic proof)
5. **Receipt signature** (if present)
6. **Public key consistency** (sanity check)
7. **Replay protection** (for assertions)

---

## What the Decoder Does NOT Do

The decoder intentionally does NOT:
- Verify signatures (you must implement this)
- Validate certificate chains (you must implement this)
- Enforce RP ID matching (you must implement this)
- Check expiration dates (you must implement this)
- Enforce policies (you must implement this)

**Why:** Verification is policy-dependent. The decoder provides the **inspection layer**; you build the **verification layer** that matches your security requirements.

---

## Example Verification Pipeline

```swift
func verifyAttestation(_ data: Data, bundleID: String, clientDataHash: Data) -> Bool {
    // 1. Decode (decoder does this)
    let attestation = try decoder.decodeAttestationObject(data)
    
    // 2. RP ID hash
    let expectedRPIdHash = SHA256.hash(data: bundleID.data(using: .utf8)!)
    guard attestation.authenticatorData.rpIdHash == expectedRPIdHash else {
        return false
    }
    
    // 3. Certificate chain trust
    guard verifyCertificateChain(attestation.attestationStatement.x5c) else {
        return false
    }
    
    // 4. Attestation signature
    let signedData = attestation.authenticatorData.rawData + SHA256.hash(data: clientDataHash)
    guard verifySignature(
        signature: attestation.attestationStatement.signature,
        data: signedData,
        publicKey: extractPublicKey(from: attestation.attestationStatement.x5c[0])
    ) else {
        return false
    }
    
    // 5. Receipt (if present)
    if let receipt = extractReceipt(from: attestation) {
        guard verifyReceiptCMS(receipt) else {
            return false
        }
    }
    
    // 6. Public key consistency
    guard verifyPublicKeyConsistency(attestation) else {
        return false
    }
    
    return true
}
```

---

## Security Considerations

### Trust Anchors

You must maintain your own trust anchor store:
- Apple Root CA G3 (for App Attest certificates)
- Apple Fraud Receipt Signing (for receipt verification)

Do not rely on system trust stores alone.

### Key Storage

After verification, store:
- Credential ID → Public Key mapping
- Sign count per credential
- Attestation timestamp

This enables:
- Assertion verification (using stored public key)
- Replay protection (monotonic sign count)
- Key rotation policies

### Error Handling

Fail securely:
- Reject on any verification failure
- Log all failures for analysis
- Never proceed with unverified attestations

---

## See Also

- `docs/WHAT_THIS_TOOL_IS.md` - What the decoder does and doesn't do
- `docs/COMMAND_REFERENCE.md` - How to use the decoder
- Apple's App Attest documentation (for official verification requirements)
