//
//  AssertionObject.swift
//  AppAttestCore
//
//  This file defines the AssertionObject structure for decoded App Attest assertions.
//  Assertions are COSE_Sign1 messages containing authenticatorData and a signature.
//
//  This decoder only parses the structure and extracts fields. It does NOT verify
//  signatures, validate certificate chains, check RP ID hashes, or validate
//  nonces/challenges. All validation must be implemented separately.
//

import Foundation

/// Represents a decoded App Attest assertion object.
/// Assertions are COSE_Sign1 messages containing authenticatorData and a signature.
/// This decoder only parses the structure; it does NOT verify signatures.
public struct AssertionObject {
    
    /// The authenticator data from the assertion payload
    public let authenticatorData: AuthenticatorData
    
    /// The COSE Sign1 structure containing headers and signature
    public let coseSign1: COSESign1
    
    /// Algorithm identifier from the protected header (as integer, e.g., -7 for ES256)
    public var algorithm: Int? {
        return coseSign1.protectedHeader.algorithm?.rawValue
    }
    
    /// Signature bytes (not verified)
    public var signature: Data {
        return coseSign1.signature
    }
    
    /// Raw assertion bytes
    public let rawData: Data
    
    /// Initializes an AssertionObject from raw assertion bytes.
    /// Assertions are COSE_Sign1 messages where the payload is authenticatorData.
    /// - Parameter data: Raw assertion bytes (CBOR-encoded COSE_Sign1)
    /// - Throws: CBORDecodingError, COSEError, or AttestationError if parsing fails
    public init(data: Data) throws {
        self.rawData = data
        
        // Step 1: Decode CBOR
        let cborValue = try CBORDecoder.decode(data)
        
        // Step 2: Parse as COSE_Sign1
        self.coseSign1 = try COSESign1(from: cborValue)
        
        // Step 3: Extract authenticatorData from payload
        guard let payload = coseSign1.payload else {
            throw AssertionError.missingPayload
        }
        
        // Step 4: Parse authenticatorData
        self.authenticatorData = try AuthenticatorData(rawData: payload)
    }
}

/// Errors that can occur during assertion decoding
public enum AssertionError: Error, CustomStringConvertible {
    case missingPayload
    case invalidStructure
    case invalidAuthenticatorData
    
    public var description: String {
        switch self {
        case .missingPayload:
            return "Assertion COSE_Sign1 payload is missing or null"
        case .invalidStructure:
            return "Invalid assertion structure: expected COSE_Sign1 format"
        case .invalidAuthenticatorData:
            return "Invalid authenticator data in assertion payload"
        }
    }
}

