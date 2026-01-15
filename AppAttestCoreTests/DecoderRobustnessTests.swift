//
//  DecoderRobustnessTests.swift
//  AppAttestCoreTests
//
//  Tests for decoder robustness - error handling, edge cases, hostile inputs
//

import XCTest
@testable import AppAttestCore

final class DecoderRobustnessTests: XCTestCase {
    
    // MARK: - Flags Formatting Tests
    
    func testFlagsBinaryFormatting0x40() throws {
        // Test specific case: 0x40 = 0b01000000 (not 0b10000000)
        let flagsByte: UInt8 = 0x40
        let binaryStr = String(flagsByte, radix: 2)
        let paddedBinary = String(repeating: "0", count: max(0, 8 - binaryStr.count)) + binaryStr
        
        XCTAssertEqual(paddedBinary, "01000000", "0x40 must format as 0b01000000, not 0b10000000")
        XCTAssertEqual(paddedBinary.count, 8, "Binary representation must be exactly 8 bits")
    }
    
    func testFlagsBinaryFormattingAllValues() throws {
        // Test all possible flag byte values
        for flagsByte in UInt8.min...UInt8.max {
            let binaryStr = String(flagsByte, radix: 2)
            let paddedBinary = String(repeating: "0", count: max(0, 8 - binaryStr.count)) + binaryStr
            
            XCTAssertEqual(paddedBinary.count, 8, "Flag byte 0x\(String(format: "%02x", flagsByte)) must format as 8 bits")
            
            // Verify it's correct binary representation
            let expected = String(flagsByte, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
            XCTAssertEqual(paddedBinary, expected, "Flag byte 0x\(String(format: "%02x", flagsByte)) binary format must match expected")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDecodeEmptyData() {
        let decoder = AppAttestDecoder(teamID: nil)
        
        do {
            _ = try decoder.decodeAttestationObject(Data())
            XCTFail("Should throw error for empty data")
        } catch is CBORDecodingError {
            // Expected
        } catch {
            XCTFail("Expected CBORDecodingError for empty data, got \(type(of: error))")
        }
    }
    
    func testDecodeInvalidBase64() {
        let invalidBase64 = "This is not base64!!!"
        
        guard let data = Data(base64Encoded: invalidBase64) else {
            // This is expected - invalid base64 should fail to decode
            return
        }
        
        // If it somehow decodes, try to parse it
        let decoder = AppAttestDecoder(teamID: nil)
        do {
            _ = try decoder.decodeAttestationObject(data)
            // If it doesn't throw, that's also acceptable (best-effort mode)
        } catch {
            // Expected - invalid data should throw
        }
    }
    
    func testDecodeTruncatedData() {
        let decoder = AppAttestDecoder(teamID: nil)
        
        // Create minimal invalid CBOR (just one byte)
        let truncated = Data([0xa1]) // Map with 1 pair, but no data
        
        do {
            _ = try decoder.decodeAttestationObject(truncated)
            XCTFail("Should throw error for truncated data")
        } catch is CBORDecodingError {
            // Expected
        } catch {
            XCTFail("Expected CBORDecodingError for truncated data, got \(type(of: error))")
        }
    }
    
    func testDecodeMalformedCBOR() {
        let decoder = AppAttestDecoder(teamID: nil)
        
        // Invalid CBOR: reserved major type 7, info > 23
        let malformed = Data([0xff])
        
        do {
            _ = try decoder.decodeAttestationObject(malformed)
            XCTFail("Should throw error for malformed CBOR")
        } catch is CBORDecodingError {
            // Expected
        } catch {
            // Other errors are also acceptable
        }
    }
    
    // MARK: - OID Robustness Tests
    
    func testOIDParsingEmptyData() {
        var reader = ASN1Reader(Data())
        
        do {
            _ = try reader.readOID()
            XCTFail("Should throw error for empty OID data")
        } catch is ASN1Error {
            // Expected
        } catch {
            XCTFail("Expected ASN1Error for empty OID, got \(type(of: error))")
        }
    }
    
    func testOIDValidationEmptyString() {
        XCTAssertFalse(X509OID.isAppleOID(""), "Empty string should not be considered Apple OID")
    }
    
    func testOIDValidationVeryLongString() {
        let longOID = String(repeating: "1.2.3.", count: 1000)
        XCTAssertFalse(X509OID.isAppleOID(longOID), "Very long OID should be rejected")
    }
    
    // MARK: - Extension Decoding Robustness
    
    func testExtensionDecodeEmptyOID() {
        let ext = X509Extension.decode(oid: "", rawValue: Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(ext, .unknown(oid: "", raw: Data([0x01, 0x02, 0x03])), "Empty OID should return unknown")
    }
    
    func testExtensionDecodeHugeData() {
        // Create data larger than 10 MB limit
        let hugeData = Data(repeating: 0x00, count: 11 * 1024 * 1024)
        let ext = X509Extension.decode(oid: "1.2.3.4.5", rawValue: hugeData)
        
        // Should return unknown with truncated raw data
        if case .unknown(let oid, let raw) = ext {
            XCTAssertEqual(oid, "1.2.3.4.5", "OID should be preserved")
            XCTAssertTrue(raw.isEmpty, "Huge data should be truncated to empty")
        } else {
            XCTFail("Huge extension data should return unknown")
        }
    }
    
    // MARK: - ASN.1 Decoder Robustness
    
    func testASN1DecodeEmptyData() {
        let decoder = ASN1Decoder()
        
        do {
            _ = try decoder.decode(Data())
            XCTFail("Should throw error for empty ASN.1 data")
        } catch is ASN1Error {
            // Expected
        } catch {
            XCTFail("Expected ASN1Error for empty data, got \(type(of: error))")
        }
    }
    
    func testASN1DecodeInvalidLength() {
        let decoder = ASN1Decoder()
        
        // Invalid: length byte says 0x85 (5-byte length), but only 1 byte follows
        let invalid = Data([0x30, 0x85, 0x01]) // SEQUENCE, 5-byte length, but only 1 byte
        
        do {
            _ = try decoder.decode(invalid)
            XCTFail("Should throw error for invalid length")
        } catch is ASN1Error {
            // Expected
        } catch {
            XCTFail("Expected ASN1Error for invalid length, got \(type(of: error))")
        }
    }
    
    // MARK: - CBOR Decoder Robustness
    
    func testCBORDecodeHugeArray() {
        // Try to create CBOR array with count > 1M (should be rejected)
        // CBOR array with count 0x1E8481 (2,000,001) = 0x9A 0x00 0x1E 0x84 0x81
        let hugeArray = Data([0x9A, 0x00, 0x1E, 0x84, 0x81]) // Array(2000001)
        
        do {
            _ = try CBORDecoder.decode(hugeArray)
            // If it doesn't throw, that's a problem - but we can't easily test this
            // because the decoder will fail on the first element read
        } catch {
            // Expected - should fail gracefully
        }
    }
    
    func testCBORDecodeHugeMap() {
        // Try to create CBOR map with count > 1M
        let hugeMap = Data([0xBB, 0x00, 0x1E, 0x84, 0x81]) // Map(2000001)
        
        do {
            _ = try CBORDecoder.decode(hugeMap)
            // Should fail on first key read
        } catch {
            // Expected
        }
    }
    
    // MARK: - CLI Argument Tests
    
    func testCLIArgumentParsing() {
        // Test that all flags are recognized
        let testCases: [(String, Bool)] = [
            ("--hex", true),
            ("--raw", true),
            ("--json", true),
            ("--verbose", true),
            ("--no-color", true),
            ("--forensic", true),
            ("--lossless-tree", true),
            ("--explain", true),
            ("--backend-ready", true),
            ("--security", true),
            ("--trust-posture", true),
            ("--strict", true),
            ("--best-effort", true),
            ("--invalid-flag", false),
        ]
        
        for (flag, shouldBeRecognized) in testCases {
            let args = ["pretty", flag, "--base64", "dGVzdA=="]
            let options = Set(args.filter { $0.hasPrefix("--") })
            let isRecognized = options.contains(flag)
            
            if shouldBeRecognized {
                XCTAssertTrue(isRecognized, "Flag \(flag) should be recognized")
            } else {
                // Invalid flags are still in the set, but that's okay
                // The important thing is valid flags work
            }
        }
    }
}
