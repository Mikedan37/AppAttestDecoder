//
//  AppAttestCore.swift
//  AppAttestCore
//
//  Created by Michael Danylchuk on 1/12/26.
//
//  This file provides the public API entry points for the AppAttestCore framework.
//  It exposes static methods for decoding App Attest artifacts (attestation objects,
//  COSE Sign1 messages, and key IDs).
//
//  This module performs structural parsing only. It does not perform cryptographic
//  validation, certificate chain verification, or any security checks. Users must
//  implement complete validation logic separately for production use.
//

import Foundation

// MARK: - Public API Entry Points

public enum AppAttest {
    
    // Empty enum used as namespace

    /// Decodes a raw attestation object into a structured representation.
    /// - Parameter data: Raw attestation object bytes
    /// - Returns: Parsed `AttestationObject` with rawData populated for validator consumption
    public static func decodeAttestationObject(_ data: Data) throws -> AttestationObject {
        let node = try CBORDecoder.decode(data)
        return try AttestationObject(cbor: node, rawData: data)
    }

    /// Decodes a COSE Sign1 message into its payload and headers
    public static func decodeCOSESign1(_ data: Data) throws -> (payload: Data?, header: COSEHeader) {
        let cborValue = try CBORDecoder.decode(data)
        let sign1 = try COSESign1(from: cborValue)
        return (payload: sign1.payload, header: sign1.protectedHeader)
    }

    /// Decodes a Key ID from Base64 string
    public static func decodeKeyID(_ base64: String) -> Data? {
        return Data(base64Encoded: base64)
    }
}
