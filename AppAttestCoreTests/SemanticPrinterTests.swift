//
//  SemanticPrinterTests.swift
//  AppAttestCoreTests
//
//  Tests for SemanticPrinter - all output modes
//

import XCTest
@testable import AppAttestCore

final class SemanticPrinterTests: XCTestCase {
    
    private var testAttestation: AttestationObject {
        get throws {
            return try TestHelpers.loadTestAttestation()
        }
    }
    
    private var testSemanticModel: AttestationSemanticModel {
        get throws {
            return try TestHelpers.loadTestSemanticModel()
        }
    }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
            """
            
            let data = try XCTUnwrap(Data(base64Encoded: base64))
            let decoder = AppAttestDecoder(teamID: teamID)
            return try decoder.decodeAttestationObject(data)
        }
    }
    
    // MARK: - Semantic Printer Tests
    
    func testSemanticPrinterDefaultMode() throws {
        let model = try testSemanticModel
        
        let printer = SemanticPrinter(colorized: false)
        let output = printer.print(model)
        
        // Verify main sections are present
        XCTAssertTrue(output.contains("APPLE APP ATTEST"), "Should contain header")
        XCTAssertTrue(output.contains("IDENTITY"), "Should contain identity section")
        XCTAssertTrue(output.contains("TRUST CHAIN"), "Should contain trust chain section")
        
        // Verify no raw hex in default mode (should be collapsed)
        let fullHexPattern = #"[0-9a-f]{64,}"# // 64+ consecutive hex chars
        let regex = try NSRegularExpression(pattern: fullHexPattern, options: .caseInsensitive)
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        let matches = regex.matches(in: output, options: [], range: range)
        XCTAssertEqual(matches.count, 0, "Default mode should not contain full hex strings (should be collapsed)")
        
        // Verify collapsed hex format (first 12 + last 12)
        XCTAssertTrue(output.contains("…"), "Should contain ellipsis for collapsed hex")
    }
    
    func testSemanticPrinterWithInterpretation() throws {
        let model = try testSemanticModel
        
        let printer = SemanticPrinter(colorized: false, showInterpretation: true, showBackendReady: false, showTrustPosture: false)
        let output = printer.print(model)
        
        // Verify interpretation fields are present
        XCTAssertTrue(output.contains("status:"), "Should contain status field")
        XCTAssertTrue(output.contains("specOrigin:"), "Should contain specOrigin field")
        XCTAssertTrue(output.contains("stability:"), "Should contain stability field")
        XCTAssertTrue(output.contains("safeUse:"), "Should contain safeUse field")
        XCTAssertTrue(output.contains("interpretation:"), "Should contain interpretation field")
    }
    
    func testSemanticPrinterWithBackendReady() throws {
        let model = try testSemanticModel
        
        let printer = SemanticPrinter(colorized: false, showInterpretation: false, showBackendReady: true, showTrustPosture: false)
        let output = printer.print(model)
        
        // Verify backend readiness section
        XCTAssertTrue(output.contains("BACKEND READINESS"), "Should contain backend readiness section")
        XCTAssertTrue(output.contains("STORE:"), "Should contain STORE section")
        XCTAssertTrue(output.contains("VERIFY:"), "Should contain VERIFY section")
        XCTAssertTrue(output.contains("MONITOR:"), "Should contain MONITOR section")
        XCTAssertTrue(output.contains("REJECT IF:"), "Should contain REJECT IF section")
    }
    
    func testSemanticPrinterWithTrustPosture() throws {
        let model = try testSemanticModel
        
        let printer = SemanticPrinter(colorized: false, showInterpretation: false, showBackendReady: false, showTrustPosture: true)
        let output = printer.print(model)
        
        // Verify trust posture section
        XCTAssertTrue(output.contains("TRUST POSTURE"), "Should contain trust posture section")
        XCTAssertTrue(output.contains("attestationIntegrity"), "Should contain attestationIntegrity")
        XCTAssertTrue(output.contains("certificateChain"), "Should contain certificateChain")
        XCTAssertTrue(output.contains("keyType"), "Should contain keyType")
        XCTAssertTrue(output.contains("replayProtection"), "Should contain replayProtection")
        XCTAssertTrue(output.contains("overallPosture"), "Should contain overallPosture")
    }
    
    func testSemanticPrinterWithSecurityMode() throws {
        let model = try testSemanticModel
        
        // Security mode = all interpretation flags
        let printer = SemanticPrinter(colorized: false, showInterpretation: true, showBackendReady: true, showTrustPosture: true)
        let output = printer.print(model)
        
        // Verify all sections are present
        XCTAssertTrue(output.contains("TRUST POSTURE"), "Should contain trust posture")
        XCTAssertTrue(output.contains("BACKEND READINESS"), "Should contain backend readiness")
        XCTAssertTrue(output.contains("specOrigin:"), "Should contain interpretation fields")
    }
    
    // MARK: - Flags Formatting Tests
    
    func testFlagsBinaryFormatting() throws {
        let attestation = try testAttestation
        let flags = attestation.authenticatorData.flags
        let flagsByte = flags.rawValue
        
        // Test binary formatting: 0x40 should be 0b01000000
        let binaryStr = String(flagsByte, radix: 2)
        let paddedBinary = String(repeating: "0", count: max(0, 8 - binaryStr.count)) + binaryStr
        
        // Verify it's exactly 8 bits
        XCTAssertEqual(paddedBinary.count, 8, "Binary representation should be exactly 8 bits")
        
        // Verify correct binary representation
        let expectedBinary = String(flagsByte, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
        XCTAssertEqual(paddedBinary, expectedBinary, "Binary formatting should match expected")
        
        // Test specific case: 0x40 = 0b01000000
        if flagsByte == 0x40 {
            XCTAssertEqual(paddedBinary, "01000000", "0x40 should format as 0b01000000")
        }
        
        // Verify semantic printer formats flags correctly
        let attestation = try testAttestation
        let model = try attestation.buildSemanticModel()
        let printer = SemanticPrinter(colorized: false)
        let output = printer.print(model)
        
        // Should contain binary representation
        XCTAssertTrue(output.contains("0b"), "Should contain binary representation")
        XCTAssertTrue(output.contains(String(format: "0x%02x", flagsByte)), "Should contain hex representation")
    }
    
    // MARK: - Extension Decoding Tests
    
    func testExtensionTierLabeling() throws {
        let attestation = try testAttestation
        
        // Get first certificate
        guard let firstCertDER = attestation.attestationStatement.x5c.first,
              let cert = try? X509Certificate.parse(der: firstCertDER) else {
            XCTSkip("Test requires valid certificate")
            return
        }
        
        // Check that extensions are decoded
        let decodedExts = cert.decodedExtensions
        XCTAssertGreaterThan(decodedExts.count, 0, "Should have decoded extensions")
        
        // Verify Apple extensions are labeled correctly
        for (oid, ext) in decodedExts {
            if X509OID.isAppleOID(oid) {
                // Apple extensions should be decoded, not marked as unknown
                switch ext {
                case .appleOID:
                    // Good - Apple extension is decoded
                    break
                case .unknown:
                    XCTFail("Apple extension \(oid) should not be marked as unknown")
                default:
                    // Other decoded types are fine
                    break
                }
            }
        }
    }
    
    // MARK: - Receipt Parsing Tests
    
    func testReceiptParsing() throws {
        let attestation = try testAttestation
        
        // Extract receipt from attestation statement
        let receiptData = extractReceipt(from: attestation.attestationStatement.rawCBOR)
        
        guard let receipt = receiptData else {
            XCTSkip("Test requires receipt in attestation")
            return
        }
        
        // Verify receipt is not empty
        XCTAssertGreaterThan(receipt.count, 0, "Receipt should not be empty")
        
        // Try CMS parsing
        if let cms = try? CMSSignedData.parse(der: receipt) {
            // Verify CMS structure
            XCTAssertGreaterThanOrEqual(cms.version, 1, "CMS version should be >= 1")
            XCTAssertFalse(cms.digestAlgorithms.isEmpty, "Should have digest algorithms")
            XCTAssertFalse(cms.encapContentInfo.content.isEmpty, "Should have payload")
        }
        
        // Verify semantic model includes receipt
        let model = try attestation.buildSemanticModel()
        XCTAssertNotNil(model.receipt, "Semantic model should include receipt")
        
        if let receiptSection = model.receipt {
            XCTAssertGreaterThan(receiptSection.rawData.count, 0, "Receipt raw data should not be empty")
            XCTAssertFalse(receiptSection.containerType.isEmpty, "Receipt container type should be identified")
        }
    }
    
    private func extractReceipt(from cbor: CBORValue) -> Data? {
        guard case .map(let pairs) = cbor else { return nil }
        for (key, value) in pairs {
            if case .textString("receipt") = key, case .byteString(let data) = value {
                return data
            }
        }
        return nil
    }
}
