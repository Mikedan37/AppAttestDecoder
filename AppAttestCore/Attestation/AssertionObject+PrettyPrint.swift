import Foundation

extension AssertionObject {
    
    /// Returns a pretty-printed representation of the assertion object
    /// - Parameter colorized: If true, adds ANSI color codes for better terminal readability
    /// - Returns: A formatted string with hierarchical structure and readable formatting
    public func prettyPrint(colorized: Bool = false) -> String {
        var output = ""
        let header = colorized ? 
            "\(ANSIColor.header)Assertion Object\(ANSIColor.reset)\n\(ANSIColor.separator)================\(ANSIColor.reset)\n\n" :
            "Assertion Object\n================\n\n"
        output += header
        
        // COSE Sign1 Structure
        output += formatField("coseSign1", value: "", indent: 0, isContainer: true, colorized: colorized)
        output += prettyPrintCOSESign1(coseSign1, indent: 2, colorized: colorized)
        
        // Authenticator Data
        output += formatField("authenticatorData", value: "", indent: 0, isContainer: true, colorized: colorized)
        output += prettyPrintAuthenticatorData(authenticatorData, indent: 2, colorized: colorized)
        
        // Raw Data
        let rawDataValue = formatHexData(rawData) + " (\(rawData.count) bytes)"
        let rawDataFormatted = colorized ? formatValue(rawDataValue, type: .hex, colorized: colorized) : rawDataValue
        output += formatField("rawData", value: rawDataFormatted, indent: 0, colorized: colorized)
        
        return output
    }
    
    // MARK: - Helper Methods
    
    // ANSI color codes for terminal output (shared with AttestationObject)
    private enum ANSIColor {
        static let reset = "\u{001B}[0m"
        static let bold = "\u{001B}[1m"
        static let dim = "\u{001B}[2m"
        
        // Text colors
        static let fieldName = "\u{001B}[36m"  // Cyan
        static let stringValue = "\u{001B}[32m"  // Green
        static let numberValue = "\u{001B}[33m"  // Yellow
        static let hexValue = "\u{001B}[35m"  // Magenta
        static let booleanValue = "\u{001B}[34m"  // Blue
        static let nilValue = "\u{001B}[31m"  // Red
        static let header = "\u{001B}[1;36m"  // Bold Cyan
        static let separator = "\u{001B}[90m"  // Dark Gray
    }
    
    private enum ValueType {
        case string, number, hex, boolean, nullValue, plain
    }
    
    private func formatValue(_ value: String, type: ValueType, colorized: Bool = false) -> String {
        guard colorized else { return value }
        
        switch type {
        case .string:
            return "\(ANSIColor.stringValue)\(value)\(ANSIColor.reset)"
        case .number:
            return "\(ANSIColor.numberValue)\(value)\(ANSIColor.reset)"
        case .hex:
            return "\(ANSIColor.hexValue)\(value)\(ANSIColor.reset)"
        case .boolean:
            return "\(ANSIColor.booleanValue)\(value)\(ANSIColor.reset)"
        case .nullValue:
            return "\(ANSIColor.nilValue)\(value)\(ANSIColor.reset)"
        case .plain:
            return value
        }
    }
    
    private func formatField(_ name: String, value: String, indent: Int, isContainer: Bool = false, colorized: Bool = false) -> String {
        let indentStr = String(repeating: " ", count: indent)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)`\(name)`\(ANSIColor.reset)" : "`\(name)`"
        
        if isContainer {
            let brace = colorized ? "\(ANSIColor.separator){\(ANSIColor.reset)" : "{"
            return "\(indentStr)\(nameFormatted): \(brace)\n"
        } else {
            return "\(indentStr)\(nameFormatted): \(value)\n"
        }
    }
    
    private func formatHexData(_ data: Data, bytesPerGroup: Int = 4) -> String {
        let hexString = data.map { String(format: "%02x", $0) }.joined()
        var formatted = ""
        for (index, char) in hexString.enumerated() {
            if index > 0 && index % (bytesPerGroup * 2) == 0 {
                formatted += " "
            }
            formatted.append(char)
        }
        return formatted
    }
    
    private func prettyPrintCOSESign1(_ sign1: COSESign1, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        
        // Protected Header
        output += formatField("protectedHeader", value: "", indent: indent, isContainer: true, colorized: colorized)
        let protectedIndent = indent + 2
        
        if let alg = sign1.protectedHeader.algorithm {
            let algFormatted = colorized ? formatValue("\(alg.rawValue)", type: .number, colorized: colorized) : "\(alg.rawValue)"
            output += formatField("algorithm", value: algFormatted, indent: protectedIndent, colorized: colorized)
        } else {
            let nilValue = colorized ? formatValue("nil", type: .nullValue, colorized: colorized) : "nil"
            output += formatField("algorithm", value: nilValue, indent: protectedIndent, colorized: colorized)
        }
        
        if let kid = sign1.protectedHeader.keyID {
            let kidValue = formatHexData(kid) + " (\(kid.count) bytes)"
            let kidFormatted = colorized ? formatValue(kidValue, type: .hex, colorized: colorized) : kidValue
            output += formatField("keyID", value: kidFormatted, indent: protectedIndent, colorized: colorized)
        }
        
        if !sign1.protectedHeader.x5c.isEmpty {
            output += formatField("x5c", value: "", indent: protectedIndent, isContainer: true, colorized: colorized)
            for (index, cert) in sign1.protectedHeader.x5c.enumerated() {
                let certIndent = protectedIndent + 2
                let certValue = formatHexData(cert) + " (\(cert.count) bytes)"
                let certFormatted = colorized ? formatValue(certValue, type: .hex, colorized: colorized) : certValue
                output += formatField("[\(index)]", value: certFormatted, indent: certIndent, colorized: colorized)
            }
            let x5cCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
            output += "\(String(repeating: " ", count: protectedIndent))\(x5cCloseBrace)\n"
        }
        
        let protectedCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(String(repeating: " ", count: indent))\(protectedCloseBrace)\n"
        
        // Unprotected Header
        output += formatField("unprotectedHeader", value: "", indent: indent, isContainer: true, colorized: colorized)
        // Unprotected header is typically empty for App Attest assertions
        let unprotectedCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(String(repeating: " ", count: indent))\(unprotectedCloseBrace)\n"
        
        // Payload
        if let payload = sign1.payload {
            let payloadValue = formatHexData(payload) + " (\(payload.count) bytes)"
            let payloadFormatted = colorized ? formatValue(payloadValue, type: .hex, colorized: colorized) : payloadValue
            output += formatField("payload", value: payloadFormatted, indent: indent, colorized: colorized)
        } else {
            let nilValue = colorized ? formatValue("nil", type: .nullValue, colorized: colorized) : "nil"
            output += formatField("payload", value: nilValue, indent: indent, colorized: colorized)
        }
        
        // Signature
        let sigValue = formatHexData(sign1.signature) + " (\(sign1.signature.count) bytes)"
        let sigFormatted = colorized ? formatValue(sigValue, type: .hex, colorized: colorized) : sigValue
        output += formatField("signature", value: sigFormatted, indent: indent, colorized: colorized)
        
        // Close coseSign1 container
        let parentIndent = indent - 2
        let parentIndentStr = String(repeating: " ", count: max(0, parentIndent))
        let closeBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(parentIndentStr)\(closeBrace)\n"
        
        return output
    }
    
    private func prettyPrintAuthenticatorData(_ authData: AuthenticatorData, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        
        // RP ID Hash
        let rpIdHashValue = formatHexData(authData.rpIdHash) + " (32 bytes)"
        let rpIdHashFormatted = colorized ? formatValue(rpIdHashValue, type: .hex, colorized: colorized) : rpIdHashValue
        output += formatField("rpIdHash", value: rpIdHashFormatted, indent: indent, colorized: colorized)
        
        // Flags
        let flagsName = colorized ? "\(ANSIColor.fieldName)`flags`\(ANSIColor.reset)" : "`flags`"
        let flagsBrace = colorized ? "\(ANSIColor.separator){\(ANSIColor.reset)" : "{"
        output += "\(indentStr)\(flagsName): \(flagsBrace)\n"
        let flagsIndent = indent + 2
        
        let rawValueStr = "0x\(String(format: "%02x", authData.flags.rawValue)) (\(authData.flags.rawValue))"
        let rawValueFormatted = colorized ? formatValue(rawValueStr, type: .hex, colorized: colorized) : rawValueStr
        output += formatField("rawValue", value: rawValueFormatted, indent: flagsIndent, colorized: colorized)
        
        let userPresentFormatted = colorized ? formatValue("\(authData.flags.userPresent)", type: .boolean, colorized: colorized) : "\(authData.flags.userPresent)"
        output += formatField("userPresent", value: userPresentFormatted, indent: flagsIndent, colorized: colorized)
        
        let userVerifiedFormatted = colorized ? formatValue("\(authData.flags.userVerified)", type: .boolean, colorized: colorized) : "\(authData.flags.userVerified)"
        output += formatField("userVerified", value: userVerifiedFormatted, indent: flagsIndent, colorized: colorized)
        
        let attestedFormatted = colorized ? formatValue("\(authData.flags.attestedCredentialData)", type: .boolean, colorized: colorized) : "\(authData.flags.attestedCredentialData)"
        output += formatField("attestedCredentialData", value: attestedFormatted, indent: flagsIndent, colorized: colorized)
        
        let extensionsFormatted = colorized ? formatValue("\(authData.flags.extensionsIncluded)", type: .boolean, colorized: colorized) : "\(authData.flags.extensionsIncluded)"
        output += formatField("extensionsIncluded", value: extensionsFormatted, indent: flagsIndent, colorized: colorized)
        
        let flagsCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(indentStr)\(flagsCloseBrace)\n"
        
        // Sign Count
        let signCountFormatted = colorized ? formatValue("\(authData.signCount)", type: .number, colorized: colorized) : "\(authData.signCount)"
        output += formatField("signCount", value: signCountFormatted, indent: indent, colorized: colorized)
        
        // Attested Credential Data (typically not present in assertions)
        if authData.attestedCredentialData != nil {
            output += formatField("attestedCredentialData", value: "", indent: indent, isContainer: true, colorized: colorized)
            // Note: Full credential data pretty-print would go here if needed
            let credDataCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
            output += "\(String(repeating: " ", count: indent))\(credDataCloseBrace)\n"
        } else {
            let nilValue = colorized ? formatValue("nil", type: .nullValue, colorized: colorized) : "nil"
            output += formatField("attestedCredentialData", value: nilValue, indent: indent, colorized: colorized)
        }
        
        // Extensions
        if authData.extensions != nil {
            output += formatField("extensions", value: "", indent: indent, isContainer: true, colorized: colorized)
            // Extensions would be pretty-printed here if needed
            let extensionsCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
            output += "\(String(repeating: " ", count: indent))\(extensionsCloseBrace)\n"
        } else {
            let nilValue = colorized ? formatValue("nil", type: .nullValue, colorized: colorized) : "nil"
            output += formatField("extensions", value: nilValue, indent: indent, colorized: colorized)
        }
        
        // Raw Data
        let rawDataValue = formatHexData(authData.rawData) + " (\(authData.rawData.count) bytes)"
        let rawDataFormatted = colorized ? formatValue(rawDataValue, type: .hex, colorized: colorized) : rawDataValue
        output += formatField("rawData", value: rawDataFormatted, indent: indent, colorized: colorized)
        
        // Close authenticatorData container
        let parentIndent = indent - 2
        let parentIndentStr = String(repeating: " ", count: max(0, parentIndent))
        let authDataCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(parentIndentStr)\(authDataCloseBrace)\n"
        
        return output
    }
}

