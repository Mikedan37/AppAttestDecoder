import SwiftUI
import CryptoKit
import DeviceCheck
import UIKit
import AppAttestCore

// Trust model (frontend): Assertions are opaque Secure Enclave artifacts.
// Cryptographic validity is determined by the Secure Enclave and backend verification, not by on-device ECDSA verification.

enum InspectorMode {
    case live
    case manual
}

/// Assertion signatures are opaque device proofs. We do NOT re-verify them locally with CryptoKit.
///
/// - Assertions are not locally verifiable ECDSA messages. Signature bytes are observational only.
///   CryptoKit verification (isValidSignature) is not a correctness signal.
/// - Empirical: DCAppAttestService.generateAssertion returns a signature that does not pass
///   CryptoKit's isValidSignature(signature, for: authenticatorData||clientDataHash) even with
///   identical inputs. ECDSA self-check on-device fails.
/// - The App Attest API does not publish a signed-message contract for the assertion blob. Cryptographic validity
///   is determined by the Secure Enclave and attestation binding (keyID ↔ credential); the backend performs
///   the only meaningful verification. See docs/APP_ATTEST_E2E_CONTRACT.md.
///
/// Removed: CryptoKit_signs_MESSAGE_not_digest, self_check, and any local ECDSA/P256 verification.
/// Assertions are opaque Secure Enclave artifacts; such checks are not a correctness signal and empirically fail.
enum AssertionTrustModel {
    /// Assertion cryptographic validity is determined by the Secure Enclave and attestation
    /// binding, not by local ECDSA verification. Frontend: key continuity, flowID continuity,
    /// challenge freshness, clientDataHash integrity, assertion CBOR structural sanity only.
    case opaqueAppleAssertion
}

private struct RegisterResponse: Decodable {
    let status: String
    let flowID: String?
    let reason: String?
    let publicKeyX963: String?
    let publicKey: String?
}

/// GET /app-attest/challenge response. Backend mints challenge and ID; frontend builds clientData and hashes it.
private struct ChallengeResponse: Decodable {
    let challengeB64: String
    let challengeID: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case challengeB64 = "challenge_b64"
        case challengeID = "challenge_id"
        case expiresAt
    }
}

/// URL query value encoding helper for base64 strings
/// RFC 3986-safe: encodes +, /, = and other special chars, preserves alphanumeric and safe chars
/// Use this ONLY when building percentEncodedQuery directly (Option B)
extension String {
    var urlQueryValueEncoded: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return self.addingPercentEncoding(withAllowedCharacters: allowed)!
    }
}

/// Canonical clientData for assertion. Encoded with sortedKeys; frontend computes clientDataHash = SHA256(clientDataBytes).
/// JSON field names: challenge, challenge_id, flow_id, key_id, bundle_id, timestamp
private struct ClientDataPayload: Encodable {
    let challenge_b64: String  // Backend-provided base64 challenge
    let challenge_id: String
    let flow_id: String
    let key_id_b64: String  // Base64 keyID
    let bundle_id: String
    let timestamp_iso8601: String
    
    enum CodingKeys: String, CodingKey {
        case challenge = "challenge"  // JSON key: "challenge" (value is challenge_b64 string)
        case challenge_id = "challenge_id"
        case flow_id = "flow_id"
        case key_id = "key_id"  // JSON key: "key_id" (value is key_id_b64 string)
        case bundle_id = "bundle_id"
        case timestamp = "timestamp"  // JSON key: "timestamp" (value is timestamp_iso8601 string)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challenge_b64, forKey: .challenge)
        try container.encode(challenge_id, forKey: .challenge_id)
        try container.encode(flow_id, forKey: .flow_id)
        try container.encode(key_id_b64, forKey: .key_id)
        try container.encode(bundle_id, forKey: .bundle_id)
        try container.encode(timestamp_iso8601, forKey: .timestamp)
    }
}

// Reference frontend: generates artifacts, logs evidence. No local assertion verification; backend owns trust, freshness, binding, replay.
struct ContentView: View {
    private let service = DCAppAttestService.shared
    @StateObject private var contextStore = AppAttestContextStore.shared
    private let keyManager = AppAttestKeyManager.shared
    
    /// Consistent SHA256 hex calculation - always hash Data, never strings
    private func sha256Hex(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }

    /// Lowercase hex, no spaces. Use for backend verification payload only.
    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// Extract X9.63 (04||x||y) from attestation's credentialPublicKey COSE. Returns nil on any failure.
    private func extractX963FromAttestation(_ attestationData: Data) -> Data? {
        guard !attestationData.isEmpty else { return nil }
        do {
            let att = try AppAttestDecoder(teamID: nil).decodeAttestation(attestationData)
            guard let cred = att.authenticatorData.attestedCredentialData else { return nil }
            guard let dict = cred.credentialPublicKey.mapValue else { return nil }
            let x = dict[.negative(-2)]?.bytes
            let y = dict[.negative(-3)]?.bytes
            guard let x = x, let y = y, x.count == 32, y.count == 32 else { return nil }
            return Data([0x04]) + x + y
        } catch { return nil }
    }

    /// Extract x963 from attestation x5c[0] (leaf) SubjectPublicKeyInfo for evidence export. 65 bytes, starts 0x04. Returns nil on failure; logs and surfaces to user.
    /// Do NOT use keyID, credentialPublicKey (COSE), or any cached value.
    private func extractX963FromLeafCertSPKI(_ attestationData: Data) -> Data? {
        let att: AttestationObject
        do { att = try AppAttestDecoder(teamID: nil).decodeAttestation(attestationData) } catch {
            print("[ContentView] extractX963FromLeafCertSPKI: decodeAttestation failed: \(error)")
            return nil
        }
        guard !att.attestationStatement.x5c.isEmpty else {
            print("[ContentView] extractX963FromLeafCertSPKI: x5c is empty")
            return nil
        }
        let leafDER = att.attestationStatement.x5c[0]
        let cert: X509Certificate
        do { cert = try X509Certificate.parse(der: leafDER) } catch {
            print("[ContentView] extractX963FromLeafCertSPKI: X509 parse failed: \(error)")
            return nil
        }
        guard let bits = cert.subjectPublicKeyBits, bits.count == 65, bits.first == 0x04 else {
            print("[ContentView] extractX963FromLeafCertSPKI: leaf SPKI expected 65-byte x963 starting 0x04, got \(cert.subjectPublicKeyBits?.count ?? 0) bytes")
            return nil
        }
        return bits
    }

    @State private var isSupported: Bool?
    
    @State private var keyID: String?
    @State private var keyIDError: String?

    // IMPORTANT: Backend mints challenge only. Frontend builds canonical clientData JSON, computes clientDataHash = SHA256(clientDataBytes), passes clientDataHash to generateAssertion, and sends clientData_base64 to verify. Frontend NEVER accepts a backend-provided clientDataHash.
    @State private var attestationBlobB64: String?
    @State private var attestationError: String?
    
    // State for backend responses; verification is performed by backend
    @State private var backendURL: String = "http://10.0.0.108:8080"
    @State private var backendResponse: String?
    @State private var backendError: String?
    @State private var isSendingToBackend = false
    @State private var isRegistering = false
    @State private var isRequestingChallenge = false
    @State private var registrationSucceeded = false
    @State private var registeredKeyID: String? // Track the keyID that was successfully registered
    @State private var currentFlowID: String? // IMPORTANT: flowID storage - generated after REGISTER, reused for CLIENT_DATA_HASH and VERIFY
    @State private var storedPublicKeyX963: Data? // X9.63 public key from REGISTER response or extracted from attestation; included in backend verification payload
    @State private var currentVerifyRunID: String? // Monotonic ID per verify attempt: grep this to reconstruct TRANSPORT→CLIENT_DATA_HASH→KEY_IDENTITY→DECODED→DIGESTS→RESULT
    @State private var lastBackendForensics: (runID: String, forensics: BackendForensics)? = nil // From /verify "forensics" (dev-only); for Diff View
    @State private var showDiffView = false
    @State private var backendAssertionMode: String = "opaque" // "strict" | "opaque" for X-AppAttest-Mode
    @State private var verifyFailureFirstDifferingByteIndex: Int?
    @State private var verifyFailureECDSA: Bool = false
    @State private var lastRegisterTarget: String? = nil   // full URL used when REGISTER fired; for plumbing debug
    @State private var pingResult: String? = nil
    @State private var isPinging = false
    @State private var evidencePublicKeyX963: Data? = nil  // x963 from attestation x5c[0] SPKI only; for evidence bundle export

    // UI display state (for debugging)
    @State private var lastExpiresAt: String?
    @State private var lastKeyID_sha256_prefix: String?
    @State private var lastAssertionObject_sha256_prefix: String?
    
    // Preview state: Generate assertion, then verify uses that same assertion
    @State private var pendingAssertionB64: String?
    @State private var pendingExpiresAt: String?
    @State private var isGeneratingAssertion = false
    
    @State private var showShareSheet = false
    @State private var mode: InspectorMode = .live
    @State private var flowTraceEntries: [FlowTraceEntry] = []
    @State private var showFlowTrace = false
    
    init() {
        print("[ContentView] Initializing...")
        
        // IMPORTANT: Log bundle ID for backend comparison (backend enforces policy)
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        print("[ContentView] ========================================")
        print("[ContentView] BUNDLE ID (backend expects this value)")
        print("[ContentView] ========================================")
        print("[ContentView] Running bundle ID: \(bundleID)")
        print("[ContentView] Expected bundle ID: DanylchukStudios.AppAttestDecoderTestApp")
        if bundleID == "DanylchukStudios.AppAttestDecoderTestApp" {
            print("[ContentView] Bundle ID matches expected value")
        } else {
            print("[ContentView] ⚠ WARNING: Bundle ID mismatch!")
            print("[ContentView] ⚠ Bundle ID mismatch - backend may reject based on policy")
            print("[ContentView] Backend expects bundle ID: \(bundleID)")
        }
        print("[ContentView] ========================================")
    }
    
    // MARK: - Helper Functions (defined before body so they can be referenced in closures)
    
    /// Decode base64 with tolerance for base64url and missing padding
    /// Handles: base64url (- and _), missing padding (=), whitespace
    private func decodeBase64Relaxed(_ s: String) -> Data? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Convert base64url to standard base64
        t = t.replacingOccurrences(of: "-", with: "+")
             .replacingOccurrences(of: "_", with: "/")
        
        // Pad to multiple of 4
        let rem = t.count % 4
        if rem != 0 {
            t += String(repeating: "=", count: 4 - rem)
        }
        
        return Data(base64Encoded: t)
    }
    
    /// Store attestation context (client-side only, for inspection UI)
    /// NOTE: Frontend does NOT decode attestation for verification purposes
    /// Backend extracts public key from attestation during registration
    /// REMOVED: clientDataHash - backend owns challenge and clientDataHash
    func captureAttestationContext(keyID: String, attestationBlob: Data) {
        // Store public key only (no clientDataHash storage)
        // Note: This is a placeholder - actual context storage would go here if needed
        print("[ContentView] Stored attestation context for keyID: \(keyID)")
    }
    
    // MARK: - Network Functions (defined before body so they can be referenced in closures)
    
    /// Phase 1: Send attestation to backend to register public key
    /// POST /app-attest/register
    /// Payload: keyID, attestationObject (base64), challenge_base64, clientDataHash_base64 (base64 32-byte; same as attestKey).
    /// Expected: { "status": "registered", "flowID": "..." }
    /// clientDataHash_base64: from ClientDataContext.clientDataHash; do not recompute.
    func sendAttestationToBackend(keyID: String, attestationBlobB64: String) {
        isRegistering = true
        backendError = nil
        backendResponse = nil

        guard let ctx = ClientDataContextManager.shared.getContext(for: keyID), !ctx.challenge.isEmpty else {
            isRegistering = false
            backendError = "challenge_base64 missing for register: no ClientDataContext or empty challenge for this keyID. Tap 'Attest Key' first."
            print("[ContentView] ERROR: REGISTER aborted: challenge missing for keyID. Tap Attest Key first.")
            return
        }
        let challenge_base64 = ctx.challenge.base64EncodedString()
        
        // IMPORTANT: Log keyID_sha256 for backend comparison - should match assertion keyID byte-for-byte
        print("[ContentView] ========================================")
        print("[ContentView] REGISTER - keyID identity")
        print("[ContentView] ========================================")
        print("[ContentView] REGISTER - keyID: \(keyID)")
        if let keyIDData = Data(base64Encoded: keyID) {
            let keyIDHex = keyIDData.map { String(format: "%02x", $0) }.joined()
            let keyID_sha256_hex = sha256Hex(keyIDData)
            print("[ContentView] REGISTER - keyID (hex): \(keyIDHex)")
            print("[ContentView] REGISTER - keyID_sha256_hex: \(keyID_sha256_hex)")
            
            // State consistency check: keyID matches KeyManager (for UI consistency, not security)
            if let storedKeyID = keyManager.getKeyID() {
                if let storedKeyIDData = Data(base64Encoded: storedKeyID) {
                    let storedKeyID_sha256_hex = sha256Hex(storedKeyIDData)
                    if keyID_sha256_hex == storedKeyID_sha256_hex {
                        print("[ContentView] REGISTER keyID matches KeyManager - key continuity check passed (state consistency)")
                    } else {
                        print("[ContentView] ERROR: ERROR: REGISTER keyID does NOT match KeyManager!")
                        print("[ContentView]   REGISTER keyID_sha256_hex: \(keyID_sha256_hex)")
                        print("[ContentView]   KeyManager keyID_sha256_hex: \(storedKeyID_sha256_hex)")
                    }
                }
            }
        }
        print("[ContentView] ========================================")
        
        guard let url = URL(string: "\(backendURL)/app-attest/register") else {
            isRegistering = false
            backendError = "Invalid backend URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: String] = [
            "keyID": keyID,
            "attestationObject": attestationBlobB64,
            "challenge_base64": challenge_base64,
            "clientDataHash_base64": ctx.clientDataHash.base64EncodedString()
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            isRegistering = false
            backendError = "Failed to encode request"
            return
        }

        request.httpBody = jsonData

        #if DEBUG
        print("[ContentView] REGISTER.challenge_base64=\(challenge_base64)")
        #endif
        print("[ContentView] REGISTER.challenge_sha256_hex=\(sha256Hex(ctx.challenge))")
        print("[ContentView] REGISTER.clientDataHash_sha256_hex=\(sha256Hex(ctx.clientDataHash))")

        lastRegisterTarget = url.absoluteString
        print("[ContentView] REGISTER PRE-FLIGHT: method=\(request.httpMethod ?? "POST") url=\(url.absoluteString) baseURL=\(backendURL) headers=\(request.allHTTPHeaderFields ?? [:]) body_size=\(request.httpBody?.count ?? 0)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isRegistering = false
                
                if let error {
                    // Network error = registration failed = cannot proceed to assertion generation
                    self.registrationSucceeded = false
                    self.backendError = "Network error: \(error.localizedDescription)"
                    print("[ContentView] ERROR: Registration failed (network error) - cannot proceed to assertion generation (state consistency)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.registrationSucceeded = false
                    self.backendError = "Invalid response"
                    print("[ContentView] ERROR: REGISTER failed (invalid response) - cannot proceed to assertion generation (state consistency)")
                    return
                }
                
                // LOUD LOGGING: Always log HTTP status
                print("[ContentView] REGISTER response status: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.registrationSucceeded = false
                    self.backendError = "HTTP error: \(httpResponse.statusCode)"
                    print("[ContentView] ERROR: REGISTER failed (HTTP \(httpResponse.statusCode)) - cannot proceed to assertion generation (state consistency)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("[ContentView] REGISTER response body: \(body)")
                    }
                    return
                }
                
                guard let data = data else {
                    self.registrationSucceeded = false
                    self.backendError = "No response data"
                    print("[ContentView] ERROR: REGISTER failed (no data) - cannot proceed to assertion generation (state consistency)")
                    return
                }
                
                // LOUD LOGGING: Always log raw response body
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    self.registrationSucceeded = false
                    self.backendError = "Invalid response encoding"
                    print("[ContentView] ERROR: REGISTER failed (invalid encoding) - cannot proceed to assertion generation (state consistency)")
                    return
                }
                
                print("[ContentView] REGISTER response body: \(jsonString)")
                self.backendResponse = jsonString

                guard let response = try? JSONDecoder().decode(RegisterResponse.self, from: data) else {
                    self.registrationSucceeded = false
                    self.registeredKeyID = nil
                    self.currentFlowID = nil
                    self.storedPublicKeyX963 = nil
                    self.currentVerifyRunID = nil
                    EvidenceStore.shared.clear()
                    self.backendError = "Invalid REGISTER response JSON"
                    print("[ContentView] ERROR: REGISTER failed - invalid JSON")
                    return
                }

                print("[ContentView] REGISTER parsed status: \(response.status)")

                switch response.status {
                case "accepted":
                    guard let flowID = response.flowID, !flowID.isEmpty else {
                        self.registrationSucceeded = false
                        self.registeredKeyID = nil
                        self.currentFlowID = nil
                        self.storedPublicKeyX963 = nil
                        self.currentVerifyRunID = nil
                        EvidenceStore.shared.clear()
                        self.backendError = "State error: flowID missing or empty in REGISTER response. Cannot proceed."
                        print("[ContentView] ERROR: REGISTER failed - flowID missing in response")
                        return
                    }
                    self.registrationSucceeded = true
                    self.registeredKeyID = keyID
                    self.currentFlowID = flowID
                    if let b64 = response.publicKeyX963 ?? response.publicKey, !b64.isEmpty, let pk = Data(base64Encoded: b64), !pk.isEmpty {
                        self.storedPublicKeyX963 = pk
                    } else if let attData = Data(base64Encoded: attestationBlobB64), let pk = self.extractX963FromAttestation(attData) {
                        self.storedPublicKeyX963 = pk
                    } else {
                        self.storedPublicKeyX963 = nil
                    }
                    self.backendResponse = jsonString
                    print("[ContentView] REGISTER succeeded - flowID received, ready for assertion generation")
                    print("[ContentView] Stored registered keyID for continuity checks: \(keyID)")
                    print("[ContentView] REGISTER - flowID: \(flowID) (BACKEND-ISSUED)")
                    
                    // Add flow trace entry
                    flowTraceEntries.append(FlowTraceEntry(
                        step: "Registration",
                        timestamp: Date(),
                        flowID: flowID,
                        status: "completed",
                        details: "keyID registered, flowID received"
                    ))

                    self.pendingAssertionB64 = nil
                    self.pendingExpiresAt = nil

                case "rejected":
                    self.registrationSucceeded = false
                    self.registeredKeyID = nil
                    self.currentFlowID = nil
                    self.storedPublicKeyX963 = nil
                    self.currentVerifyRunID = nil
                    EvidenceStore.shared.clear()
                    self.backendError = response.reason ?? "Unknown rejection"
                    print("[ContentView] ERROR: REGISTER rejected: \(self.backendError ?? "")")

                default:
                    self.registrationSucceeded = false
                    self.registeredKeyID = nil
                    self.currentFlowID = nil
                    self.storedPublicKeyX963 = nil
                    self.currentVerifyRunID = nil
                    EvidenceStore.shared.clear()
                    self.backendError = "Unknown status: \(response.status)"
                    print("[ContentView] ERROR: REGISTER unknown status: \(response.status)")
                }
            }
        }.resume()
    }

    /// POST /debug/echo with {"ping":"pong"}. Isolates: if backend logs it, network+permissions OK; if not and device shows "Local network prohibited", permissions/ATS are the blocker.
    func pingBackend() {
        isPinging = true
        pingResult = nil
        let base = backendURL.hasSuffix("/") ? String(backendURL.dropLast()) : backendURL
        guard let url = URL(string: "\(base)/debug/echo") else {
            isPinging = false
            pingResult = "Invalid URL"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["ping": "pong"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            isPinging = false
            pingResult = "Failed to encode body"
            return
        }
        request.httpBody = jsonData
        print("[ContentView] PING PRE-FLIGHT: method=POST url=\(url.absoluteString) baseURL=\(backendURL) body_size=\(jsonData.count)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isPinging = false
                if let error {
                    self.pingResult = "Error: \(error.localizedDescription)"
                    print("[ContentView] PING failed: \(error.localizedDescription)")
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    self.pingResult = "No HTTP response"
                    return
                }
                if (200...299).contains(http.statusCode) {
                    self.pingResult = "OK \(http.statusCode)"
                    print("[ContentView] PING OK \(http.statusCode)")
                } else {
                    self.pingResult = "HTTP \(http.statusCode)"
                    print("[ContentView] PING HTTP \(http.statusCode)")
                }
            }
        }.resume()
    }

    /// Called when attestKey succeeds. Extract x963 from x5c[0] SPKI only; store and log. On failure, set attestationError and print.
    private func onAttestationSucceededForEvidence(_ attestationData: Data, keyID: String) {
        guard let pk = extractX963FromLeafCertSPKI(attestationData) else {
            evidencePublicKeyX963 = nil
            attestationError = "Public key extraction from attestation leaf cert failed. See console."
            return
        }
        evidencePublicKeyX963 = pk
        print("[ContentView] publicKey_source=leaf_certificate_spki publicKey_x963_length=\(pk.count) publicKey_x963_hex=\(pk.map { String(format: "%02x", $0) }.joined()) publicKey_x963_sha256=\(sha256Hex(pk))")

        let keyIDBytes = Data(base64Encoded: keyID) ?? Data()
        let keyID_hex = keyIDBytes.map { String(format: "%02x", $0) }.joined()
        let publicKeyX963_hex = pk.map { String(format: "%02x", $0) }.joined()
        let sha256Pub_hex = sha256Hex(pk)
        let eq = keyIDBytes.count == 32 && Data(SHA256.hash(data: pk)) == keyIDBytes
        print("[ContentView] keyID_hex=\(keyID_hex) keyID_length=\(keyIDBytes.count)")
        print("[ContentView] publicKeyX963_hex=\(publicKeyX963_hex) publicKeyX963_length=\(pk.count) 0x04_prefix=\(pk.first == 0x04)")
        print("[ContentView] sha256(publicKeyX963)_hex=\(sha256Pub_hex)")
        print("[ContentView] KEYID_DERIVATION_CHECK: sha256(pubKeyX963) == keyID -> \(eq)")
    }

    /// Build OpenSSL-ready JSON from evidence publicKey (x5c[0] SPKI) and last assertion evidence. On missing data or serialization failure, set backendError and print.
    private func copyEvidenceBundle() {
        guard let pk = evidencePublicKeyX963 else {
            backendError = "Evidence: missing public key. Attest first."
            print("[ContentView] copyEvidenceBundle: evidencePublicKeyX963 is nil")
            return
        }
        guard let ev = EvidenceStore.shared.getLast() else {
            backendError = "Evidence: no assertion evidence. Run Assert Key and Verify once."
            print("[ContentView] copyEvidenceBundle: no assertion evidence. Run Assert Key and Verify once.")
            return
        }
        let pub: [String: Any] = [
            "source": "leaf_certificate_spki",
            "x963_hex": CryptoEvidence.rawHex(pk),
            "x963_length": pk.count,
            "sha256": CryptoEvidence.sha256Hex(pk)
        ]
        let auth: [String: Any] = [
            "hex": ev.authenticatorData_hex,
            "length": ev.authenticatorData.count,
            "sha256": ev.authenticatorData_sha256
        ]
        let client: [String: Any] = [
            "hex": ev.clientDataHash_hex,
            "length": ev.clientDataHash.count,
            "sha256": ev.clientDataHash_sha256
        ]
        let signed: [String: Any] = [
            "hex": CryptoEvidence.rawHex(ev.signedBytes),
            "length": ev.signedBytes.count,
            "sha256": ev.signedBytes_sha256
        ]
        let sig: [String: Any] = [
            "der_hex": ev.signature_hex,
            "length": ev.signatureDER.count,
            "sha256": ev.signature_sha256
        ]
        let top: [String: Any] = [
            "publicKey": pub,
            "authenticatorData": auth,
            "clientDataHash": client,
            "signedBytes": signed,
            "signature": sig
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: top), let str = String(data: data, encoding: .utf8) else {
            backendError = "Evidence: JSON serialization failed."
            print("[ContentView] copyEvidenceBundle: JSON serialization failed")
            return
        }
        UIPasteboard.general.string = str
    }

    /// Copy JSON for backend debug endpoint: publicKeyX963_hex, signedBytes_hex, signatureDER_hex. Raw hex only, no base64, no pretty. On missing data, set backendError.
    private func copyOpenSSLPayload() {
        let pk = evidencePublicKeyX963 ?? storedPublicKeyX963 ?? EvidenceStore.shared.getLast()?.publicKeyX963
        guard let publicKeyX963 = pk else {
            backendError = "OpenSSL payload: missing public key. Attest and register first."
            print("[ContentView] copyOpenSSLPayload: no publicKeyX963")
            return
        }
        guard let ev = EvidenceStore.shared.getLast() else {
            backendError = "OpenSSL payload: no assertion evidence. Run Assert Key and Verify once."
            print("[ContentView] copyOpenSSLPayload: no assertion evidence")
            return
        }
        let obj: [String: String] = [
            "publicKeyX963_hex": CryptoEvidence.rawHex(publicKeyX963),
            "signedBytes_hex": CryptoEvidence.rawHex(ev.signedBytes),
            "signatureDER_hex": ev.signature_hex
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: obj), let str = String(data: data, encoding: .utf8) else {
            backendError = "OpenSSL payload: JSON serialization failed."
            return
        }
        UIPasteboard.general.string = str
    }
    
    /// Copy Assertion Package: compact JSON with all assertion data for backend verification
    func copyAssertionPackage() {
        guard let ev = EvidenceStore.shared.getLast() else {
            backendError = "Assertion Package: no assertion evidence. Run Assert Key first."
            print("[ContentView] copyAssertionPackage: no assertion evidence")
            return
        }
        guard let assertionB64 = pendingAssertionB64 else {
            backendError = "Assertion Package: no assertion object. Run Assert Key first."
            print("[ContentView] copyAssertionPackage: no assertion object")
            return
        }
        guard let keyID = keyID else {
            backendError = "Assertion Package: no keyID."
            print("[ContentView] copyAssertionPackage: no keyID")
            return
        }
        
        let nonce = Data(SHA256.hash(data: ev.signedBytes))
        let nonceHex = CryptoEvidence.rawHex(nonce)
        let clientDataB64 = CryptoEvidence.base64Std(ev.clientDataBytes)
        let clientDataSha256 = CryptoEvidence.sha256Hex(ev.clientDataBytes)
        
        let obj: [String: String] = [
            "verifyRunID": ev.verifyRunID,
            "flowID": ev.flowID ?? "",
            "keyID_b64": keyID,
            "challenge_id": ev.challenge_id,
            "clientData_base64": clientDataB64,
            "assertionObject_base64": assertionB64,
            "clientData_sha256": clientDataSha256,
            "clientDataHash_hex": ev.clientDataHash_hex,
            "authenticatorData_hex": ev.authenticatorData_hex,
            "signatureDER_hex": ev.signature_hex,
            "signedBytes_sha256": ev.signedBytes_sha256,
            "nonce_hex": nonceHex
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []), let str = String(data: data, encoding: .utf8) else {
            backendError = "Assertion Package: JSON serialization failed."
            print("[ContentView] copyAssertionPackage: JSON serialization failed")
            return
        }
        UIPasteboard.general.string = str
        print("[ContentView] copyAssertionPackage: copied assertion package to clipboard")
    }

    /// Request challenge from backend, build canonical clientData, compute clientDataHash, generate assertion
    /// IMPORTANT: Frontend builds clientData JSON with sorted keys, computes SHA256(clientDataBytes), passes to generateAssertion
    /// Step 1: GET /app-attest/challenge?flowID=...&keyID=... -> { challenge_b64, challenge_id, expiresAt }
    /// Step 2: Build ClientDataPayload (canonical JSON with sorted keys)
    /// Step 3: Compute clientDataHash = SHA256(clientDataBytes)
    /// Step 4: Generate assertion with computed clientDataHash
    func requestChallengeAndGenerateAssertion(keyID: String) {
        // State check: Fail fast if registration didn't succeed
        guard registrationSucceeded else {
            backendError = "Attestation not registered. Tap 'Register Attestation' and wait for success."
            return
        }
        
        // IMPORTANT: State consistency check - keyID matches the registered keyID (for UI consistency, not security)
        guard let registeredKeyID = registeredKeyID, registeredKeyID == keyID else {
            backendError = "KeyID mismatch! The key used for assertion does not match the registered key. Generate new key and register again."
            print("[ContentView] ERROR: ERROR: keyID mismatch in /challenge request")
            if let registeredKeyID = registeredKeyID {
                print("[ContentView]   Registered keyID: \(registeredKeyID)")
                if let regKeyIDData = Data(base64Encoded: registeredKeyID) {
                    print("[ContentView]   Registered keyID_sha256_hex: \(sha256Hex(regKeyIDData))")
                }
            }
            print("[ContentView]   Request keyID: \(keyID)")
            if let reqKeyIDData = Data(base64Encoded: keyID) {
                print("[ContentView]   Request keyID_sha256_hex: \(sha256Hex(reqKeyIDData))")
            }
            return
        }
        
        // Prevent double-tap / re-entry
        guard !isRequestingChallenge && !isGeneratingAssertion else {
            print("[ContentView] SKIPPED: Assertion generation already in progress")
            return
        }
        
        guard service.isSupported else {
            backendError = "App Attest not supported on this device"
            return
        }
        
        // Verify keyID matches KeyManager
        guard let storedKeyID = keyManager.getKeyID(), storedKeyID == keyID else {
            backendError = "KeyID mismatch! The key used for assertion does not match the one used for attestation."
            return
        }
        
        // State check: flowID expected to exist - no silent fallbacks
        guard let flowID = currentFlowID else {
            backendError = "State error: flowID is missing. Registration needs to succeed and return flowID first."
            print("[ContentView] ERROR: ERROR: CHALLENGE request attempted without flowID")
            print("[ContentView] ERROR: flowID expected from backend in REGISTER response")
            return
        }
        
        let verifyRunID = UUID().uuidString
        currentVerifyRunID = verifyRunID
        
        isRequestingChallenge = true
        backendError = nil
        backendResponse = nil
        
        // STEP 6: State Integrity Check (flowID expected to exist)
                let keyID_sha256_hex: String
                if let keyIDData = Data(base64Encoded: keyID) {
                    keyID_sha256_hex = sha256Hex(keyIDData)
                } else {
                    keyID_sha256_hex = "invalid"
                }
                print("[FRONTEND][STATE] verifyRunID=\(verifyRunID)")
                print("[FRONTEND][STATE] flowID=\(flowID)")
                print("[FRONTEND][STATE] keyID_sha256=\(keyID_sha256_hex)")
                
                // Add flow trace entry for challenge request
                flowTraceEntries.append(FlowTraceEntry(
                    step: "Challenge Request",
                    timestamp: Date(),
                    flowID: flowID,
                    status: "sent",
                    details: "verifyRunID: \(verifyRunID)"
                ))
        
        // Log raw keyID before encoding
        print("[FRONTEND][CHALLENGE][KEYID] verifyRunID=\(verifyRunID)")
        print("[FRONTEND][CHALLENGE][KEYID] raw_base64=\(keyID)")
        print("[FRONTEND][CHALLENGE][KEYID] contains_plus=\(keyID.contains("+"))")
        print("[FRONTEND][CHALLENGE][KEYID] contains_equals=\(keyID.contains("="))")
        
        // STEP 2: Build URL using URLComponents + URLQueryItem
        // IMPORTANT: Let URLComponents do ALL encoding. Do NOT manually encode anything.
        // Pass raw base64 keyID to URLQueryItem - it will encode + as %2B and = as %3D automatically.
        // Never double-encode: either YOU encode OR URLComponents encodes, never both.
        
        // Parse backendURL to extract components
        guard let baseURL = URL(string: backendURL) else {
            isRequestingChallenge = false
            backendError = "Invalid backend URL"
            return
        }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = baseURL.scheme
        urlComponents.host = baseURL.host
        urlComponents.port = baseURL.port
        urlComponents.path = "/app-attest/challenge"
        
        // OPTION B: Encode values manually, then build percentEncodedQuery directly
        // This avoids double-encoding: we encode once, URLComponents does NOT encode again
        // IMPORTANT: URLQueryItem does NOT encode '+' by default, and if we pre-encode and pass to URLQueryItem,
        // it will double-encode (% becomes %25). So we bypass URLQueryItem entirely.
        
        // Encode keyID value: + -> %2B, / -> %2F, = -> %3D
        let encodedKeyID = keyID.urlQueryValueEncoded
        
        // Build query string directly: flowID=<raw>&keyID=<encoded>
        // flowID is UUID (no special chars), keyID is base64 (needs encoding)
        urlComponents.percentEncodedQuery = "flowID=\(flowID)&keyID=\(encodedKeyID)"
        
        guard let url = urlComponents.url else {
            isRequestingChallenge = false
            backendError = "Failed to construct challenge URL"
            return
        }
        
        // Log encoding verification BEFORE sending
        print("[FRONTEND][CHALLENGE][ENCODING] verifyRunID=\(verifyRunID)")
        print("[FRONTEND][CHALLENGE][ENCODING] url.absoluteString=\(url.absoluteString)")
        
        // IMPORTANT CHECK: Raw + must never appear in URL (backend treats + as space)
        assert(!url.absoluteString.contains("+"), "Raw + detected in URL — encoding bug")
        if url.absoluteString.contains("+") {
            isRequestingChallenge = false
            backendError = "URL encoding error: raw '+' detected in URL. Backend will treat it as space."
            print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) reason=raw_plus_detected")
            print("[FRONTEND][CHALLENGE][ERROR] URL=\(url.absoluteString)")
            return
        }
        
        // IMPORTANT CHECK: Raw space must never appear in URL
        assert(!url.absoluteString.contains(" "), "Raw space detected in URL — encoding bug")
        if url.absoluteString.contains(" ") {
            isRequestingChallenge = false
            backendError = "URL encoding error: raw space detected in URL."
            print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) reason=raw_space_detected")
            print("[FRONTEND][CHALLENGE][ERROR] URL=\(url.absoluteString)")
            return
        }
        
        // IMPORTANT CHECK: Check for double-encoding (should never see %252B, %252F, or %253D)
        if url.absoluteString.contains("%252B") || url.absoluteString.contains("%252F") || url.absoluteString.contains("%253D") {
            isRequestingChallenge = false
            backendError = "URL encoding error: double-encoding detected (%25XX). Remove manual encoding or use percentEncodedQuery directly."
            print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) reason=double_encoding_detected")
            print("[FRONTEND][CHALLENGE][ERROR] URL=\(url.absoluteString)")
            return
        }
        
        // IMPORTANT CHECK: Query structure must be intact (flowID= not flowID%3D)
        if url.absoluteString.contains("flowID%3D") || url.absoluteString.contains("keyID%3D") {
            isRequestingChallenge = false
            backendError = "URL encoding error: structural '=' was encoded. This breaks query parsing."
            print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) reason=structural_equals_encoded")
            print("[FRONTEND][CHALLENGE][ERROR] URL=\(url.absoluteString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // STEP 1: Instrument Network Layer - Log request artifacts
        print("[FRONTEND][CHALLENGE][REQUEST] verifyRunID=\(verifyRunID)")
        print("[FRONTEND][CHALLENGE][REQUEST] URL=\(url.absoluteString)")
        print("[FRONTEND][CHALLENGE][REQUEST] METHOD=GET")
        print("[FRONTEND][CHALLENGE][REQUEST] HEADERS=\(request.allHTTPHeaderFields ?? [:])")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isRequestingChallenge = false
                
                if let error {
                    self.backendError = "Failed to request challenge: \(error.localizedDescription)"
                    print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) error=\(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.backendError = "Invalid challenge response from backend"
                    print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) reason=no HTTPURLResponse")
                    return
                }
                
                // STEP 1: Log response artifacts (ALWAYS log status and body, even on error)
                print("[FRONTEND][CHALLENGE][RESPONSE] verifyRunID=\(verifyRunID)")
                print("[FRONTEND][CHALLENGE][RESPONSE] STATUS=\(httpResponse.statusCode)")
                
                // Log raw response body as UTF-8 string even on non-200
                let rawResponseString: String
                if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                    rawResponseString = responseStr
                    print("[FRONTEND][CHALLENGE][RESPONSE RAW] verifyRunID=\(verifyRunID)")
                    print(rawResponseString)
                } else {
                    rawResponseString = "<non-UTF8 or empty>"
                    print("[FRONTEND][CHALLENGE][RESPONSE RAW] verifyRunID=\(verifyRunID)")
                    print(rawResponseString)
                }
                
                // Handle non-200 responses with clear error message including body
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.backendError = "Challenge request failed: HTTP \(httpResponse.statusCode). Body: \(rawResponseString)"
                    print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) status=\(httpResponse.statusCode)")
                    print("[FRONTEND][CHALLENGE][ERROR] body=\(rawResponseString)")
                    return
                }
                
                guard let data = data else {
                    self.backendError = "Challenge request failed: HTTP \(httpResponse.statusCode) with no response body"
                    print("[FRONTEND][CHALLENGE][ERROR] verifyRunID=\(verifyRunID) reason=no_response_body")
                    return
                }
                
                // STEP 3 & 4: Decode with explicit CodingKeys and fail loudly
                let decoder = JSONDecoder()
                let challengeResp: ChallengeResponse
                do {
                    challengeResp = try decoder.decode(ChallengeResponse.self, from: data)
                } catch let decodingError as DecodingError {
                    self.backendError = "Failed to decode challenge response"
                    print("[FRONTEND][CHALLENGE][DECODE ERROR] verifyRunID=\(verifyRunID)")
                    print("[FRONTEND][CHALLENGE][DECODE ERROR] error=\(decodingError)")
                    print("[FRONTEND][CHALLENGE][DECODE ERROR] rawJSON=\(rawResponseString)")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("[FRONTEND][CHALLENGE][DECODE ERROR] keyNotFound=\(key.stringValue) path=\(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("[FRONTEND][CHALLENGE][DECODE ERROR] typeMismatch=\(type) path=\(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("[FRONTEND][CHALLENGE][DECODE ERROR] valueNotFound=\(type) path=\(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("[FRONTEND][CHALLENGE][DECODE ERROR] dataCorrupted path=\(context.codingPath)")
                    @unknown default:
                        print("[FRONTEND][CHALLENGE][DECODE ERROR] unknown error")
                    }
                    return
                } catch {
                    self.backendError = "Failed to decode challenge response: \(error.localizedDescription)"
                    print("[FRONTEND][CHALLENGE][DECODE ERROR] verifyRunID=\(verifyRunID) error=\(error)")
                    print("[FRONTEND][CHALLENGE][DECODE ERROR] rawJSON=\(rawResponseString)")
                    return
                }
                
                // STEP 5: Check Semantic Correctness (for logging, backend performs actual validation)
                guard let challengeBytes = Data(base64Encoded: challengeResp.challengeB64),
                      challengeBytes.count == 32 else {
                    self.backendError = "Invalid challenge_b64: not 32 bytes"
                    print("[FRONTEND][CHALLENGE][INVALID] verifyRunID=\(verifyRunID)")
                    print("[FRONTEND][CHALLENGE][INVALID] reason=challenge_b64 not 32 bytes (got \(Data(base64Encoded: challengeResp.challengeB64)?.count ?? 0))")
                    return
                }
                
                guard UUID(uuidString: challengeResp.challengeID) != nil else {
                    self.backendError = "Invalid challenge_id: not a valid UUID"
                    print("[FRONTEND][CHALLENGE][INVALID] verifyRunID=\(verifyRunID)")
                    print("[FRONTEND][CHALLENGE][INVALID] reason=challenge_id not a valid UUID: \(challengeResp.challengeID)")
                    return
                }
                
                // Parse expiresAt as ISO8601 date and check it's in the future (for logging, backend performs actual validation)
                let dateFormatter = ISO8601DateFormatter()
                if let expiresDate = dateFormatter.date(from: challengeResp.expiresAt) {
                    if expiresDate <= Date() {
                        self.backendError = "Invalid expiresAt: challenge already expired"
                        print("[FRONTEND][CHALLENGE][INVALID] verifyRunID=\(verifyRunID)")
                        print("[FRONTEND][CHALLENGE][INVALID] reason=expiresAt in the past: \(challengeResp.expiresAt)")
                        return
                    }
                } else {
                    // If not ISO8601, treat as string and log warning but don't block
                    print("[FRONTEND][CHALLENGE][WARNING] verifyRunID=\(verifyRunID) expiresAt not ISO8601 format: \(challengeResp.expiresAt)")
                }
                
                // STEP 6: Log challenge_id for state integrity
                print("[FRONTEND][STATE] verifyRunID=\(verifyRunID)")
                print("[FRONTEND][STATE] challenge_id=\(challengeResp.challengeID)")
                
                self.pendingExpiresAt = challengeResp.expiresAt
                self.lastExpiresAt = challengeResp.expiresAt
                
                // Add flow trace entry for challenge received
                flowTraceEntries.append(FlowTraceEntry(
                    step: "Challenge Received",
                    timestamp: Date(),
                    flowID: flowID,
                    status: "completed",
                    details: "challenge_id: \(challengeResp.challengeID), expiresAt: \(challengeResp.expiresAt)"
                ))
                
                // Step 2: Build canonical clientData JSON
                let bundleID = Bundle.main.bundleIdentifier ?? ""
                let timestamp = ISO8601DateFormatter().string(from: Date())
                
                let payload = ClientDataPayload(
                    challenge_b64: challengeResp.challengeB64,
                    challenge_id: challengeResp.challengeID,
                    flow_id: flowID,
                    key_id_b64: keyID,
                    bundle_id: bundleID,
                    timestamp_iso8601: timestamp
                )
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                guard let clientDataBytes = try? encoder.encode(payload) else {
                    self.backendError = "Failed to encode clientData JSON"
                    print("[ContentView] ERROR: Failed to encode ClientDataPayload")
                    return
                }
                
                // Step 3: Compute clientDataHash = SHA256(clientDataBytes)
                let clientDataHash = Data(SHA256.hash(data: clientDataBytes))
                
                // Log FRONTEND_CLIENTDATA_CANONICAL
                let clientDataB64 = clientDataBytes.base64EncodedString()
                let clientDataB64Prefix = String(clientDataB64.prefix(50))
                let clientDataHashHex = CryptoEvidence.rawHex(clientDataHash)
                let clientDataSha256 = CryptoEvidence.sha256Hex(clientDataBytes)
                
                print("[ContentView] ========================================")
                print("[ContentView] FRONTEND_CLIENTDATA_CANONICAL verifyRunID=\(verifyRunID)")
                print("[ContentView] ========================================")
                print("[ContentView] clientDataBytes_length=\(clientDataBytes.count)")
                print("[ContentView] clientDataBytes_sha256=\(clientDataSha256)")
                print("[ContentView] clientDataBytes_base64_prefix=\(clientDataB64Prefix)...")
                print("[ContentView] clientDataHash_hex=\(clientDataHashHex)")
                print("[ContentView] challenge_id=\(challengeResp.challengeID)")
                print("[ContentView] ========================================")
                
                // STEP 7: Final Assertion Preflight Log
                print("[FRONTEND][ASSERTION][PREFLIGHT] verifyRunID=\(verifyRunID)")
                print("[FRONTEND][ASSERTION][PREFLIGHT] challenge_id=\(challengeResp.challengeID)")
                print("[FRONTEND][ASSERTION][PREFLIGHT] clientDataBytes_sha256=\(clientDataSha256)")
                print("[FRONTEND][ASSERTION][PREFLIGHT] clientDataHash_hex=\(clientDataHashHex)")
                print("[FRONTEND][ASSERTION][PREFLIGHT] keyID_sha256=\(keyID_sha256_hex)")
                
                // Step 4: Generate assertion
                self.generateAndStoreAssertion(
                    keyID: keyID,
                    clientDataBytes: clientDataBytes,
                    clientDataHash: clientDataHash,
                    challenge_id: challengeResp.challengeID,
                    verifyRunID: verifyRunID
                )
            }
        }.resume()
    }
    
    /// Generate assertion with frontend-computed clientDataHash from canonical clientData JSON
    /// IMPORTANT (correctness): Frontend builds clientData JSON (sorted keys), computes SHA256(clientDataBytes), passes to generateAssertion
    /// IMPORTANT: One request → one assertion → store it for reuse in verify request.
    /// AssertionTrustModel.opaqueAppleAssertion: Assertion cryptographic validity is determined by
    /// The Secure Enclave and attestation binding, not by local ECDSA verification.
    func generateAndStoreAssertion(keyID: String, clientDataBytes: Data, clientDataHash: Data, challenge_id: String, verifyRunID: String) {
        // State check: clientDataHash expected to be 32 bytes (computed from clientDataBytes)
        guard clientDataHash.count == 32 else {
            isGeneratingAssertion = false
            backendError = "clientDataHash length incorrect: expected 32 bytes, got \(clientDataHash.count)"
            print("[ContentView] ERROR: generateAssertion rejected – clientDataHash length \(clientDataHash.count)")
            return
        }
        
        // State consistency check: Verify keyID matches registered keyID (for UI consistency, not security)
        // This prevents UI confusion, not a security decision
        guard let registeredKeyID = registeredKeyID, registeredKeyID == keyID else {
            isGeneratingAssertion = false
            backendError = "keyID mismatch – cannot generate assertion: state inconsistency"
            print("[ContentView] ERROR: generateAssertion skipped – keyID does not match registered keyID (state consistency check)")
            return
        }
        
        guard let storedKeyID = keyManager.getKeyID(), storedKeyID == keyID else {
            isGeneratingAssertion = false
            backendError = "keyID mismatch with KeyManager"
            print("[ContentView] ERROR: generateAssertion rejected – keyID does not match KeyManager")
            return
        }
        
        isGeneratingAssertion = true
        
        // IMPORTANT: generateAssertion() MUST be called exactly once per request (prevents double-tap, not security enforcement)
        // IMPORTANT (correctness): clientDataHash is computed from canonical clientData JSON (sorted keys)
        print("[ContentView] Generating assertion with FRONTEND-COMPUTED clientDataHash from canonical clientData JSON...")
        print("[ContentView]   clientDataHash length: \(clientDataHash.count) bytes (expected 32)")
        print("[ContentView]   clientDataHash source: SHA256(clientDataBytes) where clientDataBytes = canonical JSON")
        
        // Logging check: Log bundle ID for backend comparison (backend enforces policy)
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        print("[ContentView]   Bundle ID (backend expects): \(bundleID)")
        if bundleID != "DanylchukStudios.AppAttestDecoderTestApp" {
            print("[ContentView]   ⚠ WARNING: Bundle ID mismatch - backend may reject based on policy")
        }
        
        // STEP 1: FREEZE THE INPUTS - Log and freeze before generateAssertion
        assert(clientDataHash.count == 32, "clientDataHash expected to be 32 bytes before generateAssertion")
        let clientDataHash_hex = CryptoEvidence.rawHex(clientDataHash)
        let clientDataHash_sha256 = CryptoEvidence.sha256Hex(clientDataHash)
        print("[ContentView] ========================================")
        print("[ContentView] STEP 1: FROZEN INPUTS verifyRunID=\(verifyRunID) (before generateAssertion)")
        print("[ContentView] ========================================")
        print("[ContentView] keyID=\(keyID)")
        print("[ContentView] flowID=\(currentFlowID ?? "none")")
        print("[ContentView] bundleID=\(bundleID)")
        print("[ContentView] challenge_id=\(challenge_id)")
        print("[ContentView] clientDataBytes.count: \(clientDataBytes.count) bytes")
        print("[ContentView] clientDataHash.count: \(clientDataHash.count) bytes (SHA256 of clientDataBytes)")
        print("[ContentView] clientDataHash.hex: \(clientDataHash_hex)")
        print("[ContentView] clientDataHash.sha256: \(clientDataHash_sha256)")
        print("[ContentView] ========================================")
        
        service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertionObject, error in
            DispatchQueue.main.async {
                self.isGeneratingAssertion = false
                if let error {
                    self.backendError = "Failed to generate assertion: \(error.localizedDescription)"
                    return
                }
                guard let assertionObject else {
                    self.backendError = "Assertion generation returned nil"
                    return
                }
                self.forensicDumpAssertion(
                    keyID: keyID,
                    assertionObject: assertionObject,
                    clientDataBytes: clientDataBytes,
                    clientDataHash: clientDataHash,
                    challenge_id: challenge_id,
                    verifyRunID: verifyRunID,
                    flowID: self.currentFlowID
                )
                #if DEBUG
                self.dumpSignedBytes(assertionObject: assertionObject, clientDataHash: clientDataHash, verifyRunID: verifyRunID)
                #endif
                self.logVerificationFingerprints(keyID: keyID, assertionObject: assertionObject, clientDataHash: clientDataHash, verifyRunID: verifyRunID)
                self.pendingAssertionB64 = assertionObject.base64EncodedString()
                print("[ContentView] Assertion generated and stored verifyRunID=\(verifyRunID) | assertionObject \(assertionObject.count) bytes | expiresAt: \(self.pendingExpiresAt ?? "N/A") | Tap 'Send to Backend for Verification' to send")
            }
        }
    }
    
    /// FORENSIC (dev-only): Decode CBOR only to extract authenticatorData (raw) and signature (raw DER). signedBytes = authenticatorData || clientDataHash.
    /// Store CryptoEvidence in EvidenceStore. Log FRONTEND_ASSERTION_CANONICAL. OBSERVATIONAL — NOT VERIFIED; no on-device ECDSA verification.
    func forensicDumpAssertion(keyID: String, assertionObject: Data, clientDataBytes: Data, clientDataHash: Data, challenge_id: String, verifyRunID: String, flowID: String?) {
        let decoder = AppAttestDecoder(teamID: nil)
        let authenticatorData: Data
        let signature: Data
        do {
            let pair = try decoder.decodeAssertionObject(assertionObject)
            authenticatorData = pair.authenticatorData
            signature = pair.signatureDER
        } catch {
            print("[ContentView] ERROR: FORENSIC: decodeAssertionObject failed: \(error)")
            return
        }
        var signedBytes = authenticatorData
        signedBytes.append(clientDataHash)
        assert(signedBytes.count == authenticatorData.count + 32, "signedBytes must equal authenticatorData.count + 32")

        let keyID_sha256 = CryptoEvidence.sha256Hex(Data(base64Encoded: keyID) ?? Data())
        let nonce = Data(SHA256.hash(data: signedBytes))
        
        let evidence = CryptoEvidence(
            verifyRunID: verifyRunID,
            flowID: flowID,
            keyID_sha256: keyID_sha256,
            challenge_id: challenge_id,
            clientDataBytes: clientDataBytes,
            authenticatorData: authenticatorData,
            clientDataHash: clientDataHash,
            signedBytes: signedBytes,
            signatureDER: signature,
            publicKeyX963: storedPublicKeyX963,
            assertionObject_sha256: CryptoEvidence.sha256Hex(assertionObject),
            assertionObject_length: assertionObject.count
        )
        EvidenceStore.shared.store(evidence)
        
        // Log FRONTEND_ASSERTION_CANONICAL
        let authenticatorDataHex = CryptoEvidence.rawHex(authenticatorData)
        let authenticatorDataSha256 = CryptoEvidence.sha256Hex(authenticatorData)
        let signatureHex = CryptoEvidence.rawHex(signature)
        let signatureSha256 = CryptoEvidence.sha256Hex(signature)
        let signedBytesSha256 = CryptoEvidence.sha256Hex(signedBytes)
        let nonceHex = CryptoEvidence.rawHex(nonce)
        
        print("[ContentView] ========================================")
        print("[ContentView] FRONTEND_ASSERTION_CANONICAL verifyRunID=\(verifyRunID)")
        print("[ContentView] ========================================")
        print("[ContentView] authenticatorData_hex=\(authenticatorDataHex)")
        print("[ContentView] authenticatorData_sha256=\(authenticatorDataSha256)")
        print("[ContentView] signature_der_hex=\(signatureHex)")
        print("[ContentView] signature_der_sha256=\(signatureSha256)")
        print("[ContentView] signedBytes_sha256=\(signedBytesSha256)")
        print("[ContentView] nonce_hex=\(nonceHex)")
        print("[ContentView] ========================================")
        
        print("FRONTEND_CANONICAL \(evidence.canonicalJSONLine())")
    }
    
    #if DEBUG
    /// DEBUG: Signed Bytes Debug Dump. Uses AppAttestDecoder (same as inspection). signedBytes = authenticatorData || clientDataHash.
    func dumpSignedBytes(assertionObject: Data, clientDataHash: Data, verifyRunID: String) {
        let decoder = AppAttestDecoder(teamID: nil)
        let authenticatorData: Data
        do {
            let pair = try decoder.decodeAssertionObject(assertionObject)
            authenticatorData = pair.authenticatorData
        } catch {
            print("[ContentView] ERROR: DEBUG: decodeAssertionObject failed for signed bytes dump: \(error)")
            return
        }
        var signedBytes = authenticatorData
        signedBytes.append(clientDataHash)
        
        // Convert to hex for display (hex strings concatenated for display only - NOT used for signing)
        let authenticatorData_hex = authenticatorData.map { String(format: "%02x", $0) }.joined()
        let clientDataHash_hex = clientDataHash.map { String(format: "%02x", $0) }.joined()
        let signedBytes_hex = signedBytes.map { String(format: "%02x", $0) }.joined()
        
        // Compute SHA256s
        let authenticatorData_sha256 = sha256Hex(authenticatorData)
        let clientDataHash_sha256 = sha256Hex(clientDataHash)
        let signedBytes_sha256 = sha256Hex(signedBytes)
        
        // OBSERVATIONAL — NOT VERIFIED. Log only; no local signature verification.
        print("[ContentView] ========================================")
        print("[ContentView] DEBUG: SIGNED BYTES DUMP (iOS) verifyRunID=\(verifyRunID)")
        print("[ContentView] OBSERVATIONAL — NOT VERIFIED. AssertionTrustModel.opaqueAppleAssertion.")
        print("[ContentView] ========================================")
        print("[ContentView] Backend computes signedBytes from RAW BYTES, not hex/base64 strings")
        print("[ContentView] ⚠ signedBytes = authenticatorData (raw bytes) + clientDataHash (32 raw bytes)")
        print("[ContentView] ========================================")
        print("[ContentView] authenticatorData_length: \(authenticatorData.count)")
        print("[ContentView] authenticatorData_hex: \(authenticatorData_hex)")
        print("[ContentView] authenticatorData_sha256: \(authenticatorData_sha256)")
        print("[ContentView] ========================================")
        print("[ContentView] clientDataHash_length: \(clientDataHash.count)")
        print("[ContentView] clientDataHash_hex: \(clientDataHash_hex)")
        print("[ContentView] clientDataHash_sha256: \(clientDataHash_sha256)")
        print("[ContentView] ========================================")
        print("[ContentView] signedBytes_length: \(signedBytes.count) (expected authenticatorData_length + 32)")
        print("[ContentView] signedBytes_hex: \(signedBytes_hex)")
        print("[ContentView] signedBytes_sha256: \(signedBytes_sha256)")
        print("[ContentView] ========================================")
        print("[ContentView] Backend expects:")
        print("[ContentView]   - authenticatorData_sha256: \(authenticatorData_sha256)")
        print("[ContentView]   - clientDataHash_hex: \(clientDataHash_hex)")
        print("[ContentView]   - signedBytes_sha256: \(signedBytes_sha256)")
        print("[ContentView] ========================================")
    }
    #endif
    
    /// Log assertion fingerprints for backend comparison. Backend performs all verification.
    /// IMPORTANT (correctness): clientDataHash is backend-provided - frontend NEVER computes it.
    func logVerificationFingerprints(keyID: String, assertionObject: Data, clientDataHash: Data, verifyRunID: String) {
        // State check: clientDataHash expected to be 32 bytes (backend-provided)
        guard clientDataHash.count == 32 else {
            print("[ContentView] ERROR: logVerificationFingerprints – clientDataHash length \(clientDataHash.count), expected 32")
            return
        }
        
        // Fingerprint 1: keyID_sha256 (hash of raw keyID bytes, NOT string)
        let keyIDBytes = Data(base64Encoded: keyID) ?? Data()
        let keyID_sha256 = sha256Hex(keyIDBytes)
        let keyID_sha256_prefix = String(keyID_sha256.prefix(16)) // First 8 bytes hex
        
        // Fingerprint 2: clientDataHash_hex (32 bytes) - BACKEND-PROVIDED, NOT computed
        // IMPORTANT (correctness): This is the exact hash returned by backend - frontend NEVER computes it
        let clientDataHash_hex = clientDataHash.map { String(format: "%02x", $0) }.joined()
        
        // Fingerprint 3: clientDataHash_sha256 - hash of the backend-provided hash (for logging only)
        // NOTE: This is NOT used for signing - only for logging/debugging
        let clientDataHash_sha256 = sha256Hex(clientDataHash)
        
        // Fingerprint 4 & 5: decode via AppAttestDecoder; signedBytes = authenticatorData || clientDataHash
        var authenticatorData_sha256 = "N/A"
        var authenticatorData_length = 0
        var signedBytes_sha256 = "N/A"
        var signedBytes_length = 0
        do {
            let pair = try AppAttestDecoder(teamID: nil).decodeAssertionObject(assertionObject)
            authenticatorData_length = pair.authenticatorData.count
            authenticatorData_sha256 = sha256Hex(pair.authenticatorData)
            var signedBytes = pair.authenticatorData
            signedBytes.append(clientDataHash)
            signedBytes_length = signedBytes.count
            signedBytes_sha256 = sha256Hex(signedBytes)
        } catch {
            print("[ContentView] WARNING: decodeAssertionObject failed for fingerprints: \(error)")
        }
        
        // Fingerprint 6: assertionObject_sha256
        let assertionObject_sha256 = sha256Hex(assertionObject)
        let assertionObject_sha256_prefix = String(assertionObject_sha256.prefix(16)) // First 8 bytes hex
        
        // Store prefixes for UI display (already on main thread from generateAssertion callback)
        lastKeyID_sha256_prefix = keyID_sha256_prefix
        lastAssertionObject_sha256_prefix = assertionObject_sha256_prefix
        
        // OBSERVATIONAL — NOT VERIFIED. No local signature verification. Backend performs verification.
        print("[ContentView] ========================================")
        print("[ContentView] FRONTEND VERIFICATION FINGERPRINTS verifyRunID=\(verifyRunID)")
        print("[ContentView] OBSERVATIONAL — NOT VERIFIED. AssertionTrustModel.opaqueAppleAssertion. (AFTER generation, BEFORE send)")
        print("[ContentView] ========================================")
        print("[ContentView]   keyID_sha256: \(keyID_sha256)")
        print("[ContentView]   clientDataHash_hex: \(clientDataHash_hex) (BACKEND-PROVIDED, NOT computed)")
        print("[ContentView]   clientDataHash_sha256: \(clientDataHash_sha256) (hash of backend-provided hash, for logging only)")
        print("[ContentView]   clientDataHash_length: \(clientDataHash.count) bytes (expected 32)")
        print("[ContentView]   clientDataHash_source: BACKEND ONLY - frontend NEVER computes this")
        print("[ContentView]   assertionObject_sha256: \(assertionObject_sha256)")
        print("[ContentView]   assertionObject_length: \(assertionObject.count)")
        print("[ContentView]   authenticatorData_sha256: \(authenticatorData_sha256)")
        print("[ContentView]   authenticatorData_length: \(authenticatorData_length)")
        print("[ContentView]   signedBytes_sha256: \(signedBytes_sha256)")
        print("[ContentView]   signedBytes_length: \(signedBytes_length)")
        print("[ContentView] ========================================")
        print("[ContentView] Backend logs these fingerprints for comparison")
        print("[ContentView] WARNING: If any fingerprint differs, byte-for-byte integrity is broken")
        
        // Check assertion CBOR format (for logging, backend performs actual validation)
        if let firstByte = assertionObject.first {
            if firstByte == 0xa2 {
                print("[ContentView] Assertion CBOR format: 0xa2 (map) - correct")
            } else {
                print("[ContentView] WARNING: Assertion CBOR does not start with 0xa2 (map)")
                print("[ContentView]   First byte: 0x\(String(format: "%02x", firstByte))")
            }
        }
    }
    
    /// Send assertion data to backend endpoint
    /// IMPORTANT: Frontend sends clientData_base64 (canonical JSON) and challenge_id. Backend recomputes SHA256(clientData) and verifies signature.
    /// POST /app-attest/verify. Sends keyID, flowID, verifyRunID, challenge_id, clientData_base64, assertionObject (base64).
    /// Frontend displays backend responses without interpretation. Backend performs all cryptographic verification and policy enforcement.
    /// Frontend does NOT verify, guarantee, or make trust decisions. Frontend does not infer validity from response status.
    /// - Parameter verifyRunID: Optional; if nil, uses currentVerifyRunID. Enables grep of one ID across TRANSPORT→RESULT.
    func sendAssertionToBackend(keyID: String, assertionObject: Data, verifyRunID: String? = nil) {
        let runID = verifyRunID ?? currentVerifyRunID ?? "unknown"
        verifyFailureFirstDifferingByteIndex = nil
        verifyFailureECDSA = false

        if let ev = EvidenceStore.shared.get(runID) {
            let got = CryptoEvidence.sha256Hex(assertionObject)
            if got != ev.assertionObject_sha256 {
                isSendingToBackend = false
                backendError = "State inconsistency: assertionObject does not match inspected one (sha256 mismatch). Cannot proceed to verify request."
                print("[ContentView] verifyRunID=\(runID) | GUARD FAILED: sent sha256=\(got) vs inspected=\(ev.assertionObject_sha256)")
                return
            }
        }
        
        // State check: flowID expected to exist - no silent fallbacks
        guard let flowID = currentFlowID else {
            isSendingToBackend = false
            backendError = "State error: flowID is missing. Registration needs to succeed and return flowID first."
            print("[ContentView] ERROR: ERROR: VERIFY request attempted without flowID")
                    print("[ContentView] ERROR: flowID expected from backend in REGISTER response")
            return
        }
        
        guard let url = URL(string: "\(backendURL)/app-attest/verify") else {
            isSendingToBackend = false
            backendError = "Invalid backend URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(backendAssertionMode, forHTTPHeaderField: "X-AppAttest-Mode")

        // IMPORTANT: State consistency check - keyID matches the registered keyID (for UI consistency, not security)
        guard let registeredKeyID = registeredKeyID, registeredKeyID == keyID else {
            isSendingToBackend = false
            backendError = "KeyID mismatch! The key used for verify request does not match the registered key. Generate new key and register again."
            print("[ContentView] ERROR: ERROR: keyID mismatch in /verify request")
            if let registeredKeyID = registeredKeyID {
                print("[ContentView]   Registered keyID: \(registeredKeyID)")
                if let regKeyIDData = Data(base64Encoded: registeredKeyID) {
                    print("[ContentView]   Registered keyID_sha256_hex: \(sha256Hex(regKeyIDData))")
                }
            }
            print("[ContentView]   Verify keyID: \(keyID)")
            if let verifyKeyIDData = Data(base64Encoded: keyID) {
                print("[ContentView]   Verify keyID_sha256_hex: \(sha256Hex(verifyKeyIDData))")
            }
            return
        }
        
        // IMPORTANT (correctness): Use raw assertionObject Data directly - no parsing, no inspection, no transformation
        // This must be the exact bytes returned by DCAppAttestService.generateAssertion
        // Apple returns a CBOR map (0xa2), NOT a COSE_Sign1 (0x84 array)
        // Backend recomputes clientDataHash from clientData_base64
        let assertionB64 = assertionObject.base64EncodedString()
        
        guard let ev = EvidenceStore.shared.get(runID) else {
            isSendingToBackend = false
            backendError = "Missing assertion evidence. Run 'Assert Key' first."
            return
        }
        
        let clientDataB64 = CryptoEvidence.base64Std(ev.clientDataBytes)
        
        var requestBody: [String: String] = [
            "keyID": keyID,
            "flowID": flowID,
            "verifyRunID": runID,
            "challenge_id": ev.challenge_id,
            "clientData_base64": clientDataB64,
            "assertionObject_base64": assertionB64
        ]
        
        // TRANSPORT / KEY_IDENTITY: log verifyRunID for full-flow grep
        print("[ContentView] ========================================")
        print("[ContentView] VERIFY verifyRunID=\(runID) | keyID and flowID identity")
        print("[ContentView] ========================================")
        print("[ContentView] VERIFY verifyRunID=\(runID) | keyID: \(keyID)")
        print("[ContentView] VERIFY verifyRunID=\(runID) | flowID: \(flowID) (from REGISTER response)")
        print("[ContentView] VERIFY verifyRunID=\(runID) | challenge_id: \(ev.challenge_id)")
        if let keyIDData = Data(base64Encoded: keyID) {
            let keyID_sha256_hex = sha256Hex(keyIDData)
            print("[ContentView] VERIFY verifyRunID=\(runID) | keyID_sha256_hex: \(keyID_sha256_hex)")
        }
        print("[ContentView] VERIFY verifyRunID=\(runID) | Sending assertion: \(assertionObject.count) bytes, base64 \(assertionB64.count) chars | clientData_base64: \(clientDataB64.count) chars")
        print("[ContentView] ========================================")
        
        // Add flow trace entry for assertion submission
        flowTraceEntries.append(FlowTraceEntry(
            step: "Assertion Submission",
            timestamp: Date(),
            flowID: flowID,
            status: "sent",
            details: "verifyRunID: \(runID), assertionObject: \(assertionObject.count) bytes"
        ))
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            isSendingToBackend = false
            backendError = "Failed to encode request"
            return
        }
        
        request.httpBody = jsonData
        
        print("[ContentView] VERIFY verifyRunID=\(runID) | POST \(url.absoluteString) | body \(jsonData.count) bytes | assertion byte-for-byte")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSendingToBackend = false
                
                if let error {
                    self.backendError = "Network error: \(error.localizedDescription)"
                    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY failed (network): \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.backendError = "Invalid response"
                    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY failed (invalid response, no HTTPURLResponse)")
                    return
                }
                
                // LOUD LOGGING: Always log HTTP status (RESULT)
                print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY response status: \(httpResponse.statusCode)")
                
                // Check HTTP status code
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.backendError = "HTTP error: \(httpResponse.statusCode)"
                    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY failed HTTP \(httpResponse.statusCode)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("[ContentView] RESULT verifyRunID=\(runID) | response body: \(body)")
                    }
                    return
                }
                
                guard let data = data else {
                    self.backendError = "No response data"
                    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY failed (no data)")
                    return
                }
                
                // LOUD LOGGING: Always log raw response body
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    self.backendError = "Invalid response encoding"
                    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY failed (invalid encoding)")
                    return
                }
                
                print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY response body: \(jsonString)")
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let status = json["status"] as? String { print("[ContentView] RESULT verifyRunID=\(runID) | status: \(status)") }
                    if let reason = json["reason"] as? String { print("[ContentView] RESULT verifyRunID=\(runID) | reason: \(reason)") }
                    if let f = BackendForensics.from(json) { self.lastBackendForensics = (runID, f) }
                    let reason = json["reason"] as? String ?? ""
                    if reason == "SIGNED_BYTES_MISMATCH" {
                        if let i = json["firstDifferingByteIndex"] as? Int { self.verifyFailureFirstDifferingByteIndex = i }
                        else if let d = json["firstDifferingByteIndex"] as? Double { self.verifyFailureFirstDifferingByteIndex = Int(d) }
                    } else if reason == "ECDSA_VERIFY_FAILED" {
                        self.verifyFailureECDSA = true
                    }
                }
                self.backendResponse = jsonString

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    if status == "verified" || status == "accepted" {
                        self.verifyFailureFirstDifferingByteIndex = nil
                        self.verifyFailureECDSA = false
                        self.backendResponse = "Backend response (status: verified): \(jsonString)"
                        print("[ContentView] RESULT verifyRunID=\(runID) | Backend returned status: verified")
                        self.pendingAssertionB64 = nil
                        self.pendingExpiresAt = nil
                        print("[ContentView] RESULT verifyRunID=\(runID) | Cleared pending assertion")
                        
                        // Add flow trace entry for backend response
                        flowTraceEntries.append(FlowTraceEntry(
                            step: "Backend Response",
                            timestamp: Date(),
                            flowID: flowID,
                            status: "verified",
                            details: "Backend returned status: verified"
                        ))
                    } else if status == "rejected" {
                        self.backendResponse = "Backend response (status: rejected): \(jsonString)"
                        print("[ContentView] RESULT verifyRunID=\(runID) | Backend returned status: rejected")
                        
                        // Add flow trace entry for backend response
                        flowTraceEntries.append(FlowTraceEntry(
                            step: "Backend Response",
                            timestamp: Date(),
                            flowID: flowID,
                            status: "rejected",
                            details: "Backend returned status: rejected"
                        ))
                    }
                }
            }
        }.resume()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Page indicator / Mode selector
            Picker("Mode", selection: $mode) {
                Text("Live").tag(InspectorMode.live)
                Text("Manual").tag(InspectorMode.manual)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Content views with swipe gesture
            ZStack {
                if mode == .live {
                    LiveInspectorView(
                        service: service,
                        contextStore: contextStore,
                        isSupported: $isSupported,
                        keyID: $keyID,
                        keyIDError: $keyIDError,
                        attestationBlobB64: $attestationBlobB64,
                        attestationError: $attestationError,
                        showShareSheet: $showShareSheet,
                        backendURL: $backendURL,
                        backendResponse: $backendResponse,
                        backendError: $backendError,
                        isSendingToBackend: $isSendingToBackend,
                        isRegistering: $isRegistering,
                        isRequestingChallenge: $isRequestingChallenge,
                        registrationSucceeded: $registrationSucceeded,
                        registeredKeyID: $registeredKeyID,
                        currentFlowID: $currentFlowID,
                        storedPublicKeyX963: $storedPublicKeyX963,
                        currentVerifyRunID: $currentVerifyRunID,
                        backendAssertionMode: $backendAssertionMode,
                        verifyFailureFirstDifferingByteIndex: verifyFailureFirstDifferingByteIndex,
                        verifyFailureECDSA: verifyFailureECDSA,
                        lastBackendForensics: lastBackendForensics,
                        showDiffView: $showDiffView,
                        lastExpiresAt: $lastExpiresAt,
                        lastKeyID_sha256_prefix: $lastKeyID_sha256_prefix,
                        lastAssertionObject_sha256_prefix: $lastAssertionObject_sha256_prefix,
                        pendingAssertionB64: $pendingAssertionB64,
                        pendingExpiresAt: $pendingExpiresAt,
                        isGeneratingAssertion: $isGeneratingAssertion,
                        onCaptureAttestationContext: self.captureAttestationContext,
                        onRequestChallengeAndGenerateAssertion: self.requestChallengeAndGenerateAssertion,
                        onCopyAssertionPackage: { self.copyAssertionPackage() },
                        canCopyAssertionPackage: EvidenceStore.shared.getLast() != nil && pendingAssertionB64 != nil,
                        onSendAttestationToBackend: self.sendAttestationToBackend,
                        onSendAssertionToBackend: { k, d in self.sendAssertionToBackend(keyID: k, assertionObject: d, verifyRunID: self.currentVerifyRunID) },
                        lastRegisterTarget: lastRegisterTarget,
                        pingResult: pingResult,
                        isPinging: isPinging,
                        onPingBackend: { self.pingBackend() },
                        evidencePublicKeyX963: $evidencePublicKeyX963,
                        onAttestationSucceeded: { self.onAttestationSucceededForEvidence($0, keyID: $1) },
                        onCopyEvidenceBundle: { self.copyEvidenceBundle() },
                        canCopyEvidence: evidencePublicKeyX963 != nil,
                        onCopyOpenSSLPayload: { self.copyOpenSSLPayload() },
                        canCopyOpenSSLPayload: (evidencePublicKeyX963 ?? storedPublicKeyX963 ?? EvidenceStore.shared.getLast()?.publicKeyX963) != nil && EvidenceStore.shared.getLast() != nil
                    )
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                } else {
                    ManualInputInspectorView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        withAnimation(.easeInOut) {
                            if value.translation.width < -80 {
                                mode = .manual
                            } else if value.translation.width > 80 {
                                mode = .live
                            }
                        }
                    }
            )
        }
        .animation(.easeInOut, value: mode)
        .sheet(isPresented: $showDiffView) {
            NavigationStack {
                AssertionDiffView(runID: lastBackendForensics?.runID ?? "", backend: lastBackendForensics?.forensics)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showDiffView = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showFlowTrace) {
            NavigationStack {
                FlowTraceView(entries: $flowTraceEntries)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showFlowTrace = false }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") { flowTraceEntries.removeAll() }
                    }
                }
            }
        }
    }
}

struct LiveInspectorView: View {
    let service: DCAppAttestService
    @ObservedObject var contextStore: AppAttestContextStore
    private let keyManager = AppAttestKeyManager.shared
    @Binding var isSupported: Bool?
    @Binding var keyID: String?
    @Binding var keyIDError: String?
    @Binding var attestationBlobB64: String?
    @Binding var attestationError: String?
    @Binding var showShareSheet: Bool
    @Binding var backendURL: String
    @Binding var backendResponse: String?
    @Binding var backendError: String?
    @Binding var isSendingToBackend: Bool
    @Binding var isRegistering: Bool
    @Binding var isRequestingChallenge: Bool
    @Binding var registrationSucceeded: Bool
    @Binding var registeredKeyID: String?
    @Binding var currentFlowID: String?
    @Binding var storedPublicKeyX963: Data?
    @Binding var currentVerifyRunID: String?
    @Binding var backendAssertionMode: String
    var verifyFailureFirstDifferingByteIndex: Int?
    var verifyFailureECDSA: Bool
    var lastBackendForensics: (runID: String, forensics: BackendForensics)?
    @Binding var showDiffView: Bool
    @Binding var lastExpiresAt: String?
    @Binding var lastKeyID_sha256_prefix: String?
    @Binding var lastAssertionObject_sha256_prefix: String?
    @Binding var pendingAssertionB64: String?
    @Binding var pendingExpiresAt: String?
    @Binding var isGeneratingAssertion: Bool
    
    // Function closures passed from ContentView
    let onCaptureAttestationContext: (String, Data) -> Void
    let onRequestChallengeAndGenerateAssertion: (String) -> Void
    let onCopyAssertionPackage: () -> Void
    var canCopyAssertionPackage: Bool
    let onSendAttestationToBackend: (String, String) -> Void
    let onSendAssertionToBackend: (String, Data) -> Void
    var lastRegisterTarget: String?
    var pingResult: String?
    var isPinging: Bool
    let onPingBackend: () -> Void
    @Binding var evidencePublicKeyX963: Data?
    let onAttestationSucceeded: (Data, String) -> Void
    let onCopyEvidenceBundle: () -> Void
    var canCopyEvidence: Bool
    let onCopyOpenSSLPayload: () -> Void
    var canCopyOpenSSLPayload: Bool

    /// Consistent SHA256 hex calculation - always hash Data, never strings
    private func sha256Hex(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }
    
    /// Decode base64 with tolerance for base64url and missing padding
    /// Handles: base64url (- and _), missing padding (=), whitespace
    private func decodeBase64Relaxed(_ s: String) -> Data? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Convert base64url to standard base64
        t = t.replacingOccurrences(of: "-", with: "+")
             .replacingOccurrences(of: "_", with: "/")
        
        // Pad to multiple of 4
        let rem = t.count % 4
        if rem != 0 {
            t += String(repeating: "=", count: 4 - rem)
        }
        
        return Data(base64Encoded: t)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Button("Is Supported?") {
                        isSupported = service.isSupported
                    }

                if let isSupported {
                    Text(isSupported ? "Supported" : "Not Supported")
                } else {
                    Text("Not checked")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Button("Generate Key") {
                        keyIDError = nil
                        keyID = nil
                        registrationSucceeded = false
                        registeredKeyID = nil
                        currentFlowID = nil
                        storedPublicKeyX963 = nil
                        currentVerifyRunID = nil
                        evidencePublicKeyX963 = nil
                        EvidenceStore.shared.clear()
                        backendResponse = nil
                        backendError = nil
                        pendingAssertionB64 = nil
                        pendingExpiresAt = nil

                        guard service.isSupported else {
                            keyIDError = "App Attest not supported on this device / configuration."
                            return
                        }

                        service.generateKey { keyID, error in
                            DispatchQueue.main.async {
                                if let keyID {
                                    // Clear ClientDataContext when generating new key
                                    // NOTE: ClientDataContext is only used for attestation, not verification
                                    // Verification requests clientDataHash from backend (frontend NEVER computes it)
                                    if let oldKeyID = self.keyID {
                                        ClientDataContextManager.shared.clearContext(for: oldKeyID)
                                    }
                                    ClientDataContextManager.shared.clearContext(for: keyID)
                                    
                                    // Clear pending assertion and registration state when generating new key
                                    self.pendingAssertionB64 = nil
                                    self.pendingExpiresAt = nil
                                    self.registrationSucceeded = false
                                    self.registeredKeyID = nil // Clear registered keyID - new key needs to be registered
                                    self.currentFlowID = nil // Clear flowID - new key needs to be registered
                                    self.storedPublicKeyX963 = nil
                                    self.currentVerifyRunID = nil
                                    EvidenceStore.shared.clear()
                                    // Store in both @State (for UI) and KeyManager (for persistence)
                                    self.keyID = keyID
                                    self.keyManager.setKeyID(keyID) // IMPORTANT: Store in singleton for key continuity (state consistency, not security)
                                    self.keyIDError = nil
                                    print("[ContentView] GENERATE KEY - keyID: \(keyID)")
                                    if let keyIDData = Data(base64Encoded: keyID) {
                                        let keyIDHex = keyIDData.map { String(format: "%02x", $0) }.joined()
                                        print("[ContentView] GENERATE KEY - keyID (hex): \(keyIDHex)")
                                        print("[ContentView] This keyID is used for both attestation AND assertion")
                                    }
                                } else {
                                    self.keyID = nil
                                    self.keyIDError = error?.localizedDescription ?? String(describing: error)
                                    print("GenerateKey error: \(self.keyIDError ?? "unknown")")
                                }
                            }
                        }
                    }

                    Button {
                        if let keyID {
                            UIPasteboard.general.string = keyID
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(keyID == nil)
                }

                if let keyIDError {
                    Text(keyIDError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if let keyID {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Key ID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            // Copy public key button (if available)
                            if let context = contextStore.getContext(keyID: keyID),
                               !context.publicKey.isEmpty {
                                Button {
                                    UIPasteboard.general.string = context.publicKey.base64EncodedString()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "key")
                                        Text("Copy Public Key")
                                    }
                                    .font(.caption2)
                                }
                            }
                        }

                        TextEditor(text: .constant(keyID))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(height: 48)
                            .textSelection(.enabled)
                            .scrollDisabled(true)
                            .contextMenu {
                                Button("Copy") {
                                    UIPasteboard.general.string = keyID
                                }
                            }
                    }
                } else {
                    Text("Key not generated")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Button("Attest Key") {
                        attestationError = nil
                        attestationBlobB64 = nil
                        evidencePublicKeyX963 = nil

                        guard service.isSupported else {
                            attestationError = "App Attest not supported on this device / configuration."
                            return
                        }

                        guard let keyID else {
                            attestationError = "Missing keyID. Generate a key first."
                            return
                        }
                        
                        // IMPORTANT: State consistency check - verify we're using the same keyID from KeyManager (for UI consistency, not security)
                        guard let storedKeyID = keyManager.getKeyID(), storedKeyID == keyID else {
                            attestationError = "KeyID mismatch! Key may have been regenerated. Generate key again."
                            print("[ContentView] ERROR: ERROR: keyID from state (\(keyID)) does not match KeyManager (\(keyManager.getKeyID() ?? "nil"))")
                            return
                        }

                        // Log keyID to verify it matches the one used for assertion
                        print("[ContentView] ATTEST - keyID: \(keyID)")
                        if let keyIDData = Data(base64Encoded: keyID) {
                            let keyIDHex = keyIDData.map { String(format: "%02x", $0) }.joined()
                            let keyIDFingerprint = sha256Hex(keyIDData)
                            print("[ContentView] ATTEST - keyID (hex): \(keyIDHex)")
                            print("[ContentView] ATTEST - keyID SHA256: \(keyIDFingerprint)")
                            print("[ContentView] This keyID matches the one used in VERIFY")
                            
                            // State consistency check: keyID matches KeyManager (for UI consistency, not security)
                            if let storedKeyID = keyManager.getKeyID() {
                                if let storedKeyIDData = Data(base64Encoded: storedKeyID) {
                                    let storedKeyIDFingerprint = sha256Hex(storedKeyIDData)
                                    if keyIDFingerprint == storedKeyIDFingerprint {
                                        print("[ContentView] ATTEST keyID matches KeyManager - key continuity check passed (state consistency)")
                                    } else {
                                        print("[ContentView] ERROR: ERROR: ATTEST keyID does NOT match KeyManager!")
                                        print("[ContentView]   ATTEST keyID SHA256: \(keyIDFingerprint)")
                                        print("[ContentView]   KeyManager keyID SHA256: \(storedKeyIDFingerprint)")
                                    }
                                }
                            }
                        }

                        // NOTE: Attestation requires a clientDataHash, but it's separate from verification flow
                        // For verification, clientDataHash is requested from backend (frontend NEVER computes it)
                        // For attestation, we generate one client-side (Apple API requirement)
                        ClientDataContextManager.shared.clearContext(for: keyID)
                        
                        // Create new ClientDataContext for attestation (not used in verification)
                        let clientDataContext = ClientDataContextManager.shared.getOrCreateContext(for: keyID)
                        let clientDataHash = clientDataContext.clientDataHash
                        
                        // GUARD: clientDataHash expected to be 32 bytes
                        guard clientDataHash.count == 32 else {
                            attestationError = "Invalid clientDataHash length: \(clientDataHash.count) bytes (expected 32)"
                            print("[ContentView] ERROR: clientDataHash length \(clientDataHash.count), expected 32")
                            return
                        }
                        
                        // Log attestation fingerprints
                        print("[ContentView] ATTEST - keyID: \(keyID)")
                        let keyIDBytes = Data(base64Encoded: keyID) ?? Data()
                        let keyID_sha256 = sha256Hex(keyIDBytes)
                        let clientDataHash_hex = clientDataHash.map { String(format: "%02x", $0) }.joined()
                        let clientDataHash_sha256 = sha256Hex(clientDataHash)
                        
                        print("[ContentView] ATTEST - keyID_sha256: \(keyID_sha256)")
                        print("[ContentView] ATTEST - clientDataHash_hex: \(clientDataHash_hex)")
                        print("[ContentView] ATTEST - clientDataHash_sha256: \(clientDataHash_sha256)")

                        service.attestKey(keyID, clientDataHash: clientDataHash) { attestBlob, error in
                            DispatchQueue.main.async {
                                if let error {
                                    self.attestationError = error.localizedDescription
                                    self.attestationBlobB64 = nil
                                    self.evidencePublicKeyX963 = nil
                                    print("AttestKey error: \(error)")
                                } else if let attestBlob {
                                    self.attestationBlobB64 = attestBlob.base64EncodedString()
                                    self.attestationError = nil
                                    print("AttestKey success: \(attestBlob.count) bytes")
                                    onCaptureAttestationContext(keyID, attestBlob)
                                    onAttestationSucceeded(attestBlob, keyID)
                                } else {
                                    self.attestationError = "Attestation failed with no error (unsupported or misconfigured)."
                                    self.attestationBlobB64 = nil
                                    self.evidencePublicKeyX963 = nil
                                    print("AttestKey returned nil blob and nil error")
                                }
                            }
                        }
                    }

                    Button {
                        if let attestationBlobB64 {
                            UIPasteboard.general.string = attestationBlobB64
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(attestationBlobB64 == nil)
                }

                // clientDataHash is internal-only - not exposed in UI per App Attest lifecycle requirements

                if let attestationError {
                    Text(attestationError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if let attestationBlobB64 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Attestation Blob (base64)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: .constant(attestationBlobB64))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(height: 220)
                            .textSelection(.enabled)
                            .scrollDisabled(false)
                            .contextMenu {
                                Button("Copy") {
                                    UIPasteboard.general.string = attestationBlobB64
                                }
                            }
                        
                        // Inspector Button
                        // NOTE: This opens an inspection-only view.
                        // It does NOT perform verification or make trust decisions.
                        NavigationLink {
                            AttestationInspectorView(base64Attestation: attestationBlobB64)
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Inspect Attestation")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("Attestation not generated")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Assert Key button - generates assertion for preview (like Attest Key)
                // This requests clientDataHash from backend, generates assertion, stores it for preview
                HStack {
                    Button("Assert Key") {
                        guard service.isSupported else {
                            backendError = "App Attest not supported on this device / configuration."
                            return
                        }

                        guard let keyID else {
                            backendError = "Missing keyID. Generate a key first."
                            return
                        }
                        
                        guard let storedKeyID = keyManager.getKeyID(), storedKeyID == keyID else {
                            backendError = "KeyID mismatch! Key may have been regenerated. Generate key again."
                            return
                        }
                        
                        guard attestationBlobB64 != nil else {
                            backendError = "Key not attested. Tap 'Attest Key' first."
                            return
                        }
                        
                        // IMPORTANT: Request challenge from backend, build canonical clientData, compute SHA256, generate assertion
                        onRequestChallengeAndGenerateAssertion(keyID)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRequestingChallenge || isGeneratingAssertion || keyID == nil || attestationBlobB64 == nil || !registrationSucceeded)

                    Button {
                        if let assertionB64 = pendingAssertionB64 {
                            UIPasteboard.general.string = assertionB64
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(pendingAssertionB64 == nil)
                }
                
                // Display generated assertion (copyable, like attestation)
                if let assertionB64 = pendingAssertionB64 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assertion Blob (base64)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: .constant(assertionB64))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(height: 220)
                            .textSelection(.enabled)
                            .scrollDisabled(false)
                            .contextMenu {
                                Button("Copy") {
                                    UIPasteboard.general.string = assertionB64
                                }
                            }
                        
                        if let expiresAt = pendingExpiresAt {
                            Text("Expires: \(expiresAt)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Assertion not generated")
                        .foregroundStyle(.secondary)
                }

                Divider()
                
                // Backend Verification Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend Verification")
                        .font(.headline)
                    
                    Text("Flow: Generate Key → Attest Key → Register → Verify")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("Backend URL", text: $backendURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if let t = lastRegisterTarget {
                        Text("Last REGISTER: \(t)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Button("Ping Backend") { onPingBackend() }
                            .disabled(isPinging)
                        if isPinging { ProgressView().scaleEffect(0.7) }
                        if let p = pingResult {
                            Text("Ping: \(p)")
                                .font(.caption2)
                                .foregroundStyle(p.hasPrefix("OK") ? .green : .orange)
                        }
                    }

                    // Phase 1: Register Attestation (one-time per key)
                    // Backend requires keyID, attestationObject, challenge_base64 (from ClientDataContext at attestation).
                    if let attestationBlobB64 = attestationBlobB64,
                       let keyID = keyID {
                        let hasChallenge = (ClientDataContextManager.shared.getContext(for: keyID)?.challenge.isEmpty == false)
                        Button {
                            onSendAttestationToBackend(keyID, attestationBlobB64)
                        } label: {
                            HStack {
                                if isRegistering {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isRegistering ? "Registering..." : registrationSucceeded ? "Registered (flowID received)" : "Register Attestation")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRegistering || isSendingToBackend || isRequestingChallenge || registrationSucceeded || !hasChallenge)
                        .help("Sends keyID, attestationObject, challenge_base64 to backend. Registration completes before sending assertions.")
                        if !hasChallenge {
                            Text("challenge_base64 missing: tap Attest Key first.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Attest key first to proceed with registration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Backend assertion mode: X-AppAttest-Mode header (strict | opaque)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backend Mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $backendAssertionMode) {
                            Text("Strict").tag("strict")
                            Text("Opaque").tag("opaque")
                        }
                        .pickerStyle(.segmented)
                    }

                    // Phase 2: Send Assertion to Backend for Verification - uses stored assertion from "Assert Key" button
                    if registrationSucceeded {
                        Button {
                            guard let keyID else {
                                backendError = "Missing keyID. Generate a key first."
                                return
                            }
                            
                            guard let storedKeyID = keyManager.getKeyID(), storedKeyID == keyID else {
                                backendError = "KeyID mismatch! Key may have been regenerated. Generate key again."
                                return
                            }
                            
                            guard let assertionB64 = pendingAssertionB64 else {
                                backendError = "No assertion available. Tap 'Assert Key' first to generate assertion."
                                return
                            }
                            
                            // Decode stored assertion and send to verify
                            guard let assertionData = Data(base64Encoded: assertionB64) else {
                                backendError = "Failed to decode stored assertion"
                                return
                            }
                            
                            // Send stored assertion to verify (backend uses stored hash)
                            onSendAssertionToBackend(keyID, assertionData)
                        } label: {
                            HStack {
                                if isSendingToBackend {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isSendingToBackend ? "Sending to backend..." : "Send to Backend for Verification")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSendingToBackend || isRegistering || isRequestingChallenge || isGeneratingAssertion || keyID == nil || pendingAssertionB64 == nil)
                        .help("Sends the stored assertion and clientData_base64 to backend. Backend recomputes SHA256(clientData) and verifies signature.")
                        .onChange(of: registrationSucceeded) { oldValue, newValue in
                            // Reset sending state if registration fails
                            if !newValue && (isSendingToBackend || isRequestingChallenge) {
                                isSendingToBackend = false
                                isRequestingChallenge = false
                                backendError = "Registration failed. Cannot send assertion to backend for verification."
                            }
                        }
                        
                        // Diff View (dev-only): compare iOS evidence to backend forensics when backend verification fails
                        Button("Diff View") { showDiffView = true }
                            .disabled(lastBackendForensics == nil)
                            .help("If backend verification fails and backend debug is enabled, open Diff View.")
                        
                        // Flow Trace View
                        Button("Flow Trace") { showFlowTrace = true }
                            .help("View diagnostic flow trace: registration → challenge → assertion submission")

                        Button("Copy Canonical Block") {
                            let s = EvidenceStore.shared.getLast()?.canonicalJSONLine() ?? ""
                            UIPasteboard.general.string = s.isEmpty ? "(no run)" : s
                        }
                        .disabled(EvidenceStore.shared.getLast() == nil)
                        .help("Copy FRONTEND_CANONICAL JSON for the last run to clipboard.")

                        Button("Copy Evidence Bundle") { onCopyEvidenceBundle() }
                            .disabled(!canCopyEvidence)
                            .help("Copy OpenSSL-ready JSON: publicKey (x5c[0] SPKI), authenticatorData, clientDataHash, signedBytes, signature (for backend comparison).")

                        Button("Copy OpenSSL Payload") { onCopyOpenSSLPayload() }
                            .disabled(!canCopyOpenSSLPayload)
                            .help("Copy JSON for backend debug: publicKeyX963_hex, signedBytes_hex, signatureDER_hex. Raw hex, paste into curl.")

                        Button("Copy Assertion Package") { onCopyAssertionPackage() }
                            .disabled(!canCopyAssertionPackage)
                            .help("Copy compact JSON package: verifyRunID, flowID, keyID_b64, challenge_id, clientData_base64, assertionObject_base64, hashes, nonce.")

                        // Show preview info
                        if let expiresAt = pendingExpiresAt {
                            Text("Assertion ready (expires: \(expiresAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Register attestation first to proceed with assertion generation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // IMPORTANT: Prevent double-tap - button is disabled during in-flight request (UI flow control, not security)
                    // This prevents double-tap: generateAssertion() is called exactly once per verification request
                    
                    if let backendResponse {
                        Text(backendResponse)
                            .foregroundStyle(.primary)
                            .font(.footnote)
                            .padding(.vertical, 4)
                    }
                    
                    if let backendError {
                        Text(backendError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.vertical, 4)
                    }

                    if let idx = verifyFailureFirstDifferingByteIndex {
                        Text("SIGNED_BYTES_MISMATCH: first differing byte index: \(idx)")
                            .foregroundStyle(.red)
                            .font(.headline)
                            .padding(.vertical, 4)
                    }
                    if verifyFailureECDSA, let last = EvidenceStore.shared.getLast() {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Backend reported: Inputs identical but ECDSA verification failed (ECDSA_VERIFY_FAILED in strict mode)")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                            Text("authenticatorData.sha256: \(last.authenticatorData_sha256)")
                            Text("clientDataHash.sha256: \(last.clientDataHash_sha256)")
                            Text("signedBytes.sha256: \(last.signedBytes_sha256)")
                            Text("signature.sha256: \(last.signature_sha256)")
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }

                    // UI display state (for debugging)
                    if let expiresAt = lastExpiresAt {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last expiresAt: \(expiresAt)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let keyIDPrefix = lastKeyID_sha256_prefix {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("keyID_sha256 prefix: \(keyIDPrefix)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let assertionPrefix = lastAssertionObject_sha256_prefix {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("assertionObject_sha256 prefix: \(assertionPrefix)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Action Extension Test Button
                HStack {
                    Button("Test Action Extension") {
                        print("[MainApp] Opening share sheet...")
                        showShareSheet = true
                    }
                    
                    Button {
                        // No copy action needed for this button
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(true)
                    .opacity(0.3)
                }
            }
            .padding()
        }
        .navigationTitle("App Attest Test")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["Test App Attest Extension"])
        }
        .onAppear {
            print("[ContentView] View appeared")
        }
    }
}
}

// Helper to present share sheet from SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("[ShareSheet] Creating UIActivityViewController with items: \(activityItems.count)")
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Exclude system activities we don't need (faster loading)
        controller.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo,
            .postToTwitter,
            .postToFacebook,
            .openInIBooks,
            .markupAsPDF
        ]
        
        // Configure for iPad
        if let popover = controller.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootView = windowScene.windows.first?.rootViewController?.view {
                popover.sourceView = rootView
                let screenBounds = windowScene.screen.bounds
                popover.sourceRect = CGRect(x: screenBounds.width / 2, y: screenBounds.height, width: 0, height: 0)
                popover.permittedArrowDirections = .down
            }
        }
        
        print("[ShareSheet] UIActivityViewController created, presenting...")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - ContentView Extension for Backward Compatibility Functions

extension ContentView {
    /// Request clientDataHash from backend, use it once, send only assertion
    /// IMPORTANT (correctness): Frontend NEVER computes clientDataHash - only uses backend-provided hash
    /// Step 1: POST /app-attest/client-data-hash { keyID } -> { clientDataHash: base64, expiresAt: ISO8601 }
    /// Step 2: Generate assertion with backend-issued clientDataHash (exact 32 bytes, byte-for-byte)
    /// Step 3: POST /app-attest/verify { keyID, assertionObject } (NO clientDataHash sent - backend uses stored one)
    /// NOTE: This function is kept for backward compatibility but is now replaced by Generate Assertion + Verify Assertion flow
    func requestClientDataHashAndVerify(keyID: String) {
        // State check: Fail fast if registration didn't succeed
        guard registrationSucceeded else {
            backendError = "Attestation not registered. Tap 'Register Attestation' and wait for success."
            return
        }
        
        // Prevent double-tap / re-entry
        guard !isSendingToBackend && !isRequestingChallenge else {
            print("[ContentView] SKIPPED: Verification request already in progress")
            return
        }
        
        guard service.isSupported else {
            backendError = "App Attest not supported on this device"
            return
        }
        
        // Verify keyID matches
        guard let storedKeyID = keyManager.getKeyID(), storedKeyID == keyID else {
            backendError = "KeyID mismatch! The key used for assertion does not match the one used for attestation."
            return
        }
        
        isRequestingChallenge = true
        backendError = nil
        backendResponse = nil
        
        // Step 1: Request clientDataHash from backend
        guard let url = URL(string: "\(backendURL)/app-attest/client-data-hash") else {
            isRequestingChallenge = false
            backendError = "Invalid backend URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // State check: flowID expected to exist - no silent fallbacks
        guard let flowID = currentFlowID else {
            isRequestingChallenge = false
            backendError = "State error: flowID is missing. Registration needs to succeed and return flowID first."
            print("[ContentView] ERROR: ERROR: CLIENT_DATA_HASH request attempted without flowID")
                    print("[ContentView] ERROR: flowID expected from backend in REGISTER response")
            return
        }
        
        let verifyRunID = UUID().uuidString
        currentVerifyRunID = verifyRunID
        
        // IMPORTANT: Include keyID, flowID, verifyRunID. Backend stores verifyRunID on flow for grep-able chain.
        let requestBody: [String: String] = [
            "keyID": keyID,
            "flowID": flowID,
            "verifyRunID": verifyRunID
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            isRequestingChallenge = false
            backendError = "Failed to encode request"
            return
        }
        
        request.httpBody = jsonData
        
        print("[ContentView] CLIENT_DATA_HASH verifyRunID=\(verifyRunID) | Requesting clientDataHash (single-shot verify, frontend NEVER computes hash)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isRequestingChallenge = false
                
                if let error {
                    self.backendError = "Failed to request clientDataHash: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    self.backendError = "Invalid clientDataHash response from backend"
                    print("[ContentView] ERROR: Failed to get response data")
                    return
                }
                
                // STRICT PARSING: Log full raw response for debugging (CLIENT_DATA_HASH)
                let rawResponseString = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
                print("[ContentView] CLIENT_DATA_HASH verifyRunID=\(verifyRunID) | Raw response: \(rawResponseString)")
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.backendError = "Invalid JSON in clientDataHash response"
                    print("[ContentView] ERROR: Failed to parse JSON. Raw: \(rawResponseString)")
                    return
                }
                
                // STRICT PARSING: Require clientDataHash field
                guard let clientDataHashB64 = json["clientDataHash"] as? String,
                      !clientDataHashB64.isEmpty else {
                    self.backendError = "clientDataHash field missing or empty in response"
                    print("[ContentView] ERROR: clientDataHash missing. Keys: \(json.keys.joined(separator: ", ")). Raw: \(rawResponseString)")
                    return
                }
                
                // STRICT PARSING: Require expiresAt field
                guard let expiresAt = json["expiresAt"] as? String,
                      !expiresAt.isEmpty else {
                    self.backendError = "expiresAt field missing or empty in response"
                    print("[ContentView] ERROR: expiresAt missing. Keys: \(json.keys.joined(separator: ", ")). Raw: \(rawResponseString)")
                    return
                }
                
                // Decode ONCE into Data. No re-encoding, re-hashing, or JSON regeneration after receipt.
                // decodeBase64Relaxed: accepts standard base64 or base64url (normalized). Single decode only.
                guard let clientDataHash = self.decodeBase64Relaxed(clientDataHashB64) else {
                    self.backendError = "Failed to decode clientDataHash (may be base64url or missing padding)"
                    print("[ContentView] ERROR: Failed to decode clientDataHash. String: \(clientDataHashB64). Raw: \(rawResponseString)")
                    return
                }
                // GUARD: clientDataHash expected to be 32 bytes. This exact Data is passed to generateAssertion with no transformations.
                guard clientDataHash.count == 32 else {
                    self.backendError = "Invalid clientDataHash length: \(clientDataHash.count) bytes (expected 32)"
                    print("[ContentView] ERROR: clientDataHash length \(clientDataHash.count), expected 32. Raw: \(rawResponseString)")
                    return
                }
                lastExpiresAt = expiresAt
                self.generateAndSendAssertion(keyID: keyID, clientDataHash: clientDataHash, verifyRunID: verifyRunID)
            }
        }.resume()
    }
    
    /// Generate assertion with server-issued clientDataHash and send to backend.
    /// IMPORTANT (correctness): clientDataHash MUST be provided by backend - frontend NEVER computes it.
    /// AssertionTrustModel.opaqueAppleAssertion: Assertion cryptographic validity is determined by
    /// The Secure Enclave and attestation binding, not by local ECDSA verification.
    func generateAndSendAssertion(keyID: String, clientDataHash: Data, verifyRunID: String) {
        // State check: clientDataHash must be exactly 32 bytes (backend-provided)
        guard clientDataHash.count == 32 else {
            isSendingToBackend = false
            backendError = "clientDataHash length incorrect: expected 32 bytes, got \(clientDataHash.count)"
            print("[ContentView] ERROR: generateAndSendAssertion rejected – clientDataHash length \(clientDataHash.count)")
            return
        }
        
        // State consistency check: Verify keyID matches registered keyID (for UI consistency, not security)
        // This prevents UI confusion, not a security decision
        guard let registeredKeyID = registeredKeyID, registeredKeyID == keyID else {
            isSendingToBackend = false
            backendError = "keyID mismatch – cannot send assertion: state inconsistency"
            print("[ContentView] ERROR: generateAndSendAssertion skipped – keyID does not match registered keyID (state consistency check)")
            return
        }
        
        guard let storedKeyID = keyManager.getKeyID(), storedKeyID == keyID else {
            isSendingToBackend = false
            backendError = "keyID mismatch with KeyManager"
            print("[ContentView] ERROR: generateAndSendAssertion skipped – keyID does not match KeyManager (state consistency check)")
            return
        }
        
        isSendingToBackend = true
        
        // IMPORTANT: generateAssertion() MUST be called exactly once per verification request (prevents double-tap, not security enforcement)
        // IMPORTANT (correctness): The returned assertion Data MUST be sent to the backend byte-for-byte
        // IMPORTANT (correctness): clientDataHash is backend-provided - frontend NEVER computes it
        // No additional generateAssertion() calls may occur for inspection, preview, retry, or logging
        
        print("[ContentView] Generating assertion with BACKEND-PROVIDED clientDataHash (frontend NEVER computes hash)...")
        print("[ContentView]   clientDataHash length: \(clientDataHash.count) bytes (expected 32)")
        print("[ContentView]   clientDataHash source: BACKEND ONLY (no frontend computation)")
        
        // Logging check: Log bundle ID for backend comparison (backend enforces policy)
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        print("[ContentView]   Bundle ID (backend expects): \(bundleID)")
        if bundleID != "DanylchukStudios.AppAttestDecoderTestApp" {
            print("[ContentView]   ⚠ WARNING: Bundle ID mismatch - backend may reject based on policy")
        }
        
        // STEP 1: FREEZE THE INPUTS - Log and freeze before generateAssertion. Never re-encode, hash, or regenerate clientDataHash.
        assert(clientDataHash.count == 32, "clientDataHash expected to be 32 bytes before generateAssertion")
        let clientDataHash_hex = clientDataHash.map { String(format: "%02x", $0) }.joined()
        let clientDataHash_sha256 = sha256Hex(clientDataHash)
        let clientDataHash_objectID = ObjectIdentifier(clientDataHash as NSData)
        let clientDataHash_pointer = clientDataHash.withUnsafeBytes { $0.baseAddress }
        print("[ContentView] ========================================")
        print("[ContentView] STEP 1: FROZEN INPUTS verifyRunID=\(verifyRunID) (before generateAssertion)")
        print("[ContentView] ========================================")
        print("[ContentView] keyID=\(keyID)")
        print("[ContentView] flowID=\(currentFlowID ?? "none")")
        print("[ContentView] bundleID=\(bundleID)")
        print("[ContentView] clientDataHash.count: \(clientDataHash.count) bytes (backend-issued 32 raw bytes)")
        print("[ContentView] clientDataHash.hex: \(clientDataHash_hex)")
        print("[ContentView] clientDataHash.sha256: \(clientDataHash_sha256)")
        print("[ContentView] clientDataHash.objectID: \(clientDataHash_objectID)")
        print("[ContentView] clientDataHash.pointer: \(String(describing: clientDataHash_pointer)) (mutation detection only)")
        print("[ContentView] ========================================")
        // clientDataHash is the exact Data decoded once from the backend; no transformations.
        service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertionObject, error in
            DispatchQueue.main.async {
                if let error {
                    self.isSendingToBackend = false
                    self.backendError = "Failed to generate assertion: \(error.localizedDescription)"
                    return
                }
                
                guard let assertionObject else {
                    self.isSendingToBackend = false
                    self.backendError = "Assertion generation returned nil"
                    return
                }
                // NOTE: Backward compatibility function - uses old flow. Forensic dump skipped.
                // Main flow uses requestChallengeAndGenerateAssertion which includes forensic dump.
                
                #if DEBUG
                // DEBUG: Signed Bytes Debug Dump - for comparing with backend logs
                self.dumpSignedBytes(assertionObject: assertionObject, clientDataHash: clientDataHash, verifyRunID: verifyRunID)
                #endif
                
                // IMPORTANT (correctness): Log fingerprints AFTER generation and BEFORE sending
                self.logVerificationFingerprints(keyID: keyID, assertionObject: assertionObject, clientDataHash: clientDataHash, verifyRunID: verifyRunID)
                
                // IMPORTANT (correctness): Send assertion immediately - no storage, no reuse, no regeneration
                // IMPORTANT (correctness): Send only keyID and assertionObject (backend uses stored clientDataHash)
                // IMPORTANT (correctness): Frontend NEVER sends clientDataHash - backend owns it
                self.sendAssertionToBackend(keyID: keyID, assertionObject: assertionObject, verifyRunID: verifyRunID)
            }
        }
    }
}
