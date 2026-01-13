//
//  COSESign1.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// Minimal COSE_Sign1 decoder per RFC 8152 / 9052.
/// Expects a CBOR array of the form:
/// [ protected : bstr, unprotected : map, payload : bstr / null, signature : bstr ]
/// This structure is decoded but NOT verified. All fields are exposed for validator consumption.
public struct COSESign1 {

    /// Protected header (CBOR-encoded map, typically contains algorithm).
    /// This header is parsed but NOT validated. Consumers must verify algorithm and other parameters.
    public let protectedHeader: COSEHeader
    
    /// Unprotected header (CBOR map, may contain additional parameters).
    /// This header is parsed but NOT validated. Consumers must verify any parameters they use.
    public let unprotectedHeader: COSEHeader
    
    /// Payload (byte string or null). For assertions, this contains authenticator data.
    /// This value is extracted but NOT validated. Consumers must parse and validate payload separately.
    public let payload: Data?
    
    /// Signature bytes. Cryptographic signature over the protected header and payload.
    /// This value is extracted but NOT verified. Consumers must verify signature using appropriate keys.
    public let signature: Data

    public init(from value: CBORValue) throws {
        guard case .array(let items) = value, items.count == 4 else {
            throw COSEError.invalidStructure
        }

        // 1. Protected header (bstr -> CBOR map)
        self.protectedHeader = try COSEHeader.decodeProtected(items[0])

        // 2. Unprotected header (map)
        self.unprotectedHeader = try COSEHeader.decodeUnprotected(items[1])

        // 3. Payload (bstr or null)
        switch items[2] {
        case .byteString(let data):
            self.payload = data
        case .null:
            self.payload = nil
        default:
            throw COSEError.invalidPayload
        }

        // 4. Signature (bstr)
        guard let sig = items[3].bytes else {
            throw COSEError.invalidSignature
        }
        self.signature = sig
    }
}
