//
//  BackendForensics.swift
//  AppAttestDecoderTestApp
//
//  Model for optional "forensics" object in /app-attest/verify response (dev-only).
//  Compare to CryptoEvidence (EvidenceStore) for Diff View.
//

import Foundation

struct BackendForensics {
    var authenticatorData_sha256: String?
    var storedClientDataHash_sha256: String?
    var signature_sha256: String?
    var signedBytesA_sha256: String?
    var digestA_hex: String?
    var signedBytesB_sha256: String?
    var digestB_hex: String?
    /// Optional raw hex for first-differing-byte diff (backend must include).
    var authenticatorData_hex: String?
    var storedClientDataHash_hex: String?
    var signature_hex: String?

    static func from(_ json: [String: Any]) -> BackendForensics? {
        guard let f = json["forensics"] as? [String: Any] else { return nil }
        return BackendForensics(
            authenticatorData_sha256: f["authenticatorData_sha256"] as? String,
            storedClientDataHash_sha256: f["storedClientDataHash_sha256"] as? String,
            signature_sha256: f["signature_sha256"] as? String,
            signedBytesA_sha256: f["signedBytesA_sha256"] as? String,
            digestA_hex: f["digestA_hex"] as? String,
            signedBytesB_sha256: f["signedBytesB_sha256"] as? String,
            digestB_hex: f["digestB_hex"] as? String,
            authenticatorData_hex: f["authenticatorData_hex"] as? String,
            storedClientDataHash_hex: f["storedClientDataHash_hex"] as? String,
            signature_hex: f["signature_hex"] as? String
        )
    }
}
