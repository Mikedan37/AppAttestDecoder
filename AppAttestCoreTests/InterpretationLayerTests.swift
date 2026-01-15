//
//  InterpretationLayerTests.swift
//  AppAttestCoreTests
//
//  Tests for InterpretationLayer - trust posture, usage guidance, opaque field interpretation
//

import XCTest
@testable import AppAttestCore

final class InterpretationLayerTests: XCTestCase {
    
    // MARK: - Trust Posture Tests
    
    func testTrustPostureAssessment() {
        let posture = InterpretationLayer.assessTrustPosture(
            hasAttestation: true,
            certificateChainLength: 3,
            keyType: "EC (2)",
            signCount: 0,
            hasReceipt: true,
            hasEnvironment: true
        )
        
        XCTAssertEqual(posture.attestationIntegrity, .strong)
        XCTAssertEqual(posture.certificateChain, .strong)
        XCTAssertEqual(posture.keyType, .hardwareBacked)
        XCTAssertEqual(posture.replayProtection, .good)
        XCTAssertEqual(posture.receiptPresence, .strong)
        XCTAssertEqual(posture.environmentBinding, .strong)
        XCTAssertEqual(posture.overallPosture, .strong)
        XCTAssertTrue(posture.suitableForHighRisk)
    }
    
    func testTrustPostureWithMissingReceipt() {
        let posture = InterpretationLayer.assessTrustPosture(
            hasAttestation: true,
            certificateChainLength: 2,
            keyType: "EC (2)",
            signCount: 0,
            hasReceipt: false,
            hasEnvironment: true
        )
        
        XCTAssertEqual(posture.receiptPresence, .missing)
        XCTAssertFalse(posture.suitableForHighRisk, "Should not be suitable for high-risk without receipt")
    }
    
    func testTrustPostureWithWeakChain() {
        let posture = InterpretationLayer.assessTrustPosture(
            hasAttestation: true,
            certificateChainLength: 1,
            keyType: "EC (2)",
            signCount: 0,
            hasReceipt: true,
            hasEnvironment: true
        )
        
        XCTAssertEqual(posture.certificateChain, .weak)
        XCTAssertEqual(posture.overallPosture, .weak, "Overall should be weak if chain is weak")
    }
    
    // MARK: - Usage Guidance Tests
    
    func testPublicKeyUsageGuidance() {
        let guidance = InterpretationLayer.interpretPublicKey(
            keyType: "EC (2)",
            algorithm: "ES256 (-7)",
            curve: "P-256 (1)"
        )
        
        XCTAssertFalse(guidance.storage.isEmpty, "Should provide storage guidance")
        XCTAssertFalse(guidance.verification.isEmpty, "Should provide verification guidance")
        XCTAssertFalse(guidance.rotation.isEmpty, "Should provide rotation guidance")
        XCTAssertFalse(guidance.invalidation.isEmpty, "Should provide invalidation guidance")
        
        // Verify specific guidance items
        XCTAssertTrue(guidance.storage.contains { $0.contains("device-bound") }, "Should mention device-bound storage")
        XCTAssertTrue(guidance.verification.contains { $0.contains("verify future assertions") }, "Should mention assertion verification")
    }
    
    // MARK: - Opaque Field Interpretation Tests
    
    func testAppleExtensionInterpretation() {
        let interpretation = InterpretationLayer.interpretOpaqueExtension(
            oid: "1.2.840.113635.100.8.5", // Receipt
            rawLength: 1000,
            structure: "CMS SignedData"
        )
        
        XCTAssertEqual(interpretation.specOrigin, .apple)
        XCTAssertEqual(interpretation.stability, .private)
        XCTAssertEqual(interpretation.safeUse, .preserve)
        XCTAssertTrue(interpretation.interpretation.contains("Apple"), "Should mention Apple")
        XCTAssertTrue(interpretation.interpretation.contains("decoded"), "Should indicate decoded structure")
    }
    
    func testUnknownExtensionInterpretation() {
        let interpretation = InterpretationLayer.interpretOpaqueExtension(
            oid: "1.2.3.4.5.6.7.8.9",
            rawLength: 100,
            structure: "ASN.1 SEQUENCE"
        )
        
        XCTAssertEqual(interpretation.specOrigin, .unknown)
        XCTAssertEqual(interpretation.stability, .undocumented)
        XCTAssertEqual(interpretation.safeUse, .auditOnly)
        XCTAssertTrue(interpretation.interpretation.contains("not recognized"), "Should indicate unknown")
    }
    
    func testReceiptInterpretation() {
        let interpretation = InterpretationLayer.interpretReceipt(
            containerType: "CMS/PKCS#7 SignedData",
            size: 5000,
            structure: "CMS SignedData"
        )
        
        XCTAssertEqual(interpretation.specOrigin, .apple)
        XCTAssertEqual(interpretation.stability, .private)
        XCTAssertEqual(interpretation.safeUse, .preserve)
        XCTAssertTrue(interpretation.interpretation.contains("Apple-signed"), "Should mention Apple-signed")
        XCTAssertTrue(interpretation.observedStructure.contains("CMS SignedData"), "Should identify CMS structure")
    }
    
    // MARK: - Backend Readiness Tests
    
    func testBackendReadinessWithCredential() {
        let readiness = InterpretationLayer.assessBackendReadiness(
            hasCredential: true,
            hasReceipt: true,
            signCount: 0,
            hasEnvironment: true
        )
        
        XCTAssertFalse(readiness.store.isEmpty, "Should provide storage guidance")
        XCTAssertFalse(readiness.verify.isEmpty, "Should provide verification guidance")
        XCTAssertFalse(readiness.monitor.isEmpty, "Should provide monitoring guidance")
        XCTAssertFalse(readiness.reject.isEmpty, "Should provide rejection criteria")
        
        // Verify specific items
        XCTAssertTrue(readiness.store.contains { $0.contains("Credential ID") }, "Should mention credential ID storage")
        XCTAssertTrue(readiness.verify.contains { $0.contains("RP ID hash") }, "Should mention RP ID hash verification")
        XCTAssertTrue(readiness.reject.contains { $0.contains("RP ID hash mismatch") }, "Should mention RP ID rejection")
    }
    
    func testBackendReadinessWithReplayProtection() {
        let readiness = InterpretationLayer.assessBackendReadiness(
            hasCredential: true,
            hasReceipt: false,
            signCount: 5,
            hasEnvironment: false
        )
        
        // Should mention signCount monitoring for non-zero values
        XCTAssertTrue(readiness.monitor.contains { $0.contains("signCount") }, "Should mention signCount monitoring")
        XCTAssertTrue(readiness.reject.contains { $0.contains("replay") }, "Should mention replay rejection")
    }
}
