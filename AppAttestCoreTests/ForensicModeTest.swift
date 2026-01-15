//
//  ForensicModeTest.swift
//  AppAttestCoreTests
//
//  Created by Michael Danylchuk on 1/14/26.
//
//  Quick test to verify forensic mode works with real attestation

import XCTest
@testable import AppAttestCore

final class ForensicModeTest: XCTestCase {
    
    func testForensicModeWithRealAttestation() throws {
        let attestationBase64 = """
        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
        """
        
        guard let data = Data(base64Encoded: attestationBase64.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            XCTFail("Failed to decode base64")
            return
        }
        
        let decoder = AppAttestDecoder(teamID: nil)
        let attestation = try decoder.decodeAttestationObject(data)
        
        // Test forensic view
        let forensicMode = ForensicMode(showRaw: true, showDecoded: true, showJSON: false, colorized: false)
        let forensicOutput = attestation.forensicPrint(mode: forensicMode)
        
        // Verify output contains expected sections
        XCTAssertTrue(forensicOutput.contains("Attestation Object (Forensic View)"), "Should contain header")
        XCTAssertTrue(forensicOutput.contains("authenticatorData"), "Should contain authenticatorData")
        XCTAssertTrue(forensicOutput.contains("attestationStatement"), "Should contain attestationStatement")
        XCTAssertTrue(forensicOutput.contains("x5c"), "Should contain certificate chain")
        
        // Test JSON export
        let jsonMode = ForensicMode(showRaw: false, showDecoded: false, showJSON: true, colorized: false)
        let jsonOutput = attestation.forensicPrint(mode: jsonMode)
        
        // Verify JSON output
        XCTAssertTrue(jsonOutput.contains("\"type\""), "JSON should contain type field")
        XCTAssertTrue(jsonOutput.contains("\"format\""), "JSON should contain format field")
        XCTAssertTrue(jsonOutput.contains("\"authenticatorData\""), "JSON should contain authenticatorData")
        XCTAssertTrue(jsonOutput.contains("\"attestationStatement\""), "JSON should contain attestationStatement")
        
        // Verify certificate chain is present
        XCTAssertTrue(attestation.attestationStatement.x5c.count > 0, "Should have certificate chain")
        
        // Verify extensions are decoded
        if let firstCert = attestation.attestationStatement.x5c.first,
           let cert = try? X509Certificate.parse(der: firstCert) {
            let decodedExts = cert.decodedExtensions
            XCTAssertTrue(decodedExts.count > 0, "Should have decoded extensions")
            
            // Verify Apple extensions are present
            let hasAppleExt = decodedExts.keys.contains { X509OID.isAppleOID($0) }
            XCTAssertTrue(hasAppleExt, "Should have Apple extensions")
        }
        
        print("✅ Forensic mode test passed")
        print("   - Forensic view output length: \(forensicOutput.count) chars")
        print("   - JSON output length: \(jsonOutput.count) chars")
        print("   - Certificate chain length: \(attestation.attestationStatement.x5c.count)")
    }
}
