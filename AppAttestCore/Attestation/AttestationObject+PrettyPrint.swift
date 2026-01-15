import Foundation

extension AttestationObject {
    
    /// Returns a pretty-printed representation of the attestation object
    /// - Parameter colorized: If true, adds ANSI color codes for better terminal readability
    /// - Returns: A formatted string with hierarchical structure and readable formatting
    public func prettyPrint(colorized: Bool = false) -> String {
        var output = ""
        let header = colorized ? 
            "\(ANSIColor.header)Attestation Object\(ANSIColor.reset)\n\(ANSIColor.separator)==================\(ANSIColor.reset)\n\n" :
            "Attestation Object\n==================\n\n"
        output += header
        
        // Format field
        let formatValue = colorized ? formatValue(format, type: .string, colorized: colorized) : format
        output += formatField("format", value: formatValue, indent: 0, colorized: colorized)
        
        // Authenticator Data
        output += formatField("authenticatorData", value: "", indent: 0, isContainer: true, colorized: colorized)
        output += prettyPrintAuthenticatorData(authenticatorData, indent: 2, colorized: colorized)
        
        // Attestation Statement
        output += formatField("attestationStatement", value: "", indent: 0, isContainer: true, colorized: colorized)
        output += prettyPrintAttStmt(attestationStatement, indent: 2, colorized: colorized)
        
        return output
    }
    
    // MARK: - Helper Methods
    
    // ANSI color codes for terminal output
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
        
        // Attested Credential Data
        if let credData = authData.attestedCredentialData {
            output += formatField("attestedCredentialData", value: "", indent: indent, isContainer: true, colorized: colorized)
            output += prettyPrintAttestedCredentialData(credData, indent: indent + 2, colorized: colorized)
        } else {
            let nilValue = colorized ? formatValue("nil", type: .nullValue, colorized: colorized) : "nil"
            output += formatField("attestedCredentialData", value: nilValue, indent: indent, colorized: colorized)
        }
        
        // Extensions
        if let extensions = authData.extensions {
            output += formatField("extensions", value: "", indent: indent, isContainer: true, colorized: colorized)
            output += prettyPrintCBORValue(extensions, indent: indent + 2, colorized: colorized)
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
    
    private func prettyPrintAttestedCredentialData(_ credData: AttestedCredentialData, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        
        // AAGUID
        let aaguidValue = formatHexData(credData.aaguid) + " (16 bytes)"
        let aaguidFormatted = colorized ? formatValue(aaguidValue, type: .hex, colorized: colorized) : aaguidValue
        output += formatField("aaguid", value: aaguidFormatted, indent: indent, colorized: colorized)
        
        // Credential ID
        let credIdValue = formatHexData(credData.credentialId) + " (\(credData.credentialId.count) bytes)"
        let credIdFormatted = colorized ? formatValue(credIdValue, type: .hex, colorized: colorized) : credIdValue
        output += formatField("credentialId", value: credIdFormatted, indent: indent, colorized: colorized)
        
        // Credential Public Key (CBOR)
        output += formatField("credentialPublicKey", value: "", indent: indent, isContainer: true, colorized: colorized)
        output += prettyPrintCBORValue(credData.credentialPublicKey, indent: indent + 2, colorized: colorized)
        
        // Close container
        let parentIndentStr = String(repeating: " ", count: indent - 2)
        let credDataCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(parentIndentStr)\(credDataCloseBrace)\n"
        
        return output
    }
    
    private func prettyPrintAttStmt(_ attStmt: AttStmt, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        
        // Algorithm
        if let alg = attStmt.alg {
            let algFormatted = colorized ? formatValue("\(alg)", type: .number, colorized: colorized) : "\(alg)"
            output += formatField("alg", value: algFormatted, indent: indent, colorized: colorized)
        } else {
            let nilValue = colorized ? formatValue("nil", type: .nullValue, colorized: colorized) : "nil"
            output += formatField("alg", value: nilValue, indent: indent, colorized: colorized)
        }
        
        // Signature
        if !attStmt.signature.isEmpty {
            let sigValue = formatHexData(attStmt.signature) + " (\(attStmt.signature.count) bytes)"
            let sigFormatted = colorized ? formatValue(sigValue, type: .hex, colorized: colorized) : sigValue
            output += formatField("signature", value: sigFormatted, indent: indent, colorized: colorized)
        } else {
            let emptyValue = colorized ? formatValue("empty", type: .plain, colorized: colorized) : "empty"
            output += formatField("signature", value: emptyValue, indent: indent, colorized: colorized)
        }
        
        // Certificate Chain (x5c)
        output += formatField("x5c", value: "", indent: indent, isContainer: true, colorized: colorized)
        for (index, certDER) in attStmt.x5c.enumerated() {
            output += prettyPrintCertificate(certDER: certDER, index: index, totalCerts: attStmt.x5c.count, indent: indent + 2, colorized: colorized)
        }
        let x5cIndentStr = String(repeating: " ", count: indent)
        let x5cCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(x5cIndentStr)\(x5cCloseBrace)\n"
        
        // Raw CBOR
        output += formatField("rawCBOR", value: "", indent: indent, isContainer: true, colorized: colorized)
        output += prettyPrintCBORValue(attStmt.rawCBOR, indent: indent + 2, colorized: colorized)
        
        // Close attestationStatement container
        let parentIndentStr = String(repeating: " ", count: indent - 2)
        let attStmtCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        output += "\(parentIndentStr)\(attStmtCloseBrace)\n"
        
        return output
    }
    
    private func prettyPrintCBORValue(_ value: CBORValue, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        
        switch value {
        case .unsigned(let u):
            let numValue = colorized ? formatValue("\(u)", type: .number, colorized: colorized) : "\(u)"
            output += "\(indentStr)unsigned(\(numValue))\n"
            
        case .negative(let n):
            let numValue = colorized ? formatValue("\(n)", type: .number, colorized: colorized) : "\(n)"
            output += "\(indentStr)negative(\(numValue))\n"
            
        case .byteString(let data):
            let hexValue = formatHexData(data) + " (\(data.count) bytes)"
            let hexFormatted = colorized ? formatValue(hexValue, type: .hex, colorized: colorized) : hexValue
            output += "\(indentStr)byteString(\(hexFormatted))\n"
            
        case .textString(let s):
            let strValue = colorized ? formatValue("\"\(s)\"", type: .string, colorized: colorized) : "\"\(s)\""
            output += "\(indentStr)textString(\(strValue))\n"
            
        case .array(let arr):
            let arrayBracket = colorized ? "\(ANSIColor.separator)[\(ANSIColor.reset)" : "["
            output += "\(indentStr)array(\(arr.count) elements): \(arrayBracket)\n"
            for (index, elem) in arr.enumerated() {
                output += "\(indentStr)  [\(index)]:\n"
                // Recursively print element with proper indentation
                let elemStr = prettyPrintCBORValue(elem, indent: indent + 4, colorized: colorized)
                output += elemStr
            }
            let closeBracket = colorized ? "\(ANSIColor.separator)]\(ANSIColor.reset)" : "]"
            output += "\(indentStr)\(closeBracket)\n"
            
        case .map(let pairs):
            let mapBrace = colorized ? "\(ANSIColor.separator){\(ANSIColor.reset)" : "{"
            output += "\(indentStr)map(\(pairs.count) pairs): \(mapBrace)\n"
            for (key, val) in pairs {
                // Format key
                let keyStr: String
                switch key {
                case .textString(let s):
                    keyStr = colorized ? formatValue("\"\(s)\"", type: .string, colorized: colorized) : "\"\(s)\""
                case .unsigned(let u):
                    keyStr = colorized ? formatValue("\(u)", type: .number, colorized: colorized) : "\(u)"
                case .negative(let n):
                    keyStr = colorized ? formatValue("\(n)", type: .number, colorized: colorized) : "\(n)"
                default:
                    keyStr = "\(key)"
                }
                let keyFormatted = colorized ? "\(ANSIColor.fieldName)`\(keyStr)`\(ANSIColor.reset)" : "`\(keyStr)`"
                output += "\(indentStr)  \(keyFormatted):\n"
                // Recursively print value with proper indentation
                let valStr = prettyPrintCBORValue(val, indent: indent + 4, colorized: colorized)
                output += valStr
            }
            let mapCloseBrace = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
            output += "\(indentStr)\(mapCloseBrace)\n"
            
        case .tagged(let tag, let inner):
            let tagValue = colorized ? formatValue("\(tag)", type: .number, colorized: colorized) : "\(tag)"
            output += "\(indentStr)tagged(\(tagValue)):\n"
            // Recursively print inner value
            output += prettyPrintCBORValue(inner, indent: indent + 2, colorized: colorized)
            
        case .simple(let u):
            output += "\(indentStr)simple(\(u))\n"
            
        case .boolean(let b):
            let boolValue = colorized ? formatValue("\(b)", type: .boolean, colorized: colorized) : "\(b)"
            output += "\(indentStr)boolean(\(boolValue))\n"
            
        case .null:
            let nilValue = colorized ? formatValue("null", type: .nullValue, colorized: colorized) : "null"
            output += "\(indentStr)\(nilValue)\n"
            
        case .undefined:
            let undefValue = colorized ? formatValue("undefined", type: .nullValue, colorized: colorized) : "undefined"
            output += "\(indentStr)\(undefValue)\n"
        }
        
        return output
    }
    
    private func prettyPrintCertificate(certDER: Data, index: Int, totalCerts: Int, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        
        // Try to parse the certificate
        if let cert = try? X509Certificate.parse(der: certDER) {
            // Certificate parsed successfully - show decoded info
            let role = index == 0 ? " (leaf)" : index == totalCerts - 1 ? " (root)" : " (intermediate)"
            let certHeader = colorized ? 
                "\(ANSIColor.fieldName)`[\(index)]`\(ANSIColor.reset): Certificate\(role) [\(certDER.count) bytes]" :
                "`[\(index)]`: Certificate\(role) [\(certDER.count) bytes]"
            output += "\(indentStr)\(certHeader)\n"
            
            // Subject
            let subjectValue = cert.subject.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.subject.description
            let subjectFormatted = colorized ? formatValue(subjectValue, type: .string, colorized: colorized) : subjectValue
            output += "\(indentStr)  \(colorized ? "\(ANSIColor.fieldName)`Subject`\(ANSIColor.reset)" : "`Subject`"): \(subjectFormatted)\n"
            
            // Issuer
            let issuerValue = cert.issuer.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.issuer.description
            let issuerFormatted = colorized ? formatValue(issuerValue, type: .string, colorized: colorized) : issuerValue
            output += "\(indentStr)  \(colorized ? "\(ANSIColor.fieldName)`Issuer`\(ANSIColor.reset)" : "`Issuer`"): \(issuerFormatted)\n"
            
            // Extensions (decoded)
            let decodedExts = cert.decodedExtensions
            if !decodedExts.isEmpty {
                let extHeader = colorized ? 
                    "\(ANSIColor.fieldName)`extensions`\(ANSIColor.reset): \(ANSIColor.separator){\(ANSIColor.reset)" :
                    "`extensions`: {"
                output += "\(indentStr)  \(extHeader)\n"
                
                for (oid, ext) in decodedExts.sorted(by: { $0.key < $1.key }) {
                    output += prettyPrintExtension(oid: oid, ext: ext, indent: indent + 4, colorized: colorized)
                }
                
                let extClose = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
                output += "\(indentStr)  \(extClose)\n"
            }
        } else {
            // Failed to parse - show raw bytes
            let certValue = formatHexData(certDER.prefix(32)) + "... (\(certDER.count) bytes)"
            let certFormatted = colorized ? formatValue(certValue, type: .hex, colorized: colorized) : certValue
            output += formatField("[\(index)]", value: certFormatted, indent: indent, colorized: colorized)
        }
        
        return output
    }
    
    private func prettyPrintExtension(oid: String, ext: X509Extension, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        let name = X509OID.name(for: oid)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)`\(name)`\(ANSIColor.reset)" : "`\(name)`"
        
        switch ext {
        case .basicConstraints(let isCA, let pathLength):
            let value = "isCA: \(isCA)" + (pathLength.map { ", pathLength: \($0)" } ?? "")
            let valueFormatted = colorized ? formatValue(value, type: .plain, colorized: colorized) : value
            output += "\(indentStr)\(nameFormatted): \(valueFormatted)\n"
            
        case .keyUsage(let usages):
            let usageNames = usages.map { $0.name }.joined(separator: ", ")
            let valueFormatted = colorized ? formatValue(usageNames, type: .plain, colorized: colorized) : usageNames
            output += "\(indentStr)\(nameFormatted): \(valueFormatted)\n"
            
        case .extendedKeyUsage(let usages):
            let usageNames = usages.map { $0.name }.joined(separator: ", ")
            let valueFormatted = colorized ? formatValue(usageNames, type: .plain, colorized: colorized) : usageNames
            output += "\(indentStr)\(nameFormatted): \(valueFormatted)\n"
            
        case .subjectKeyIdentifier(let keyId):
            let keyIdHex = keyId.map { String(format: "%02x", $0) }.joined()
            let valueFormatted = colorized ? formatValue(keyIdHex, type: .hex, colorized: colorized) : keyIdHex
            output += "\(indentStr)\(nameFormatted): \(valueFormatted)\n"
            
        case .authorityKeyIdentifier(let keyId, let issuer, let serial):
            var parts: [String] = []
            if let keyId = keyId {
                let keyIdHex = keyId.map { String(format: "%02x", $0) }.joined()
                parts.append("Key ID: \(keyIdHex)")
            }
            if let issuer = issuer {
                parts.append("Issuer: \(issuer)")
            }
            if let serial = serial {
                let serialHex = serial.map { String(format: "%02x", $0) }.joined()
                parts.append("Serial: \(serialHex)")
            }
            let value = parts.joined(separator: ", ")
            let valueFormatted = colorized ? formatValue(value, type: .plain, colorized: colorized) : value
            output += "\(indentStr)\(nameFormatted): \(valueFormatted)\n"
            
        case .subjectAlternativeName(let names):
            let namesStr = names.map { $0.description }.joined(separator: ", ")
            let valueFormatted = colorized ? formatValue(namesStr, type: .plain, colorized: colorized) : namesStr
            output += "\(indentStr)\(nameFormatted): \(valueFormatted)\n"
            
        case .appleOID(_, let appleExt):
            output += "\(indentStr)\(nameFormatted): \(ANSIColor.separator){\(ANSIColor.reset)\n"
            output += prettyPrintAppleExtension(appleExt, indent: indent + 2, colorized: colorized)
            let extClose = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
            output += "\(indentStr)\(extClose)\n"
            
        case .unknown(_, let raw):
            let hexValue = formatHexData(raw.prefix(16)) + (raw.count > 16 ? "..." : "") + " (\(raw.count) bytes)"
            let valueFormatted = colorized ? formatValue(hexValue, type: .hex, colorized: colorized) : hexValue
            output += "\(indentStr)\(nameFormatted): \(valueFormatted) [raw]\n"
        }
        
        return output
    }
    
    private func prettyPrintAppleExtension(_ appleExt: AppleAppAttestExtension, indent: Int, colorized: Bool = false) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        
        switch appleExt.type {
        case .challenge(let hash):
            let hashValue = formatHexData(hash) + " (\(hash.count) bytes)"
            let hashFormatted = colorized ? formatValue(hashValue, type: .hex, colorized: colorized) : hashValue
            output += "\(indentStr)\(colorized ? "\(ANSIColor.fieldName)`challenge`\(ANSIColor.reset)" : "`challenge`"): \(hashFormatted)\n"
            
        case .receipt(let receipt):
            output += "\(indentStr)\(colorized ? "\(ANSIColor.fieldName)`receipt`\(ANSIColor.reset)" : "`receipt`"): \(ANSIColor.separator){\(ANSIColor.reset)\n"
            if let bundleID = receipt.bundleID {
                let valueFormatted = colorized ? formatValue(bundleID, type: .string, colorized: colorized) : bundleID
                output += "\(indentStr)  \(colorized ? "\(ANSIColor.fieldName)`bundleID`\(ANSIColor.reset)" : "`bundleID`"): \(valueFormatted)\n"
            }
            if let teamID = receipt.teamID {
                let valueFormatted = colorized ? formatValue(teamID, type: .string, colorized: colorized) : teamID
                output += "\(indentStr)  \(colorized ? "\(ANSIColor.fieldName)`teamID`\(ANSIColor.reset)" : "`teamID`"): \(valueFormatted)\n"
            }
            if let appVersion = receipt.appVersion {
                let valueFormatted = colorized ? formatValue(appVersion, type: .string, colorized: colorized) : appVersion
                output += "\(indentStr)  \(colorized ? "\(ANSIColor.fieldName)`appVersion`\(ANSIColor.reset)" : "`appVersion`"): \(valueFormatted)\n"
            }
            if let creationDate = receipt.receiptCreationDate {
                let dateStr = ISO8601DateFormatter().string(from: creationDate)
                let valueFormatted = colorized ? formatValue(dateStr, type: .string, colorized: colorized) : dateStr
                output += "\(indentStr)  \(colorized ? "\(ANSIColor.fieldName)`receiptCreationDate`\(ANSIColor.reset)" : "`receiptCreationDate`"): \(valueFormatted)\n"
            }
            if let expirationDate = receipt.receiptExpirationDate {
                let dateStr = ISO8601DateFormatter().string(from: expirationDate)
                let valueFormatted = colorized ? formatValue(dateStr, type: .string, colorized: colorized) : dateStr
                output += "\(indentStr)  \(colorized ? "\(ANSIColor.fieldName)`receiptExpirationDate`\(ANSIColor.reset)" : "`receiptExpirationDate`"): \(valueFormatted)\n"
            }
            let extClose = colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
            output += "\(indentStr)\(extClose)\n"
            
        case .keyPurpose(let purpose):
            let valueFormatted = colorized ? formatValue(purpose, type: .string, colorized: colorized) : purpose
            output += "\(indentStr)\(colorized ? "\(ANSIColor.fieldName)`keyPurpose`\(ANSIColor.reset)" : "`keyPurpose`"): \(valueFormatted)\n"
            
        case .environment(let env):
            let valueFormatted = colorized ? formatValue(env, type: .string, colorized: colorized) : env
            output += "\(indentStr)\(colorized ? "\(ANSIColor.fieldName)`environment`\(ANSIColor.reset)" : "`environment`"): \(valueFormatted)\n"
            
        case .osVersion(let version):
            let valueFormatted = colorized ? formatValue(version, type: .string, colorized: colorized) : version
            output += "\(indentStr)\(colorized ? "\(ANSIColor.fieldName)`osVersion`\(ANSIColor.reset)" : "`osVersion`"): \(valueFormatted)\n"
            
        case .deviceClass(let deviceClass):
            let valueFormatted = colorized ? formatValue(deviceClass, type: .string, colorized: colorized) : deviceClass
            output += "\(indentStr)\(colorized ? "\(ANSIColor.fieldName)`deviceClass`\(ANSIColor.reset)" : "`deviceClass`"): \(valueFormatted)\n"
            
        case .unknown(_, let raw):
            let hexValue = formatHexData(raw.prefix(16)) + (raw.count > 16 ? "..." : "") + " (\(raw.count) bytes)"
            let valueFormatted = colorized ? formatValue(hexValue, type: .hex, colorized: colorized) : hexValue
            output += "\(indentStr)\(colorized ? "\(ANSIColor.fieldName)`raw`\(ANSIColor.reset)" : "`raw`"): \(valueFormatted)\n"
        }
        
        return output
    }
}

