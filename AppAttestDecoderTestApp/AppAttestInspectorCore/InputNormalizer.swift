//
//  InputNormalizer.swift
//  AppAttestInspectorCore
//
//  Normalizes various input encodings into Data.
//

import Foundation

public enum InputNormalizationError: Error, CustomStringConvertible {
    case invalidBase64
    case invalidBase64URL
    case invalidHex
    case emptyInput
    
    public var description: String {
        switch self {
        case .invalidBase64:
            return "Invalid Base64 encoding"
        case .invalidBase64URL:
            return "Invalid Base64URL encoding"
        case .invalidHex:
            return "Invalid hex encoding"
        case .emptyInput:
            return "Input is empty"
        }
    }
}

public struct InputNormalizer {
    /// Normalize input string to Data based on encoding
    public static func normalize(_ input: String, encoding: InputEncoding) throws -> Data {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw InputNormalizationError.emptyInput
        }
        
        switch encoding {
        case .base64:
            guard let data = Data(base64Encoded: trimmed) else {
                throw InputNormalizationError.invalidBase64
            }
            return data
            
        case .base64URL:
            // Base64URL uses - and _ instead of + and /
            let base64 = trimmed
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            // Add padding if needed
            let padding = String(repeating: "=", count: (4 - base64.count % 4) % 4)
            guard let data = Data(base64Encoded: base64 + padding) else {
                throw InputNormalizationError.invalidBase64URL
            }
            return data
            
        case .hex:
            // Remove common hex prefixes and whitespace
            let cleaned = trimmed
                .replacingOccurrences(of: "0x", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
            
            guard cleaned.count % 2 == 0 else {
                throw InputNormalizationError.invalidHex
            }
            
            var data = Data()
            var index = cleaned.startIndex
            while index < cleaned.endIndex {
                let nextIndex = cleaned.index(index, offsetBy: 2)
                let byteString = String(cleaned[index..<nextIndex])
                guard let byte = UInt8(byteString, radix: 16) else {
                    throw InputNormalizationError.invalidHex
                }
                data.append(byte)
                index = nextIndex
            }
            return data
            
        case .raw:
            return Data(trimmed.utf8)
        }
    }
    
    /// Auto-detect encoding and normalize
    public static func autoNormalize(_ input: String) throws -> Data {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw InputNormalizationError.emptyInput
        }
        
        // Try Base64 first (most common)
        if let data = Data(base64Encoded: trimmed) {
            return data
        }
        
        // Try Base64URL
        let base64URL = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - base64URL.count % 4) % 4)
        if let data = Data(base64Encoded: base64URL + padding) {
            return data
        }
        
        // Try hex (must be even length and only hex chars)
        let cleaned = trimmed
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if cleaned.count % 2 == 0,
           cleaned.allSatisfy({ $0.isHexDigit }),
           let data = try? hexToData(cleaned) {
            return data
        }
        
        // Fallback to raw UTF-8
        return Data(trimmed.utf8)
    }
    
    private static func hexToData(_ hex: String) throws -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                throw InputNormalizationError.invalidHex
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}

extension Character {
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
