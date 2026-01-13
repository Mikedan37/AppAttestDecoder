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
public struct COSESign1 {

    public let protectedHeader: COSEHeader
    public let unprotectedHeader: COSEHeader
    public let payload: Data?
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
