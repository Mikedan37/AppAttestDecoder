//
//  LosslessTreeDumperTests.swift
//  AppAttestCoreTests
//
//  Tests for LosslessTreeDumper - CBOR nodes, ASN.1 TLVs, byte accounting
//

import XCTest
@testable import AppAttestCore

final class LosslessTreeDumperTests: XCTestCase {
    
    func testLosslessTreeDumpStructure() throws {
        let attestation = try TestHelpers.loadTestAttestation()
        
        let dumper = LosslessTreeDumper(colorized: false)
        let output = dumper.dump(attestation)
        
        // Verify output contains key sections
        XCTAssertTrue(output.contains("CBOR STRUCTURE"), "Should contain CBOR structure section")
        XCTAssertTrue(output.contains("CERTIFICATE CHAIN"), "Should contain certificate chain section")
        XCTAssertTrue(output.contains("LOSSLESS"), "Should contain lossless verification")
        
        // Verify CBOR nodes are counted
        XCTAssertTrue(output.contains("CBOR nodes"), "Should show CBOR node count")
        
        // Verify ASN.1 TLVs are counted
        XCTAssertTrue(output.contains("ASN.1 TLVs"), "Should show ASN.1 TLV count")
    }
    
    func testLosslessTreeDumpCBORNodes() throws {
        let attestation = try TestHelpers.loadTestAttestation()
        
        let dumper = LosslessTreeDumper(colorized: false)
        let output = dumper.dump(attestation)
        
        // Verify CBOR structure is present
        XCTAssertTrue(output.contains("map"), "Should contain CBOR map structures")
        XCTAssertTrue(output.contains("byteString"), "Should contain byte string structures")
        
        // Verify paths are shown
        XCTAssertTrue(output.contains("/"), "Should contain path separators")
    }
    
    func testLosslessTreeDumpASN1TLVs() throws {
        let attestation = try TestHelpers.loadTestAttestation()
        
        guard let firstCert = attestation.attestationStatement.x5c.first else {
            XCTSkip("Test requires certificate in chain")
            return
        }
        
        let dumper = LosslessTreeDumper(colorized: false)
        let output = dumper.dump(attestation)
        
        // Verify certificate TLV structure is present
        XCTAssertTrue(output.contains("SEQUENCE"), "Should contain ASN.1 SEQUENCE")
        XCTAssertTrue(output.contains("offset"), "Should show TLV offsets")
        XCTAssertTrue(output.contains("length"), "Should show TLV lengths")
    }
    
    func testLosslessTreeDumpByteAccounting() throws {
        let attestation = try TestHelpers.loadTestAttestation()
        
        let dumper = LosslessTreeDumper(colorized: false)
        let output = dumper.dump(attestation)
        
        // Verify byte accounting is present
        XCTAssertTrue(output.contains("bytes"), "Should show byte counts")
        XCTAssertTrue(output.contains("sha256"), "Should show SHA256 hashes")
        XCTAssertTrue(output.contains("base64"), "Should show base64 encoding")
    }
    
    func testLosslessTreeDumpReceipt() throws {
        let attestation = try TestHelpers.loadTestAttestation()
        
        let dumper = LosslessTreeDumper(colorized: false)
        let output = dumper.dump(attestation)
        
        // Receipt may or may not be present, but if it is, it should be dumped
        if output.contains("receipt") {
            XCTAssertTrue(output.contains("RECEIPT"), "Should contain receipt section if present")
        }
    }
    
    func testLosslessTreeDumpNoColor() throws {
        let attestation = try TestHelpers.loadTestAttestation()
        let attestation = try TestHelpers.loadTestAttestation()
        
        let dumper = LosslessTreeDumper(colorized: false)
        let output = dumper.dump(attestation)
        
        // Verify no ANSI color codes in output
        let ansiPattern = #"\x1b\[[0-9;]*m"#
        let regex = try NSRegularExpression(pattern: ansiPattern, options: [])
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        let matches = regex.matches(in: output, options: [], range: range)
        
        XCTAssertEqual(matches.count, 0, "No-color mode should not contain ANSI codes")
    }
}
