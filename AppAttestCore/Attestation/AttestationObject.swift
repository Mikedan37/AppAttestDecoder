//
//  AttestationObject.swift
//  AppAttestCore
//
//  This file defines the AttestationObject structure for decoded App Attest
//  attestation objects. It parses CBOR-encoded attestation data into structured
//  domain objects (format, authenticatorData, attestationStatement).
//
//  This decoder only parses the structure and extracts fields. It does NOT verify
//  signatures, validate certificate chains, check RP ID hashes, or validate
//  nonces/challenges. All validation must be implemented separately.
//

import Foundation

public struct AttestationObject {

    public let format: String
    public let authenticatorData: AuthenticatorData
    public let attestationStatement: AttStmt

    public init(cbor: CBORValue) throws {
        let topLevel: CBORValue

        // Step 1: unwrap CBOR tag if present
        switch cbor {
        case .tagged(_, let inner):
            topLevel = inner
        default:
            topLevel = cbor
        }

        // Step 2: App Attest wraps the attestation object inside a CBOR byte string
        let unwrapped: CBORValue
        switch topLevel {
        case .byteString(let data):
            // App Attest defines the top-level object as a single CBOR-encoded byte string
            unwrapped = try CBORDecoder.decode(data)
        default:
            unwrapped = topLevel
        }

        // Step 3: normalize until we reach a CBOR map (NO recursive byteString decoding)
        func extractMap(from value: CBORValue) throws -> [(CBORValue, CBORValue)] {
            switch value {
            case .map(let m):
                return m

            case .tagged(_, let inner):
                return try extractMap(from: inner)

            case .array(let arr):
                guard arr.count == 1 else {
                    throw AttestationError.invalidTopLevelType
                }
                return try extractMap(from: arr[0])

            default:
                // Byte strings are opaque by spec and must NOT be CBOR-decoded here
                throw AttestationError.invalidTopLevelType
            }
        }

        let mapPairs = try extractMap(from: unwrapped)
        let map = Dictionary(uniqueKeysWithValues: mapPairs)

        // Helper to get all keys as strings for error messages
        // Note: CBOR decoder already decodes negative integers, so .negative contains the actual value
        func getAllKeys() -> [String] {
            return mapPairs.map { pair -> String in
                switch pair.0 {
                case .textString(let s):
                    return s
                case .negative(let n):
                    // The decoder already decoded it, so n is the actual negative value
                    return "\(Int(n))"
                case .unsigned(let u):
                    return "\(u)"
                default:
                    return "\(pair.0)"
                }
            }
        }

        // --- Decode fmt ---
        guard let fmtValue = map[.textString("fmt")] ?? map[.textString("format")],
              let format = fmtValue.string else {
            throw AttestationError.missingRequiredField(availableKeys: [], allKeys: getAllKeys())
        }

        // --- Decode attestation statement ---
        guard let attStmtValue = map[.textString("attStmt")] ?? map[.textString("attestationStatement")] else {
            throw AttestationError.missingRequiredField(availableKeys: [], allKeys: getAllKeys())
        }

        // --- Decode authenticator data ---
        var authDataBytes: Data?
        
        // 1️⃣ Try standard text keys
        if let b = map[.textString("authData")]?.bytes {
            authDataBytes = b
        } else if let b = map[.textString("authenticatorData")]?.bytes {
            authDataBytes = b
        }
        
        // 2️⃣ Fallback: search for byte strings in the entire structure
        // Apple's App Attest might embed authData in attStmt or use a different structure
        if authDataBytes == nil {
            // Helper to find the largest byte string (likely to be authData)
            // authData is typically 37+ bytes (32 for rpIdHash + flags + counter + optional data)
            var candidateByteStrings: [(Data, String)] = []
            
            func collectByteStrings(in value: CBORValue, path: String = "root") {
                switch value {
                case .byteString(let bs):
                    // Collect all byte strings, we'll pick the largest one that's >= 37 bytes
                    candidateByteStrings.append((bs, path))
                case .array(let arr):
                    for (idx, elem) in arr.enumerated() {
                        collectByteStrings(in: elem, path: "\(path)[\(idx)]")
                    }
                case .map(let pairs):
                    for (key, val) in pairs {
                        let keyStr: String
                        switch key {
                        case .textString(let s):
                            keyStr = s
                        case .negative(let n):
                            keyStr = "\(n)"
                        case .unsigned(let u):
                            keyStr = "\(u)"
                        default:
                            keyStr = "\(key)"
                        }
                        collectByteStrings(in: val, path: "\(path).\(keyStr)")
                    }
                case .tagged(_, let inner):
                    collectByteStrings(in: inner, path: "\(path)[tagged]")
                default:
                    break
                }
            }
            
            // Collect all byte strings from the entire structure
            collectByteStrings(in: unwrapped)
            
            // Filter to byte strings that are large enough to be authData (>= 37 bytes)
            // and pick the largest one (authData is typically the largest byte string)
            let validCandidates = candidateByteStrings.filter { $0.0.count >= 37 }
            if let largest = validCandidates.max(by: { $0.0.count < $1.0.count }) {
                authDataBytes = largest.0
            } else if let anyLarge = candidateByteStrings.first(where: { $0.0.count >= 30 }) {
                // Fallback: if no 37+ byte strings, try 30+ (might be minimal authData)
                authDataBytes = anyLarge.0
            }
        }

        guard let finalAuthData = authDataBytes else {
            // Create an array of key descriptions
            var allKeysList = getAllKeys()

            // Inspect the value under the negative integer key (for debugging)
            for (key, value) in mapPairs {
                if case .negative = key {
                    let valueInfo: String
                    switch value {
                    case .byteString(let bs):
                        valueInfo = "byteString(\(bs.count) bytes)"
                    case .array(let arr):
                        let elements = arr.map { elem -> String in
                            switch elem {
                            case .byteString(let bs):
                                return "byteString(\(bs.count) bytes)"
                            default:
                                return "\(elem)"
                            }
                        }.joined(separator: ", ")
                        valueInfo = "array(\(arr.count) elements): [\(elements)]"
                    case .tagged(let tag, let inner):
                        valueInfo = "tagged(\(tag), \(inner))"
                    default:
                        valueInfo = "\(value) (type: \(type(of: value)))"
                    }

                    allKeysList.append("Value under \(key): \(valueInfo)")
                    break
                }
            }

            throw AttestationError.missingRequiredField(
                availableKeys: [],
                allKeys: allKeysList
            )
        }

        self.format = format
        self.authenticatorData = try AuthenticatorData(rawData: finalAuthData)
        self.attestationStatement = try AttStmt(cbor: attStmtValue)
    }
}

public enum AttestationError: Error, CustomStringConvertible {
    case invalidTopLevelType
    case missingRequiredField(availableKeys: [String], allKeys: [String])
    case invalidFormatField
    case invalidAuthenticatorData
    
    public var description: String {
        switch self {
        case .invalidTopLevelType:
            return "Invalid attestation object top-level type"
        case .missingRequiredField(let textKeys, let allKeys):
            var msg = "Missing required field in attestation object."
            if !textKeys.isEmpty {
                msg += " Text keys: \(textKeys.joined(separator: ", "))"
            }
            if !allKeys.isEmpty {
                msg += " All keys: \(allKeys.joined(separator: ", "))"
            }
            return msg
        case .invalidFormatField:
            return "Invalid format field in attestation object"
        case .invalidAuthenticatorData:
            return "Invalid authenticator data in attestation object"
        }
    }
}
