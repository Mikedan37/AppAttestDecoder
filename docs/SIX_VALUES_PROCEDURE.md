# SIX_VALUES: Zero-Ambiguity Comparison

When verification fails, use this. Do not theorize. Do not refactor. Do not add more logging first.

## The six values (full identity of one assertion)

1. `verifyRunID`
2. `authenticatorData.sha256`
3. `clientDataHash.sha256`
4. `signedBytes.sha256`
5. `signature.sha256`
6. `keyID_sha256`

## Procedure

1. **Pick one failing `verifyRunID`.** One. Ignore all others.

2. **Copy the SIX_VALUES block from the frontend.**  
   Grep: `verifyRunID=<that-uuid>` → find the `---------- SIX_VALUES ----------` block.

3. **Copy the SIX_VALUES block from the backend for the same run.**  
   (Same `verifyRunID` or `flowID`.)

4. **Paste them side by side.**

## Then

- **First mismatch** → bug location. Identity or lifecycle. Not crypto.
- **No mismatch** → only two options left: wrong public key material, or signature parsing (DER vs raw / malformed DER). Tiny search space.

Done.
