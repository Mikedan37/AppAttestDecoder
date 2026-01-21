//
//  AppAttestDecoder.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//
//  This file provides the high-level decoder interface for App Attest artifacts.
//  It orchestrates CBOR decoding and domain object parsing for attestation objects
//  and assertion objects.
//
//  This decoder performs structural parsing only. It extracts fields, parses
//  certificates, and decodes authenticator data. It does NOT verify signatures,
//  validate certificate chains, check RP ID hashes, or validate nonces/challenges.
//  All validation must be implemented separately by users.
//

import Foundation

public struct AppAttestDecoder {
    public let teamID: String?

    public init(teamID: String? = nil) {
        self.teamID = teamID
    }

    // MARK: - Attestation

    /// Decodes a full App Attest attestation object (CBOR encoded)
    /// - Parameter data: Raw attestation object bytes
    /// - Returns: Parsed `AttestationObject` with all raw materials exposed for validator consumption
    /// - Note: This method only parses structure. All validation must be performed separately.
    public func decodeAttestation(_ data: Data) throws -> AttestationObject {
        let cborValue = try CBORDecoder.decode(data)
        return try AttestationObject(cbor: cborValue, rawData: data)
    }

    /// Backwards-compatible API for tests and CLI
    /// - Parameter data: Raw attestation object bytes
    /// - Returns: Parsed `AttestationObject`
    public func decodeAttestationObject(_ data: Data) throws -> AttestationObject {
        return try decodeAttestation(data)
    }

    // MARK: - Assertion

    /// Decodes an App Attest assertion object (COSE_Sign1 message)
    /// Assertions are COSE_Sign1 structures where the payload contains authenticatorData.
    /// This method only parses the structure; it does NOT verify signatures.
    /// - Parameter data: Raw assertion bytes (CBOR-encoded COSE_Sign1)
    /// - Returns: Parsed `AssertionObject` containing authenticatorData and signature
    /// - Throws: CBORDecodingError, COSEError, or AssertionError if parsing fails
    public func decodeAssertion(_ data: Data) throws -> AssertionObject {
        return try AssertionObject(data: data)
    }

    /// Decodes an App Attest assertion in Apple map format (CBOR 0xa2 with "authenticatorData" and "signature").
    /// Same CBOR path as inspection. Lossless: returns raw bytes only. Does NOT verify.
    /// - Parameter data: Raw assertion bytes (CBOR map)
    /// - Returns: (authenticatorData, signatureDER)
    /// - Throws: CBORDecodingError or AssertionError if not a map or keys missing
    public func decodeAssertionObject(_ data: Data) throws -> (authenticatorData: Data, signatureDER: Data) {
        let cbor = try CBORDecoder.decode(data)
        guard case .map(let pairs) = cbor else { throw AssertionError.invalidStructure }
        var auth: Data?, sig: Data?
        for (k, v) in pairs {
            if case .textString("authenticatorData") = k, case .byteString(let b) = v { auth = b }
            if case .textString("signature") = k, case .byteString(let b) = v { sig = b }
        }
        guard let a = auth, let s = sig else { throw AssertionError.invalidStructure }
        return (a, s)
    }

    /// Decodes an App Attest assertion from base64 (standard, padded). Uses decodeAssertionObject(_:).
    /// - Parameter base64: Base64-encoded assertion (standard alphabet, padding expected)
    /// - Returns: (authenticatorData, signatureDER)
    /// - Throws: AssertionError.invalidInput if base64 decode fails; AssertionError or CBORDecodingError from decodeAssertionObject
    public func decodeAssertionObject(base64Encoded base64: String) throws -> (authenticatorData: Data, signatureDER: Data) {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed), !data.isEmpty else {
            throw AssertionError.invalidInput(reason: "Base64 decode failed or empty")
        }
        return try decodeAssertionObject(data)
    }
}
