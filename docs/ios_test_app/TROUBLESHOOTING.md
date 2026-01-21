# Troubleshooting

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

Common issues and solutions for the diagnostic test app.

---

## Network Connectivity

### Backend Not Reachable

**Symptoms:**
- "Ping Backend" fails
- HTTP errors (connection refused, timeout)
- Local network permission errors

**Solutions:**

1. **Verify backend is running**
   - Check backend logs
   - Test with `curl` from terminal

2. **Check local network permissions**
   - Settings → Privacy & Security → Local Network
   - Enable access for `AppAttestDecoderTestApp`

3. **Verify backend URL**
   - Check IP address and port
   - Ensure URL is correct (e.g., `http://10.0.0.108:8080`)

4. **Check App Transport Security**
   - Ensure ATS allows HTTP for local network
   - See `IOS_SANDBOX_SETUP.md` for configuration

### URL Encoding Issues

**Symptoms:**
- Backend returns "flowID and keyID query parameters required"
- Backend returns "Invalid keyID format"
- `+` characters appear as spaces in backend logs

**Solutions:**

- Frontend uses `URLComponents` and `URLQueryItem` for encoding
- `keyID` is base64-encoded using custom encoding for `+`, `/`, `=`
- If issues persist, check frontend logs for `percentEncodedQuery` value

---

## App Attest Capability

### "App Attest Not Available"

**Symptoms:**
- Error when calling `DCAppAttestService.shared.isSupported`
- Error when generating keys

**Solutions:**

1. **Verify capability is enabled**
   - Xcode → Signing & Capabilities
   - Ensure "App Attest" is added

2. **Verify App ID configuration**
   - Apple Developer Portal → Identifiers
   - Ensure App Attest capability is enabled for your App ID

3. **Use physical device**
   - App Attest does NOT work on simulators
   - Must use iPhone or iPad running iOS 14.0+

### Key Generation Fails

**Symptoms:**
- `generateKey()` returns error
- Key generation button does nothing

**Solutions:**

- Check device logs for specific error
- Ensure device has Secure Enclave (iPhone 5s or later)
- Ensure device is not in a restricted state

---

## State Consistency

### "flowID is missing"

**Symptoms:**
- Cannot proceed past Register step
- Challenge request fails

**Solutions:**

- Ensure Register completed successfully
- Check backend response contains `flowID`
- If Register failed, try again with new key

### "keyID mismatch"

**Symptoms:**
- Verify request fails with keyID mismatch error
- Registered keyID does not match current keyID

**Solutions:**

- Do not generate new key mid-flow
- If key changed, restart flow: Generate Key → Attest → Register → Assert → Verify
- Check UI shows correct registered keyID

### "Missing assertion evidence"

**Symptoms:**
- Cannot send assertion to backend
- Evidence store is empty

**Solutions:**

- Ensure "Assert Key" completed successfully
- Check logs for assertion generation errors
- Try generating assertion again

---

## Backend Errors

### "challenge_base64 required"

**Symptoms:**
- Register request fails
- Backend returns error about missing challenge

**Solutions:**

- Complete "Attest Key" step before attempting Register
- Check `ClientDataContext` contains challenge
- Verify challenge is base64-encoded correctly

### "Invalid challenge response"

**Symptoms:**
- Challenge request succeeds but assertion generation fails
- Challenge decoding fails

**Solutions:**

- Check backend logs for challenge validation
- Verify challenge decodes to 32 bytes
- Ensure challenge_id is valid UUID

### "ECDSA verification failed"

**Symptoms:**
- Backend returns verification failure
- Backend reports signature mismatch

**Solutions:**

- This is a backend verification issue, not frontend
- Check backend logs for detailed error
- Verify `clientData_base64` matches what backend expects
- Check `signedBytes` computation matches backend

---

## UI Issues

### Buttons Disabled

**Symptoms:**
- Buttons grayed out during operations
- Cannot proceed to next step

**Solutions:**

- Wait for current operation to complete
- Check for error messages
- Verify network connectivity

### No Response Displayed

**Symptoms:**
- Backend request completes but no response shown
- UI does not update

**Solutions:**

- Check console logs for errors
- Verify response decoding succeeds
- Check UI state updates on main thread

---

## Logging

### Finding Logs

All logs are prefixed with:
- `[ContentView]` - Main view operations
- `[FRONTEND]` - Frontend-specific logs
- `verifyRunID=...` - Correlation ID for full flow

### Common Log Patterns

**Registration:**
```
[ContentView] REGISTER PRE-FLIGHT: method=POST url=...
[ContentView] REGISTER.challenge_base64=...
```

**Challenge:**
```
[FRONTEND][CHALLENGE][REQUEST] URL=...
[FRONTEND][CHALLENGE][RESPONSE RAW] {...}
```

**Verify:**
```
[ContentView] VERIFY verifyRunID=... | keyID and flowID identity
[ContentView] VERIFY verifyRunID=... | Sending assertion: ...
```

---

## Related Documentation

- **`SETUP.md`** - Initial setup instructions
- **`DATA_FLOW.md`** - What data flows through the app
- **`ROLE_OF_FRONTEND.md`** - Frontend responsibilities
- **`IOS_SANDBOX_SETUP.md`** - Sandbox configuration
