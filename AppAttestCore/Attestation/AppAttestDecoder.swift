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
}
