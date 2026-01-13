//
//  X509Error.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// Errors thrown by the lightweight ASN.1/DER + X.509 parsing layer.
public enum X509Error: Error, CustomStringConvertible, LocalizedError {
    // MARK: - DER / ASN.1
    case truncated
    case invalidTag(expected: UInt8?, actual: UInt8)
    case invalidLength
    case lengthOutOfBounds
    case nonMinimalLengthEncoding
    case invalidOID
    case unsupportedIndefiniteLength

    // MARK: - X.509 structure
    case invalidCertificate
    case unsupportedCertificateVersion(Int)
    case missingRequiredField(String)
    case unsupportedAlgorithm(String)
    case invalidTimeEncoding

    // MARK: - Key / SPKI
    case invalidBitString
    case invalidPublicKey

    public var errorDescription: String? { description }

    public var description: String {
        switch self {
        case .truncated:
            return "DER/ASN.1: input ended unexpectedly (truncated)."
        case .invalidTag(let expected, let actual):
            if let expected {
                return String(format: "DER/ASN.1: invalid tag (expected 0x%02X, got 0x%02X).", expected, actual)
            }
            return String(format: "DER/ASN.1: invalid/unexpected tag 0x%02X.", actual)
        case .invalidLength:
            return "DER/ASN.1: invalid length encoding."
        case .lengthOutOfBounds:
            return "DER/ASN.1: length exceeds available input."
        case .nonMinimalLengthEncoding:
            return "DER/ASN.1: non-minimal length encoding."
        case .invalidOID:
            return "DER/ASN.1: invalid OBJECT IDENTIFIER encoding."
        case .unsupportedIndefiniteLength:
            return "DER/ASN.1: indefinite-length encoding is not supported (DER requires definite length)."

        case .invalidCertificate:
            return "X.509: invalid certificate structure."
        case .unsupportedCertificateVersion(let v):
            return "X.509: unsupported certificate version: \(v)."
        case .missingRequiredField(let field):
            return "X.509: missing required field: \(field)."
        case .unsupportedAlgorithm(let alg):
            return "X.509: unsupported/unknown algorithm: \(alg)."
        case .invalidTimeEncoding:
            return "X.509: invalid time encoding (UTCTime/GeneralizedTime)."

        case .invalidBitString:
            return "X.509: invalid BIT STRING encoding."
        case .invalidPublicKey:
            return "X.509: invalid SubjectPublicKeyInfo / public key encoding."
        }
    }
}
