//
//  SemanticPrinter.swift
//  AppAttestDecoderCLI
//
//  Semantic View printer - clean, readable, decoded meaning only
//  No raw bytes, no ASN.1 dumps, no hex unless it adds meaning
//

import Foundation

/// Semantic View Printer
/// Produces clean, human-readable output with decoded meaning only
public class SemanticPrinter {
    let colorized: Bool
    private var footnotes: [String] = []
    private var footnoteCounter: Int = 0
    private let showInterpretation: Bool
    private let showBackendReady: Bool
    private let showTrustPosture: Bool
    
    public init(colorized: Bool = false, showInterpretation: Bool = false, showBackendReady: Bool = false, showTrustPosture: Bool = false) {
        self.colorized = colorized
        self.showInterpretation = showInterpretation
        self.showBackendReady = showBackendReady
        self.showTrustPosture = showTrustPosture
    }
    
    /// Print semantic model in clean, readable format
    public func print(_ model: AttestationSemanticModel) -> String {
        var output = ""
        
        // Executive Summary
        output += printSummary(model.summary)
        output += "\n"
        
        // Trust Posture (if requested)
        if showTrustPosture {
            output += printTrustPosture(model)
            output += "\n"
        }
        
        // Identity
        output += printIdentity(model.identity)
        output += "\n"
        
        // Credential (if present)
        if let credential = model.credential {
            output += printCredential(credential)
            output += "\n"
        }
        
        // Trust Chain
        output += printTrustChain(model.trustChain)
        output += "\n"
        
        // Platform Claims
        output += printPlatformClaims(model.platformClaims)
        output += "\n"
        
        // Receipt (if present)
        if let receipt = model.receipt {
            output += printReceipt(receipt)
            output += "\n"
        }
        
        // Backend Readiness (if requested)
        if showBackendReady {
            output += printBackendReadiness(model)
            output += "\n"
        }
        
        // Footnotes (if any)
        if !footnotes.isEmpty {
            output += "\n"
            output += printFootnotes()
        }
        
        return output
    }
    
    // MARK: - Summary
    
    private func printSummary(_ summary: AttestationSemanticModel.SummarySection) -> String {
        var output = ""
        output += sectionHeader("APPLE APP ATTEST")
        output += twoColumn("Format", summary.format)
        output += twoColumn("Certificate Chain", "\(summary.certificateChainLength) certificate(s)")
        output += twoColumn("Receipt", summary.receiptPresent ? "Present" : "Not present")
        output += twoColumn("Attested Credential", summary.attestedCredentialPresent ? "Present" : "Not present")
        if let env = summary.environment {
            output += twoColumn("Environment", env)
        }
        output += twoColumn("Extensions", "\(summary.extensionCount.decoded + summary.extensionCount.opaque) total (\(summary.extensionCount.decoded) decoded, \(summary.extensionCount.opaque) opaque)")
        return output
    }
    
    // MARK: - Identity
    
    private func printIdentity(_ identity: AttestationSemanticModel.IdentitySection) -> String {
        var output = ""
        output += sectionHeader("IDENTITY")
        
        // RP ID Hash - compact format (no full hex/base64 in semantic view)
        let hexCompact = formatHexCompact(identity.rpIdHash.hex)
        let b64Compact = formatBase64Compact(identity.rpIdHash.base64)
        output += twoColumn("rpIdHash", "\(identity.rpIdHash.length) bytes (hex: \(hexCompact), b64: \(b64Compact))")
        addFootnote("RP ID hash is SHA-256 of the bundle identifier. Use --forensic for full hex/base64.")
        
        // Flags - format binary correctly (8 bits, left-padded)
        let flagsByte = identity.flags.rawByte
        let binaryStr = String(flagsByte, radix: 2)
        let paddedBinary = String(repeating: "0", count: max(0, 8 - binaryStr.count)) + binaryStr
        var flagParts: [String] = []
        if identity.flags.userPresent { flagParts.append("UP") }
        if identity.flags.userVerified { flagParts.append("UV") }
        if identity.flags.attestedCredentialData { flagParts.append("AT") }
        if identity.flags.extensionsIncluded { flagParts.append("ED") }
        let flagsDesc = flagParts.isEmpty ? "none" : flagParts.joined(separator: ", ")
        output += twoColumn("flags", "0x\(String(format: "%02x", flagsByte)) (0b\(paddedBinary)) [\(flagsDesc)]")
        
        // Sign Count
        output += twoColumn("signCount", identity.signCount.formatted)
        output += indent("  Significance: \(identity.signCount.significance)")
        addFootnote("Sign count increments with each use. Zero indicates first attestation.")
        
        return output
    }
    
    // MARK: - Credential
    
    private func printCredential(_ credential: AttestationSemanticModel.CredentialSection) -> String {
        var output = ""
        output += sectionHeader("CREDENTIAL")
        
        // AAGUID
        if let uuid = credential.aaguid.uuid {
            output += twoColumn("aaguid", uuid)
        } else {
            let hexCompact = formatHexCompact(credential.aaguid.hex)
            output += twoColumn("aaguid", "\(hexCompact) (\(credential.aaguid.length) bytes)")
        }
        addFootnote("AAGUID (Authenticator Attestation GUID) identifies the authenticator model.")
        
        // Credential ID - compact
        let credIdHex = formatHexCompact(credential.credentialId.hex)
        let credIdB64 = formatBase64Compact(credential.credentialId.base64)
        output += twoColumn("credentialId", "\(credential.credentialId.length) bytes (hex: \(credIdHex), b64: \(credIdB64))")
        
        // Public Key
        output += indent("publicKey:")
        if let kty = credential.publicKey.keyType {
            output += indent("  kty: \(kty)", level: 2)
        }
        if let alg = credential.publicKey.algorithm {
            output += indent("  alg: \(alg)", level: 2)
        }
        if let crv = credential.publicKey.curve {
            output += indent("  crv: \(crv)", level: 2)
        }
        if let x = credential.publicKey.xCoordinate {
            let hexCompact = formatHexCompact(x.hex)
            output += indent("  x: \(hexCompact) (\(x.length) bytes) 🔒", level: 2)
        }
        if let y = credential.publicKey.yCoordinate {
            let hexCompact = formatHexCompact(y.hex)
            output += indent("  y: \(hexCompact) (\(y.length) bytes) 🔒", level: 2)
        }
        
        if !credential.publicKey.unknownParameters.isEmpty {
            output += indent("  unknownParams: \(credential.publicKey.unknownParameters.count)", level: 2)
        }
        
        // Usage guidance (if requested)
        if showBackendReady || showInterpretation {
            let guidance = InterpretationLayer.interpretPublicKey(
                keyType: credential.publicKey.keyType,
                algorithm: credential.publicKey.algorithm,
                curve: credential.publicKey.curve
            )
            
            if !guidance.storage.isEmpty {
                output += indent("  usage:")
                for item in guidance.storage {
                    output += indent("    • \(item)", level: 3)
                }
                for item in guidance.verification {
                    output += indent("    • \(item)", level: 3)
                }
                for item in guidance.rotation {
                    output += indent("    • \(item)", level: 3)
                }
                for item in guidance.invalidation {
                    output += indent("    • \(item)", level: 3)
                }
            }
        }
        
        addFootnote("Public key coordinates are cryptographic material. 🔒 indicates opaque data. Use --forensic for full hex.")
        
        return output
    }
    
    // MARK: - Trust Chain
    
    private func printTrustChain(_ chain: AttestationSemanticModel.TrustChainSection) -> String {
        var output = ""
        output += sectionHeader("TRUST CHAIN")
        output += twoColumn("Structure", chain.chainStructure)
        output += "\n"
        
        for cert in chain.certificates {
            output += printCertificate(cert)
            output += "\n"
        }
        
        return output
    }
    
    private func printCertificate(_ cert: AttestationSemanticModel.CertificateInfo) -> String {
        var output = ""
        output += indent("Certificate [\(cert.index)] — \(cert.role):")
        
        // Subject - show CN if available, otherwise full DN
        let subjectCN = cert.subject.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.subject.fullDN
        output += indent("  subject: \(subjectCN)", level: 2)
        
        // Issuer - show CN if available
        let issuerCN = cert.issuer.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.issuer.fullDN
        output += indent("  issuer: \(issuerCN)", level: 2)
        
        // Serial Number - compact hex
        let serialCompact = formatHexCompact(cert.serialNumber)
        output += indent("  serial: \(serialCompact)", level: 2)
        
        // Signature Algorithm
        output += indent("  sigAlg: \(cert.signatureAlgorithm.name)", level: 2)
        
        // Public Key - compact
        var pubKeyDesc = cert.publicKey.algorithm
        if let type = cert.publicKey.type {
            pubKeyDesc += " (\(type))"
        }
        if let curve = cert.publicKey.curve {
            pubKeyDesc += ", \(curve)"
        }
        if let keySize = cert.publicKey.keySize {
            pubKeyDesc += ", \(keySize) bits"
        }
        output += indent("  publicKey: \(pubKeyDesc)", level: 2)
        
        // Validity - compact
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        let notBeforeShort = formatter.string(from: cert.validity.notBefore)
        let notAfterShort = formatter.string(from: cert.validity.notAfter)
        output += indent("  validity: \(notBeforeShort) to \(notAfterShort) (\(cert.validity.durationDays) days)", level: 2)
        
        // Extensions - show decoded content (compact)
        if !cert.extensions.isEmpty {
            output += indent("  extensions (\(cert.extensions.count)):", level: 2)
            for ext in cert.extensions {
                output += printExtension(ext, indent: 3)
            }
        }
        
        return output
    }
    
    // MARK: - Platform Claims
    
    private func printPlatformClaims(_ claims: AttestationSemanticModel.PlatformClaimsSection) -> String {
        var output = ""
        output += sectionHeader("PLATFORM CLAIMS")
        
        if let env = claims.environment {
            output += twoColumn("environment", env)
        }
        if let osVersion = claims.osVersion {
            output += twoColumn("osVersion", osVersion)
        }
        if let deviceClass = claims.deviceClass {
            output += twoColumn("deviceClass", deviceClass)
        }
        if let keyPurpose = claims.keyPurpose {
            output += twoColumn("keyPurpose", keyPurpose)
        }
        
        if claims.environment == nil && claims.osVersion == nil && claims.deviceClass == nil && claims.keyPurpose == nil {
            output += indent("No platform claims decoded")
        }
        
        return output
    }
    
    // MARK: - Extensions
    
    private func printExtension(_ ext: AttestationSemanticModel.ExtensionInfo, indent: Int) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        
        // Show OID and hex preview inline
        let hexPreview = formatHexPreview(ext.rawDER, firstBytes: 16, lastBytes: 8)
        output += "\(indentStr)• \(ext.name) (\(ext.oid))"
        if ext.critical {
            output += " [CRITICAL]"
        }
        output += " — \(hexPreview) (\(ext.rawLength) bytes)\n"
        
        if let decoded = ext.decoded {
            switch decoded {
            case .basicConstraints(let isCA, let pathLength):
                output += "\(indentStr)  isCA: \(isCA)"
                if let pl = pathLength {
                    output += ", pathLength: \(pl)"
                }
                output += "\n"
            case .keyUsage(let usages):
                let usageNames = usages.map { $0.name }.joined(separator: ", ")
                output += "\(indentStr)  \(usageNames)\n"
            case .extendedKeyUsage(let usages):
                let usageNames = usages.map { $0.name }.joined(separator: ", ")
                output += "\(indentStr)  \(usageNames)\n"
            case .subjectKeyIdentifier(let keyId):
                let hex = keyId.map { String(format: "%02x", $0) }.joined()
                let hexCompact = formatHexCompact(hex)
                output += "\(indentStr)  Key ID: \(hexCompact) (\(keyId.count) bytes)\n"
            case .authorityKeyIdentifier(let keyId, _, _):
                if let kid = keyId {
                    let hex = kid.map { String(format: "%02x", $0) }.joined()
                    let hexCompact = formatHexCompact(hex)
                    output += "\(indentStr)  Key ID: \(hexCompact)\n"
                }
            case .subjectAlternativeName(let names):
                for name in names.prefix(3) {
                    output += "\(indentStr)  \(name.description)\n"
                }
                if names.count > 3 {
                    output += "\(indentStr)  ... and \(names.count - 3) more\n"
                }
            case .appleChallenge(let hash):
                let hex = hash.map { String(format: "%02x", $0) }.joined()
                let hexCompact = formatHexCompact(hex)
                output += "\(indentStr)  Challenge: \(hexCompact) (\(hash.count) bytes)\n"
            case .appleReceipt(let receipt):
                if let bundleID = receipt.bundleID {
                    output += "\(indentStr)  Bundle ID: \(bundleID)\n"
                }
                if let teamID = receipt.teamID {
                    output += "\(indentStr)  Team ID: \(teamID)\n"
                }
            case .appleKeyPurpose(let purpose):
                output += "\(indentStr)  Purpose: \(purpose)\n"
            case .appleEnvironment(let env):
                output += "\(indentStr)  Environment: \(env)\n"
            case .appleOSVersion(let version):
                output += "\(indentStr)  OS Version: \(version)\n"
            case .appleDeviceClass(let deviceClass):
                output += "\(indentStr)  Device Class: \(deviceClass)\n"
            }
        } else {
            output += "\(indentStr)  [Opaque - \(ext.rawLength) bytes]\n"
        }
        
        return output
    }
    
    // MARK: - Receipt
    
    private func printReceipt(_ receipt: AttestationSemanticModel.ReceiptSection) -> String {
        var output = ""
        output += sectionHeader("RECEIPT")
        output += twoColumn("containerType", receipt.containerType)
        output += twoColumn("size", "\(receipt.rawData.count) bytes")
        
        // Enhanced ASN.1/CMS inspection
        let inspection = ReceiptASN1Inspector.inspect(receipt.rawData)
        
        if let cms = inspection.cmsStructure {
            output += twoColumn("cmsVersion", "\(cms.version)")
            output += twoColumn("digestAlgorithms", cms.digestAlgorithms.joined(separator: ", "))
            output += twoColumn("contentType", "\(cms.contentTypeName) (\(cms.contentType))")
            output += twoColumn("payloadSize", "\(cms.payloadSize) bytes")
            output += twoColumn("certificates", "\(cms.certificateCount)")
            output += twoColumn("signers", "\(cms.signerCount)")
        }
        
        // ASN.1 TLV tree (first few levels)
        if !inspection.asn1Tree.isEmpty {
            output += "\n"
            output += indent("ASN.1 Structure (top level):", level: 1)
            for node in inspection.asn1Tree.prefix(10) {
                let constructed = node.constructed ? " (constructed)" : ""
                output += indent("  \(node.path): \(node.tag) [offset: \(node.offset), length: \(node.length)]\(constructed)", level: 2)
                if !node.valueHexPreview.isEmpty && !node.constructed {
                    output += indent("    hex: \(node.valueHexPreview)", level: 3)
                }
            }
            if inspection.asn1Tree.count > 10 {
                output += indent("  ... and \(inspection.asn1Tree.count - 10) more nodes", level: 2)
            }
        }
        
        // Payload analysis
        if let payload = inspection.payloadAnalysis {
            output += "\n"
            output += twoColumn("payloadFormat", payload.detectedFormat)
            output += twoColumn("payloadSize", "\(payload.size) bytes")
            if !payload.structure.isEmpty {
                output += indent("Payload structure:", level: 1)
                for node in payload.structure.prefix(5) {
                    output += indent("  \(node.tag) [\(node.length) bytes]", level: 2)
                }
            }
        }
        
        switch receipt.structure {
        case .cms(let cms):
            output += indent("  version: \(cms.version)", level: 1)
            output += indent("  contentType: \(cms.contentTypeName)", level: 1)
            output += indent("  payloadSize: \(cms.payloadSize) bytes", level: 1)
            if !cms.certificates.isEmpty {
                output += indent("  certificates: \(cms.certificates.count)", level: 1)
            }
            if !cms.signers.isEmpty {
                output += indent("  signers: \(cms.signers.count)", level: 1)
            }
            if let payload = cms.payloadStructure {
                switch payload {
                case .asn1(let desc): output += indent("  payload: \(desc)", level: 1)
                case .cbor(let desc): output += indent("  payload: \(desc)", level: 1)
                case .plist(let desc): output += indent("  payload: \(desc)", level: 1)
                case .opaque(let desc): output += indent("  payload: ◻ \(desc)", level: 1)
                }
            }
        case .cbor(let cbor):
            output += indent("  type: \(cbor.majorType)", level: 1)
            output += indent("  structure: \(cbor.structure)", level: 1)
        case .asn1(let asn1):
            output += indent("  tag: \(asn1.tag)", level: 1)
            output += indent("  class: \(asn1.tagClass)", level: 1)
            output += indent("  length: \(asn1.length) bytes", level: 1)
        case .plist(let plist):
            output += indent("  format: \(plist.format)", level: 1)
        case .opaque(let reason):
            output += indent("  status: ◻ Opaque", level: 1)
            output += indent("  reason: \(reason)", level: 1)
        }
        
        // Receipt interpretation (if requested)
        if showInterpretation {
            let interpretation = InterpretationLayer.interpretReceipt(
                containerType: receipt.containerType,
                size: receipt.rawData.count,
                structure: nil
            )
            output += indent("  specOrigin: \(interpretation.specOrigin.rawValue)", level: 1)
            output += indent("  stability: \(interpretation.stability.rawValue)", level: 1)
            output += indent("  safeUse: \(interpretation.safeUse.rawValue)", level: 1)
            output += indent("  interpretation: \(interpretation.interpretation)", level: 1)
            output += indent("  safeOperation: \(interpretation.safeOperation)", level: 1)
        } else {
            // Even without interpretation, show better label
            output += indent("  note: Decoded structure, inner payload is Apple-private", level: 1)
        }
        
        addFootnote("Receipt is Apple-signed evidence blob. Use --lossless-tree for full structure dump.")
        
        return output
    }
    
    // MARK: - Formatting Helpers
    
    private func sectionHeader(_ title: String) -> String {
        if colorized {
            return "\n\(ANSIColor.header)\(title)\(ANSIColor.reset)\n"
        } else {
            return "\n\(title)\n"
        }
    }
    
    private func subsectionHeader(_ title: String) -> String {
        if colorized {
            return "\n\(ANSIColor.subsection)\(title)\(ANSIColor.reset)\n"
        } else {
            return "\n\(title)\n"
        }
    }
    
    private func twoColumn(_ key: String, _ value: String, keyWidth: Int = 18) -> String {
        let keyUpper = key.uppercased()
        let paddedKey = keyUpper.padding(toLength: keyWidth, withPad: " ", startingAt: 0)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)\(paddedKey)\(ANSIColor.reset)" : paddedKey
        return "\(nameFormatted) \(value)\n"
    }
    
    private func indent(_ text: String, level: Int = 1) -> String {
        let spaces = String(repeating: " ", count: level * 2)
        return "\(spaces)\(text)\n"
    }
    
    /// Format hex string with ellipsis for long values
    private func formatHexCompact(_ hex: String, maxLength: Int = 24) -> String {
        guard hex.count > maxLength else { return hex }
        let prefix = String(hex.prefix(12))
        let suffix = String(hex.suffix(12))
        return "\(prefix)…\(suffix)"
    }
    
    /// Format hex preview from Data (first N bytes + last M bytes)
    private func formatHexPreview(_ data: Data, firstBytes: Int = 16, lastBytes: Int = 8) -> String {
        guard data.count > firstBytes + lastBytes else {
            return data.map { String(format: "%02x", $0) }.joined()
        }
        let first = data.prefix(firstBytes).map { String(format: "%02x", $0) }.joined()
        let last = data.suffix(lastBytes).map { String(format: "%02x", $0) }.joined()
        return "\(first)…\(last)"
    }
    
    /// Format base64 string with ellipsis for long values
    private func formatBase64Compact(_ base64: String, maxLength: Int = 24) -> String {
        guard base64.count > maxLength else { return base64 }
        let prefix = String(base64.prefix(12))
        let suffix = String(base64.suffix(8))
        return "\(prefix)…\(suffix)"
    }
    
    private func addFootnote(_ text: String) {
        footnoteCounter += 1
        footnotes.append("[\(footnoteCounter)] \(text)")
    }
    
    private func printFootnotes() -> String {
        var output = ""
        output += sectionHeader("NOTES")
        for footnote in footnotes {
            output += "\(footnote)\n"
        }
        return output
    }
    
    // MARK: - Trust Posture
    
    private func printTrustPosture(_ model: AttestationSemanticModel) -> String {
        var output = ""
        output += sectionHeader("TRUST POSTURE")
        
        let posture = InterpretationLayer.assessTrustPosture(
            hasAttestation: true,
            certificateChainLength: model.summary.certificateChainLength,
            keyType: model.credential?.publicKey.keyType,
            signCount: model.identity.signCount.value,
            hasReceipt: model.receipt != nil,
            hasEnvironment: model.platformClaims.environment != nil
        )
        
        output += twoColumn("attestationIntegrity", posture.attestationIntegrity.rawValue)
        output += twoColumn("certificateChain", "\(posture.certificateChain.rawValue) (Apple Root)")
        output += twoColumn("keyType", posture.keyType.rawValue)
        output += twoColumn("replayProtection", "\(posture.replayProtection.rawValue) (signCount = \(model.identity.signCount.value))")
        output += twoColumn("receiptPresence", posture.receiptPresence.rawValue)
        output += twoColumn("environmentBinding", posture.environmentBinding.rawValue)
        output += "\n"
        output += twoColumn("overallPosture", posture.overallPosture.rawValue)
        
        if posture.suitableForHighRisk {
            output += indent("Suitable for high-risk operations")
        } else {
            output += indent("Review required before high-risk operations")
        }
        
        addFootnote("Trust posture is non-authoritative. Based on structural analysis, not cryptographic verification.")
        
        return output
    }
    
    // MARK: - Backend Readiness
    
    private func printBackendReadiness(_ model: AttestationSemanticModel) -> String {
        var output = ""
        output += sectionHeader("BACKEND READINESS")
        
        let readiness = InterpretationLayer.assessBackendReadiness(
            hasCredential: model.credential != nil,
            hasReceipt: model.receipt != nil,
            signCount: model.identity.signCount.value,
            hasEnvironment: model.platformClaims.environment != nil
        )
        
        if !readiness.store.isEmpty {
            output += indent("STORE:")
            for item in readiness.store {
                output += indent("  • \(item)", level: 2)
            }
            output += "\n"
        }
        
        if !readiness.verify.isEmpty {
            output += indent("VERIFY:")
            for item in readiness.verify {
                output += indent("  • \(item)", level: 2)
            }
            output += "\n"
        }
        
        if !readiness.monitor.isEmpty {
            output += indent("MONITOR:")
            for item in readiness.monitor {
                output += indent("  • \(item)", level: 2)
            }
            output += "\n"
        }
        
        if !readiness.reject.isEmpty {
            output += indent("REJECT IF:")
            for item in readiness.reject {
                output += indent("  • \(item)", level: 2)
            }
        }
        
        return output
    }
    
    // MARK: - ANSI Colors
    
    enum ANSIColor {
        static let header = "\u{001B}[1;37m"      // Bold white
        static let subsection = "\u{001B}[1;36m" // Bold cyan
        static let fieldName = "\u{001B}[36m"     // Cyan
        static let reset = "\u{001B}[0m"          // Reset
    }
}

