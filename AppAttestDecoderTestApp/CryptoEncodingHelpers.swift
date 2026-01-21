//
//  CryptoEncodingHelpers.swift
//  AppAttestDecoderTestApp
//
//  Explicit encoding helpers. All crypto inputs carried as Data; base64 only at network boundary.
//  - Data <-> hex
//  - Data <-> base64 (standard, padded)
//  - base64url decode (separate, never automatic)
//

import Foundation

enum CryptoEncoding {

    // MARK: - Data <-> hex

    static func dataToHex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns nil if string has odd length or non-hex characters.
    static func hexToData(_ hex: String) -> Data? {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard s.count.isMultiple(of: 2), s.allSatisfy({ $0.isHexDigit }) else { return nil }
        var d = Data(capacity: s.count / 2)
        var i = s.startIndex
        while i < s.endIndex {
            let next = s.index(i, offsetBy: 2)
            guard let b = UInt8(s[i..<next], radix: 16) else { return nil }
            d.append(b)
            i = next
        }
        return d
    }

    // MARK: - Data <-> base64 (standard, padded)

    static func dataToBase64(_ data: Data) -> String {
        data.base64EncodedString()
    }

    /// Standard base64 decode. No base64url, no padding relaxation. Returns nil on failure.
    static func base64ToData(_ base64: String) -> Data? {
        let s = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(base64Encoded: s)
    }

    // MARK: - base64url decode (separate, explicit)

    /// Decode base64url only. Use when backend explicitly sends base64url. Does not accept standard base64.
    static func base64URLToData(_ base64url: String) -> Data? {
        var t = base64url.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "-", with: "+")
             .replacingOccurrences(of: "_", with: "/")
        let rem = t.count % 4
        if rem != 0 { t += String(repeating: "=", count: 4 - rem) }
        return Data(base64Encoded: t)
    }
}
