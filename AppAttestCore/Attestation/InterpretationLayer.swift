//
//  InterpretationLayer.swift
//  AppAttestCore
//
//  Interpretation layer - provides best-effort meaning with confidence levels
//  Does not claim truth, claims reasoning
//

import Foundation

/// Interpretation layer - adds semantic meaning to decoded structures
/// without claiming authority or decoding undocumented fields
public struct InterpretationLayer {
    
    // MARK: - Trust Posture
    
    public struct TrustPosture {
        public let attestationIntegrity: PostureLevel
        public let certificateChain: PostureLevel
        public let keyType: KeySecurityLevel
        public let replayProtection: PostureLevel
        public let receiptPresence: PostureLevel
        public let environmentBinding: PostureLevel
        
        public var overallPosture: PostureLevel {
            // Conservative: weakest link determines overall
            let levels = [
                attestationIntegrity,
                certificateChain,
                replayProtection,
                environmentBinding
            ]
            return levels.min() ?? .unknown
        }
        
        public var suitableForHighRisk: Bool {
            return overallPosture == .strong &&
                   keyType == .hardwareBacked &&
                   receiptPresence != .missing
        }
    }
    
    public enum PostureLevel: String, Comparable {
        case strong = "Strong"
        case good = "Good"
        case moderate = "Moderate"
        case weak = "Weak"
        case missing = "Missing"
        case unknown = "Unknown"
        
        public static func < (lhs: PostureLevel, rhs: PostureLevel) -> Bool {
            let order: [PostureLevel] = [.strong, .good, .moderate, .weak, .missing, .unknown]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex > rhsIndex // Lower index = stronger
        }
    }
    
    public enum KeySecurityLevel: String {
        case hardwareBacked = "Hardware-backed (Secure Enclave)"
        case software = "Software-backed"
        case unknown = "Unknown"
    }
    
    // MARK: - Usage Guidance
    
    public struct UsageGuidance {
        public let storage: [String]
        public let verification: [String]
        public let rotation: [String]
        public let invalidation: [String]
    }
    
    // MARK: - Opaque Field Interpretation
    
    public struct OpaqueInterpretation {
        public let status: String
        public let confidence: String
        public let observedStructure: [String]
        public let interpretation: String
        public let safeOperation: String
        public let specOrigin: SpecOrigin
        public let stability: Stability
        public let safeUse: SafeUse
    }
    
    public enum SpecOrigin: String {
        case rfc = "RFC"
        case apple = "Apple"
        case vendor = "Vendor"
        case unknown = "Unknown"
    }
    
    public enum Stability: String {
        case stable = "stable"
        case undocumented = "undocumented"
        case `private` = "private"
    }
    
    public enum SafeUse: String {
        case verify = "verify"
        case store = "store"
        case auditOnly = "audit-only"
        case ignore = "ignore"
        case preserve = "preserve + forward to Apple"
    }
    
    // MARK: - Public Key Interpretation
    
    public static func interpretPublicKey(
        keyType: String?,
        algorithm: String?,
        curve: String?
    ) -> UsageGuidance {
        var storage: [String] = []
        var verification: [String] = []
        var rotation: [String] = []
        var invalidation: [String] = []
        
        if keyType == "EC (2)" && curve == "P-256 (1)" {
            storage.append("Store as device-bound identity")
            storage.append("Associate with credential ID for lookup")
            verification.append("Use to verify future assertions")
            verification.append("Verify signature over authenticatorData || clientDataHash")
            rotation.append("Rotate only if new attestation is presented")
            rotation.append("Invalidate old key when new attestation received")
            invalidation.append("Invalidate on policy breach")
            invalidation.append("Invalidate on key compromise")
            invalidation.append("Invalidate on device compromise")
        }
        
        return UsageGuidance(
            storage: storage,
            verification: verification,
            rotation: rotation,
            invalidation: invalidation
        )
    }
    
    // MARK: - Trust Posture Assessment
    
    public static func assessTrustPosture(
        hasAttestation: Bool,
        certificateChainLength: Int,
        keyType: String?,
        signCount: UInt32,
        hasReceipt: Bool,
        hasEnvironment: Bool
    ) -> TrustPosture {
        let attestationIntegrity: PostureLevel = hasAttestation ? .strong : .missing
        let certificateChain: PostureLevel = certificateChainLength >= 2 ? .strong : .weak
        let keySecurity: KeySecurityLevel = (keyType == "EC (2)") ? .hardwareBacked : .unknown
        let replayProtection: PostureLevel = signCount == 0 ? .good : .moderate
        let receiptPresence: PostureLevel = hasReceipt ? .strong : .missing
        let environmentBinding: PostureLevel = hasEnvironment ? .strong : .moderate
        
        return TrustPosture(
            attestationIntegrity: attestationIntegrity,
            certificateChain: certificateChain,
            keyType: keySecurity,
            replayProtection: replayProtection,
            receiptPresence: receiptPresence,
            environmentBinding: environmentBinding
        )
    }
    
    // MARK: - Opaque Field Interpretation
    
    public static func interpretOpaqueExtension(
        oid: String,
        rawLength: Int,
        structure: String?
    ) -> OpaqueInterpretation {
        let name = X509OID.name(for: oid)
        
        // Apple App Attest extensions
        if oid.hasPrefix("1.2.840.113635.100.8") {
            return interpretAppleExtension(oid: oid, name: name, rawLength: rawLength, structure: structure)
        }
        
        // Unknown extension
        return OpaqueInterpretation(
            status: "opaque",
            confidence: "low",
            observedStructure: structure.map { [$0] } ?? ["raw bytes"],
            interpretation: "Extension OID \(oid) is not recognized. Preserved for audit and future decoding.",
            safeOperation: "Treat as integrity-bound but not user-readable. Do not reject attestation based on unknown extensions.",
            specOrigin: .unknown,
            stability: .undocumented,
            safeUse: .auditOnly
        )
    }
    
    private static func interpretAppleExtension(
        oid: String,
        name: String,
        rawLength: Int,
        structure: String?
    ) -> OpaqueInterpretation {
        var observed: [String] = []
        var interpretation = ""
        var safeOp = ""
        var specOrigin: SpecOrigin = .apple
        var stability: Stability = .private
        var safeUse: SafeUse = .auditOnly
        
        if let structDesc = structure {
            observed.append(structDesc)
        }
        
        switch oid {
        case "1.2.840.113635.100.8.2": // Challenge
            interpretation = "Apple App Attest challenge hash. Used to bind attestation to specific request. Decoded but not contractually stable."
            safeOp = "Verify challenge matches expected value. Treat as integrity-bound."
            stability = .undocumented
            safeUse = .verify
            
        case "1.2.840.113635.100.8.5": // Receipt
            interpretation = "Apple-signed evidence blob (CMS/PKCS#7 SignedData). Contains device and app attestation metadata. Decoded structure, inner payload is Apple-private."
            safeOp = "Verify CMS signature independently. Do not parse inner payload unless Apple publishes spec."
            observed.append("CMS SignedData container")
            observed.append("Apple Fraud Receipt Signing certificate")
            stability = .private
            safeUse = .preserve
            
        case "1.2.840.113635.100.8.6": // Key Purpose
            interpretation = "Apple App Attest key purpose identifier. Likely encodes intended use (app-attest, assertion, etc.). Decoded but not contractually stable."
            safeOp = "Treat as integrity-bound. Do not reject based on unknown purpose values."
            stability = .undocumented
            safeUse = .store
            
        case "1.2.840.113635.100.8.7": // Environment
            interpretation = "Apple App Attest environment identifier. Likely encodes device OS + build metadata. Decoded but not contractually stable."
            safeOp = "Treat as integrity-bound but not user-readable. Do not parse for policy decisions unless Apple publishes spec."
            observed.append("ASN.1 SEQUENCE")
            observed.append("contains version-like integers")
            observed.append("contains platform string: \"iphoneos\"")
            stability = .private
            safeUse = .auditOnly
            
        default:
            interpretation = "Apple App Attest extension. Decoded structure, semantics are Apple-private."
            safeOp = "Preserve for audit. Do not reject attestation based on unknown Apple extensions."
            stability = .private
            safeUse = .auditOnly
        }
        
        return OpaqueInterpretation(
            status: "decoded",
            confidence: "medium",
            observedStructure: observed,
            interpretation: interpretation,
            safeOperation: safeOp,
            specOrigin: specOrigin,
            stability: stability,
            safeUse: safeUse
        )
    }
    
    // MARK: - Receipt Interpretation
    
    public static func interpretReceipt(
        containerType: String,
        size: Int,
        structure: String?
    ) -> OpaqueInterpretation {
        var observed: [String] = []
        var interpretation = ""
        
        if containerType.contains("CMS") || containerType.contains("PKCS#7") {
            observed.append("CMS SignedData")
            observed.append("Apple Fraud Receipt Signing certificate")
            interpretation = "Apple-signed evidence blob. Contains device and app attestation metadata. Container decoded, inner payload structure is Apple-private."
        } else if containerType.contains("CBOR") {
            observed.append("CBOR structure")
            interpretation = "Receipt appears to be CBOR-encoded. Structure decoded but semantics are Apple-private."
        } else if containerType.contains("ASN.1") {
            observed.append("ASN.1 structure")
            interpretation = "Receipt appears to be ASN.1-encoded. Structure decoded but semantics are Apple-private."
        } else {
            observed.append("Binary blob")
            interpretation = "Receipt is a binary blob. Structure is Apple-private."
        }
        
        return OpaqueInterpretation(
            status: "decoded",
            confidence: "medium",
            observedStructure: observed,
            interpretation: interpretation,
            safeOperation: "Verify CMS signature independently. Do not parse inner payload unless Apple publishes spec. Preserve for audit.",
            specOrigin: .apple,
            stability: .private,
            safeUse: .preserve
        )
    }
    
    // MARK: - Backend Readiness Summary
    
    public struct BackendReadiness {
        public let store: [String]
        public let verify: [String]
        public let monitor: [String]
        public let reject: [String]
    }
    
    public static func assessBackendReadiness(
        hasCredential: Bool,
        hasReceipt: Bool,
        signCount: UInt32,
        hasEnvironment: Bool
    ) -> BackendReadiness {
        var store: [String] = []
        var verify: [String] = []
        var monitor: [String] = []
        var reject: [String] = []
        
        if hasCredential {
            store.append("Credential ID → Public Key mapping")
            store.append("Attestation timestamp")
            verify.append("RP ID hash matches bundle ID")
            verify.append("Attestation signature over authenticatorData || clientDataHash")
            verify.append("Certificate chain anchors to Apple Root CA G3")
            verify.append("Receipt CMS signature (if present)")
        }
        
        if signCount == 0 {
            store.append("Initial signCount = 0 (first attestation)")
            monitor.append("Track signCount for replay protection")
        } else {
            monitor.append("Verify signCount > last seen (monotonic)")
            reject.append("Reject if signCount <= last seen (replay)")
        }
        
        if hasReceipt {
            verify.append("Receipt CMS signature")
            verify.append("Receipt signing certificate is Apple Fraud Receipt Signing")
            store.append("Receipt raw bytes (for audit)")
        }
        
        if hasEnvironment {
            monitor.append("Track environment changes (sandbox vs production)")
        }
        
        reject.append("Reject if RP ID hash mismatch")
        reject.append("Reject if certificate chain invalid")
        reject.append("Reject if attestation signature invalid")
        reject.append("Reject if receipt signature invalid (if present)")
        
        return BackendReadiness(
            store: store,
            verify: verify,
            monitor: monitor,
            reject: reject
        )
    }
}
