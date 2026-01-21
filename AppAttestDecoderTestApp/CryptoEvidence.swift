//
//  CryptoEvidence.swift
//  AppAttestDecoderTestApp
//
//  Reproducible ground-truth crypto bytes for assertion verify requests.
//  Used for logging (FRONTEND_CANONICAL), request construction, and Diff View.
//  Observational only; no on-device ECDSA verification.
//

import Foundation
import CryptoKit

struct CryptoEvidence {
    let verifyRunID: String
    let flowID: String?
    let keyID_sha256: String
    let challenge_id: String
    let clientDataBytes: Data
    let authenticatorData: Data
    let clientDataHash: Data
    let signedBytes: Data
    let signatureDER: Data
    let publicKeyX963: Data?
    let assertionObject_sha256: String
    let assertionObject_length: Int

    // MARK: - Output helpers (lowercase hex, no spaces; standard base64)

    static func sha256Hex(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }

    static func rawHex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func base64Std(_ data: Data) -> String {
        data.base64EncodedString()
    }

    // MARK: - Computed hashes (for Diff View and canonical)

    var authenticatorData_sha256: String { Self.sha256Hex(authenticatorData) }
    var clientDataHash_sha256: String { Self.sha256Hex(clientDataHash) }
    var signedBytes_sha256: String { Self.sha256Hex(signedBytes) }
    var signature_sha256: String { Self.sha256Hex(signatureDER) }
    var publicKeyX963_sha256: String? { publicKeyX963.map { Self.sha256Hex($0) } }

    var authenticatorData_hex: String { Self.rawHex(authenticatorData) }
    var clientDataHash_hex: String { Self.rawHex(clientDataHash) }
    var signature_hex: String { Self.rawHex(signatureDER) }

    /// SHA256(clientDataBytes) in hex; equals clientDataHash_hex.
    var clientData_sha256: String { clientDataHash_hex }

    /// FRONTEND_CANONICAL: one grep-friendly JSON line for logging.
    func canonicalJSONLine() -> String {
        let j: [String: Any] = [
            "verifyRunID": verifyRunID,
            "flowID": flowID ?? "",
            "keyID_sha256": keyID_sha256,
            "challenge_id": challenge_id,
            "clientDataBytes_length": clientDataBytes.count,
            "authenticatorData_sha256": authenticatorData_sha256,
            "clientDataHash_sha256": clientDataHash_sha256,
            "signedBytes_sha256": signedBytes_sha256,
            "signature_sha256": signature_sha256,
            "publicKeyX963_sha256": publicKeyX963_sha256 ?? "",
            "authenticatorData_length": authenticatorData.count,
            "clientDataHash_length": clientDataHash.count,
            "signedBytes_length": signedBytes.count,
            "signature_length": signatureDER.count,
            "publicKeyX963_length": publicKeyX963?.count ?? 0,
            "assertionObject_sha256": assertionObject_sha256,
            "assertionObject_length": assertionObject_length,
        ]
        guard let d = try? JSONSerialization.data(withJSONObject: j),
              let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }
}

// MARK: - EvidenceStore

final class EvidenceStore {
    static let shared = EvidenceStore()
    private init() {}

    private var storage: [String: CryptoEvidence] = [:]
    private(set) var lastVerifyRunID: String?

    func store(_ e: CryptoEvidence) {
        storage[e.verifyRunID] = e
        lastVerifyRunID = e.verifyRunID
    }

    func get(_ runID: String) -> CryptoEvidence? { storage[runID] }

    func getLast() -> CryptoEvidence? { lastVerifyRunID.flatMap { storage[$0] } }

    func clear() {
        storage = [:]
        lastVerifyRunID = nil
    }
}
