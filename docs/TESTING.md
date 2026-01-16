# Trust Boundary Testing

## Why This Exists

The iOS test app exists to demonstrate a **cryptographically closed trust boundary**. The app is a **producer only**—it generates App Attest assertions and sends them to the backend. It performs no decoding, no cryptographic verification, and makes no trust decisions. All security validation happens server-side.

This separation is intentional and non-negotiable. The client cannot influence trust decisions. The backend validates every assertion cryptographically, rejects tampered data, and makes the final trust decision. This prevents "helpful" client logic from introducing security vulnerabilities.

The two tests below prove the boundary is closed: valid assertions pass, tampered assertions fail. Nothing in between.

## Test 1: Happy Path (Real Assertion)

**Objective:** Verify that a legitimate App Attest assertion is accepted by the backend.

**Steps:**
1. Launch the iOS test app on a physical device (App Attest does not work in simulator)
2. Generate an App Attest key (tap "Generate Key")
3. Attest the key (tap "Attest Key")
4. Tap "Send to Backend" (this generates a fresh assertion and sends it to the backend)

**Expected Result:**
- Backend responds with: `{ "status": "verified" }`
- UI displays: **✅ Verified**

**What This Proves:**
- App Attest key is valid
- Assertion format is correct
- Sig_structure reconstruction is correct
- Public key lookup works
- Validator math is correct
- Trust decision path is wired

## Test 2: Tamper Test (Mutated Assertion)

**Objective:** Verify that tampered assertions are rejected by the backend.

**Steps:**
1. Generate an assertion using Test 1
2. Before sending to backend, mutate the assertion:
   - Copy the base64 assertion from the UI
   - Decode it to bytes
   - Flip one byte anywhere in the assertionObject
   - Re-encode to base64
   - Replace the assertion in the request (requires backend modification or manual testing)
   
   **Alternative:** Modify the backend to mutate one byte before validation, or use a tool to mutate the assertion before sending.

3. Send the mutated assertion to the backend

**Expected Result:**
- Backend responds with: `{ "status": "rejected", "reason": "..." }`
- UI displays: **❌ Rejected: [reason]**

**What This Proves:**
- No normalization
- No forgiveness
- No "close enough" crypto
- No client influence on trust
- Cryptographic validation is strict

## Success Criteria

Both tests must pass:
- ✅ Test 1: Real assertion → verified
- ✅ Test 2: Mutated assertion → rejected

When both happen, the system is **cryptographically closed**.

Not "works on my phone." **Closed.**

## Important Notes

**Backend behavior with garbage input is correct:**
- A correct security backend rejects junk loudly
- It rejects malformed input early
- It never tries to be polite
- It never guesses intent

If your backend didn't behave that way, that would be a red flag.

**The iOS app is a producer only:**
- It generates assertions using DeviceCheck APIs
- It sends raw bytes to the backend
- It displays backend responses
- It does NOT decode assertions
- It does NOT verify signatures
- It does NOT make trust decisions

This is by design. The trust boundary is enforced by architecture, not by convention.
