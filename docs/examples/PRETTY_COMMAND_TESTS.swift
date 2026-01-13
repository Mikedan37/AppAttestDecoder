//
//  PRETTY_COMMAND_TESTS.swift
//  AppAttestCoreTests
//
//  REFERENCE EXAMPLE - NOT COMPILED
//
//  This file contains reference unit tests for the `pretty` CLI command functionality.
//  Tests cover prettyPrint() method, colorization, error handling, and output formatting.
//
//  IMPORTANT: This file is NOT part of any Xcode target and is NOT compiled.
//  The actual tests live in AppAttestCoreTests/AppAttestCoreTests.swift.
//
//  This file is kept for reference purposes only.
//

import XCTest
@testable import AppAttestCore

final class PrettyCommandTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let teamID = "M7PB4PDJAS"
    
    /// Real device-generated attestation object for testing
    private let attestationObjectBase64 = """
        o2NmbXRvYXBwbGUtYXBwYXR0ZXN0Z2F0dFN0bXSiY3g1Y4JZBBIwggQOMIIDlKADAgECAgYBm7S3gl4wCgYIKoZIzj0EAwIwTzEjMCEGA1UEAwwaQXBwbGUgQXBwIEF0dGVzdGF0aW9uIENBIDExEzARBgNVBAoMCkFwcGxlIEluYy4xEzARBgNVBAgMCkNhbGlmb3JuaWEwHhcNMjYwMTEyMDAxODAzWhcNMjYwMTE1MDAxODAzWjCBkTFJMEcGA1UEAwxAZjBkYjYwMTk3YzI5YjJhY2MwMTA4YzkzODhjZjMwZTMxMWUwNTAwNjA0YzNlYTU0NjBiMjg2ZjVkZDc2OGExZjEaMBgGA1UECwwRQUFBIENlcnRpZmljYXRpb24xEzARBgNVBAoMCkFwcGxlIEluYy4xEzARBgNVBAgMCkNhbGlmb3JuaWEwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAASOyElKHwLO4pmfh0aK79f3ttcCM2dhfYyeh7ZPaRMHnRKeH9/0yrkMQA99KN7FR+pVLnmP1fJlFm3POvYnYWzLo4ICFzCCAhMwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCBPAwgZMGCSqGSIb3Y2QIBQSBhTCBgqQDAgEKv4kwAwIBAL+JMQMCAQC/iTIDAgEAv4kzAwIBAL+JNDUEM003UEI0UERKQVMuRGFueWxjaHVrU3R1ZGlvcy5BcHBBdHRlc3REZWNvZGVyVGVzdEFwcL+JNgMCAQS/iTcDAgEAv4k5AwIBAL+JOgMCAQC/iTsDAgEAqgMCAQAwgc0GCSqGSIb3Y2QIBwSBvzCBvL+KeAYEBDI2LjG/iFADAgECv4p5CQQHMS4wLjE5OL+KewcEBTIzQjg1v4p8BgQEMjYuMb+KfQYEBDI2LjG/in4DAgEAv4p/AwIBAL+LAAMCAQC/iwEDAgEAv4sCAwIBAL+LAwMCAQC/iwQDAgEBv4sFAwIBAL+LCg8EDTIzLjIuODUuMC4wLDC/iwsPBA0yMy4yLjg1LjAuMCwwv4sMDwQNMjMuMi44NS4wLjAsML+IAgoECGlwaG9uZW9zMDMGCSqGSIb3Y2QIAgQmMCShIgQg7hWQ3uzksYGpHczYCfkNHjswnbaHxBMcYZLCm+H80OUwWAYJKoZIhvdjZAgGBEswSaNHBEUwQwwCMTEwPTAKDANva2ShAwEB/zAJDAJvYaEDAQH/MAsMBG9zZ26hAwEB/zALDARvZGVsoQMBAf8wCgwDb2NroQMBAf8wCgYIKoZIzj0EAwIDaAAwZQIwaqpqxrXvmYIk3Yx3T8T+abI/cDsolQucQSdggNxnz2b/1qaPMc/rMGRprnLi4hnhAjEA2dGqsng8cyxeInnhkqLNbk6n2ArujMB7LTvOuQvw4iGwoBfvD9vdgiclcmQSlBMVWQJHMIICQzCCAcigAwIBAgIQCbrF4bxAGtnUU5W8OBoIVDAKBggqhkjOPQQDAzBSMSYwJAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwKQXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODM5NTVaFw0zMDAzMTMwMDAwMDBaME8xIzAhBgNVBAMMGkFwcGxlIEFwcCBBdHRlc3RhdGlvbiBDQSAxMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAErls3oHdNebI1j0Dn0fImJvHCX+8XgC3qs4JqWYdP+NKtFSV4mqJmBBkSSLY8uWcGnpjTY71eNw+/oI4ynoBzqYXndG6jWaL2bynbMq9FXiEWWNVnr54mfrJhTcIaZs6Zo2YwZDASBgNVHRMBAf8ECDAGAQH/AgEAMB8GA1UdIwQYMBaAFKyREFMzvb5oQf+nDKnl+url5YqhMB0GA1UdDgQWBBQ+410cBBmpybQx+IR01uHhV3LjmzAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwMDaQAwZgIxALu+iI1zjQUCz7z9Zm0JV1A1vNaHLD+EMEkmKe3R+RToeZkcmui1rvjTqFQz97YNBgIxAKs47dDMge0ApFLDukT5k2NlU/7MKX8utN+fXr5aSsq2mVxLgg35BDhveAe7WJQ5t2dyZWNlaXB0WQ+WMIAGCSqGSIb3Y2QIBwSBvzCBvL+KeAYEBDI2LjG/iFADAgECv4p5CQQHMS4wLjE5OL+KewcEBTIzQjg1v4p8BgQEMjYuMb+KfQYEBDI2LjG/in4DAgEAv4p/AwIBAL+LAAMCAQC/iwEDAgEAv4sCAwIBAL+LAwMCAQC/iwQDAgEBv4sFAwIBAL+LCg8EDTIzLjIuODUuMC4wLDC/iwsPBA0yMy4yLjg1LjAuMCwwv4sMDwQNMjMuMi44NS4wLjAsML+IAgoECGlwaG9uZW9zMDMGCSqGSIb3Y2QIAgQmMCShIgQg7hWQ3uzksYGpHczYCfkNHjswnbaHxBMcYZLCm+H80OUwWAYJKoZIhvdjZAgGBEswSaNHBEUwQwwCMTEwPTAKDANva2ShAwEB/zAJDAJvYaEDAQH/MAsMBG9zZ26hAwEB/zALDARvZGVsoQMBAf8wCgwDb2NroQMBAf8wCgYIKoZIzj0EAwIDaAAwZQIwaqpqxrXvmYIk3Yx3T8T+abI/cDsolQucQSdggNxnz2b/1qaPMc/rMGRprnLi4hnhAjEA2dGqsng8cyxeInnhkqLNbk6n2ArujMB7LTvOuQvw4iGwoBfvD9vdgiclcmQSlBMVWQJHMIICQzCCAcigAwIBAgIQCbrF4bxAGtnUU5W8OBoIVDAKBggqhkjOPQQDAzBSMSYwJAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwKQXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODM5NTVaFw0zMDAzMTMwMDAwMDBaME8xIzAhBgNVBAMMGkFwcGxlIEFwcCBBdHRlc3RhdGlvbiBDQSAxMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAErls3oHdNebI1j0Dn0fImJvHCX+8XgC3qs4JqWYdP+NKtFSV4mqJmBBkSSLY8uWcGnpjTY71eNw+/oI4ynoBzqYXndG6jWaL2bynbMq9FXiEWWNVnr54mfrJhTcIaZs6Zo2YwZDASBgNVHRMBAf8ECDAGAQH/AgEAMB8GA1UdIwQYMBaAFKyREFMzvb5oQf+nDKnl+url5YqhMB0GA1UdDgQWBBQ+410cBBmpybQx+IR01uHhV3LjmzAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwMDaQAwZgIxALu+iI1zjQUCz7z9Zm0JV1A1vNaHLD+EMEkmKe3R+RToeZkcmui1rvjTqFQz97YNBgIxAKs47dDMge0ApFLDukT5k2NlU/7MKX8utN+fXr5aSsq2mVxLgg35BDhveAe7WJQ5t2dyZWNlaXB0WQ+WMIAGCSqGSIb3Y2QIBwSBvzCBvL+KeAYEBDI2LjG/iFADAgECv4p5CQQHMS4wLjE5OL+KewcEBTIzQjg1v4p8BgQEMjYuMb+KfQYEBDI2LjG/in4DAgEAv4p/AwIBAL+LAAMCAQC/iwEDAgEAv4sCAwIBAL+LAwMCAQC/iwQDAgEBv4sFAwIBAL+LCg8EDTIzLjIuODUuMC4wLDC/iwsPBA0yMy4yLjg1LjAuMCwwv4sMDwQNMjMuMi44NS4wLjAsML+IAgoECGlwaG9uZW9zMDMGCSqGSIb3Y2QIAgQmMCShIgQg7hWQ3uzksYGpHczYCfkNHjswnbaHxBMcYZLCm+H80OUwWAYJKoZIhvdjZAgGBEswSaNHBEUwQwwCMTEwPTAKDANva2ShAwEB/zAJDAJvYaEDAQH/MAsMBG9zZ26hAwEB/zALDARvZGVsoQMBAf8wCgwDb2NroQMEggFoAQH/MAoGCCqGSM49BAMCA2gAMGUCMGqqasa175mCJN2Md0/E/mmyP3A7KJULnEEnYIDcZ89m/9amjzHP6zBkaa5y4uIZ4QIxANnRqrJ4PHMsXiJ54ZKizW5Op9gK7ozAey07zrkL8OIhsKAX7w/b3YInJXJkEpQTFTAoAgEEAgEBBCCCF4+x4Iuui8joMl0Ad5zGY5fkwpJWWqsJRtEk0Gu/hzBgAgEFAgEBBFhDaDlnUjMxb1J0Zjg2UVEyOFhYMGxyN2NUbTV5WE9tdEdDL3JMWEcrKy9jWTNUcWJQaHI1TG9uQ2hkS29ON01JVG5ENnIvVDhwUVZBejlSQndUeVNJQT09MA4CAQYCAQEEBkFUVEVTVDAPAgEHAgEBBAdzYW5kYm94MB8CAQwCAQEEFzIwMjYtMDEtMTNUMDA6MTg6MDQuMDFaMB8CARUCAQEEFzIwMjYtMDQtMTNUMDA6MTg6MDQuMDFaAAAAAAAAoIAwggOvMIIDVKADAgECAhBCBNMtTmPM37+D65ivVXYxMAoGCCqGSM49BAMCMHwxMDAuBgNVBAMMJ0FwcGxlIEFwcGxpY2F0aW9uIEludGVncmF0aW9uIENBIDUgLSBHMTEmMCQGA1UECwwdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxEzARBgNVBAoMCkFwcGxlIEluYy4xCzAJBgNVBAYTAlVTMB4XDTI1MDEyMjE4MjYxMVoXDTI2MDIxNzE5NTYwNFowWjE2MDQGA1UEAwwtQXBwbGljYXRpb24gQXR0ZXN0YXRpb24gRnJhdWQgUmVjZWlwdCBTaWduaW5nMRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJuGmJmX1OlG3Mu+RD8r9ykR00BrxC8fwiSrFQtF7pL6a9Ss9K0cHBGKTSTiPrdSgaJTiWG0KsOTiHuEH2MP7OOjggHYMIIB1DAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFNkX/ktnkDhLkvTbztVXgBQLjz3JMEMGCCsGAQUFBwEBBDcwNTAzBggrBgEFBQcwAYYnaHR0cDovL29jc3AuYXBwbGUuY29tL29jc3AwMy1hYWljYTVnMTAxMIIBHAYDVR0gBIIBEzCCAQ8wggELBgkqhkiG92NkBQEwgf0wgcMGCCsGAQUFBwICMIG2DIGzUmVsaWFuY2Ugb24gdGhpcyBjZXJ0aWZpY2F0ZSBieSBhbnkgcGFydHkgYXNzdW1lcyBhY2NlcHRhbmNlIG9mIHRoZSB0aGVuIGFwcGxpY2FibGUgc3RhbmRhcmQgdGVybXMgYW5kIGNvbmRpdGlvbnMgb2YgdXNlLCBjZXJ0aWZpY2F0ZSBwb2xpY3kgYW5kIGNlcnRpZmljYXRpb24gcHJhY3RpY2Ugc3RhdGVtZW50cy4wNQYIKwYBBQUHAgEWKWh0dHA6Ly93d3cuYXBwbGUuY29tL2NlcnRpZmljYXRlYXV0aG9yaXR5MB0GA1UdDgQWBBSbrrPFJWW8XMvY60qmR1GnKfDawjAOBgNVHQ8BAf8EBAMCB4AwDwYJKoZIhvdjZAwPBAIFADAKBggqhkjOPQQDAgNJADBGAiEA/lsJsgMpTepk85d+NDBRzDRTEblU78CoFeAFnkGcCTsCIQCOFA9A6Tf9h80SMXutbVhrIAAcrTRvuOcnh+aIsMYcgzCCAvkwggJ/oAMCAQICEFb7g9Qr/43DN5kjtVqubr0wCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTkwMzIyMTc1MzMzWhcNMzQwMzIyMDAwMDAwWjB8MTAwLgYDVQQDDCdBcHBsZSBBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSA1IC0gRzExJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJLOY719hrGrKAo7HOGv+wSUgJGs9jHfpssoNW9ES+Eh5VfdEo2NuoJ8lb5J+r4zyq7NBBnxL0Ml+vS+s8uDfrqjgfcwgfQwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBS7sN6hWDOImqSKmd6+veuv2sskqzBGBggrBgEFBQcBAQQ6MDgwNgYIKwYBBQUHMAGGKmh0dHA6Ly9vY3NwLmFwcGxlLmNvbS9vY3NwMDMtYXBwbGVyb290Y2FnMzA3BgNVHR8EMDAuMCygKqAohiZodHRwOi8vY3JsLmFwcGxlLmNvbS9hcHBsZXJvb3RjYWczLmNybDAdBgNVHQ4EFgQU2Rf+S2eQOEuS9NvO1VeAFAuPPckwDgYDVR0PAQH/BAQDAgEGMBAGCiqGSIb3Y2QGAgMEAgUAMAoGCCqGSM49BAMDA2gAMGUCMQCNb6afoeDk7FtOc4qSfz14U5iP9NofWB7DdUr+OKhMKoMaGqoNpmRt4bmT6NFVTO0CMGc7LLTh6DcHd8vV7HaoGjpVOz81asjF5pKw4WG+gElp5F8rqWzhEQKqzGHZOLdzSjCCAkMwggHJoAMCAQICCC3F/IjSxUuVMAoGCCqGSM49BAMDMGcxGzAZBgNVBAMMEkFwcGxlIFJvb3QgQ0EgLSBHMzEmMCQGA1UECwwdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxEzARBgNVBAoMCkFwcGxlIEluYy4xCzAJBgNVBAYTAlVTMB4XDTE0MDQzMDE4MTkwNloXDTM5MDQzMDE4MTkwNlowZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAASY6S89QHKk7ZMicoETHN0QlfHFo05x3BQW2Q7lpgUqd2R7X04407scRLV/9R+2MmJdyemEW08wTxFaAP1YWAyl9Q8sTQdHE3Xal5eXbzFc7SudeyA72LlU2V6ZpDpRCjGjQjBAMB0GA1UdDgQWBBS7sN6hWDOImqSKmd6+veuv2sskqzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAKBggqhkjOPQQDAwNoADBlAjEAg+nBxBZeGl00GNnt7/RsDgBGS7jfskYRxQ/95nqMoaZrzsID1Jz1k8Z0uGrfqiMVAjBtZooQytQN1E/NjUM+tIpjpTNu423aF7dkH8hTJvmIYnQ5Cxdby1GoDOgYA+eisigAADGB/jCB+wIBATCBkDB8MTAwLgYDVQQDDCdBcHBsZSBBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSA1IC0gRzExJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUwIQQgTTLU5jzN+/g+uYr1V2MTANBglghkgBZQMEAgEFADAKBggqhkjOPQQDAgRIMEYCIQCPr2p0SR0lHTNSXt0OlXyorYMBeXQs1F1FpTJwIym7xwIhAPjstLXgeel6aCkSMogT+QNVv/utQfYgMfQotbQEb0vJAAAAAAAAaGF1dGhEYXRhWKQRCbmwJQ6AQC9gxzBFDlUdqJfC7FG2E7efZjCOJNDJzkAAAAAAYXBwYXR0ZXN0ZGV2ZWxvcAAg8NtgGXwpsqzAEIyTiM8w4xHgUAYEw+pUYLKG9d12ih+lAQIDJiABIVggjshJSh8CzuKZn4dGiu/X97bXAjNnYX2Mnoe2T2kTB50iWCASnh/f9Mq5DEAPfSjexUfqVS55j9XyZRZtzzr2J2Fsyw==
        """
    
    private var decoder: AppAttestDecoder!
    private var attestation: AttestationObject!
    
    override func setUp() {
        super.setUp()
        decoder = AppAttestDecoder(teamID: teamID)
        
        let attestationData = try! XCTUnwrap(
            Data(base64Encoded: attestationObjectBase64),
            "Test attestation data should decode from base64"
        )
        attestation = try! decoder.decodeAttestationObject(attestationData)
    }
    
    // MARK: - Basic Functionality Tests
    
    /// Test that prettyPrint() produces non-empty output
    func testPrettyPrintProducesOutput() throws {
        let output = attestation.prettyPrint()
        
        XCTAssertFalse(
            output.isEmpty,
            "prettyPrint() should produce non-empty output"
        )
        XCTAssertGreaterThan(
            output.count,
            100,
            "prettyPrint() output should be substantial (>100 characters)"
        )
    }
    
    /// Test that prettyPrint() includes all major fields
    func testPrettyPrintIncludesAllFields() throws {
        let output = attestation.prettyPrint()
        
        // Verify main sections are present
        XCTAssertTrue(
            output.contains("format"),
            "prettyPrint() should include 'format' field"
        )
        XCTAssertTrue(
            output.contains("authenticatorData"),
            "prettyPrint() should include 'authenticatorData' section"
        )
        XCTAssertTrue(
            output.contains("attestationStatement"),
            "prettyPrint() should include 'attestationStatement' section"
        )
        XCTAssertTrue(
            output.contains("rpIdHash"),
            "prettyPrint() should include 'rpIdHash' field"
        )
        XCTAssertTrue(
            output.contains("flags"),
            "prettyPrint() should include 'flags' field"
        )
        XCTAssertTrue(
            output.contains("x5c"),
            "prettyPrint() should include 'x5c' certificate chain"
        )
    }
    
    // MARK: - Colorization Tests
    
    /// Test that colorized output contains ANSI escape codes
    func testPrettyPrintColorizedContainsANSICodes() throws {
        let colorizedOutput = attestation.prettyPrint(colorized: true)
        let plainOutput = attestation.prettyPrint(colorized: false)
        
        // Colorized output should contain ANSI escape sequences
        XCTAssertTrue(
            colorizedOutput.contains("\u{001B}"),
            "Colorized output should contain ANSI escape codes"
        )
        
        // Plain output should not contain ANSI escape sequences
        XCTAssertFalse(
            plainOutput.contains("\u{001B}"),
            "Non-colorized output should not contain ANSI escape codes"
        )
        
        // Colorized output should be longer (due to ANSI codes)
        XCTAssertGreaterThan(
            colorizedOutput.count,
            plainOutput.count,
            "Colorized output should be longer than plain output due to ANSI codes"
        )
    }
    
    /// Test that colorized output uses correct color scheme
    func testPrettyPrintColorScheme() throws {
        let output = attestation.prettyPrint(colorized: true)
        
        // Verify color codes are present (field names in cyan, etc.)
        // Note: We check for presence of ANSI codes, not specific colors
        // since the exact implementation may vary
        XCTAssertTrue(
            output.contains("\u{001B}[36m") || output.contains("\u{001B}[1;36m"),
            "Colorized output should include cyan color codes for field names"
        )
    }
    
    // MARK: - Formatting Tests
    
    /// Test that hex data is formatted with spaces every 4 bytes
    func testPrettyPrintHexFormatting() throws {
        let output = attestation.prettyPrint()
        
        // Find a hex string pattern (8 hex chars = 4 bytes, followed by space)
        let hexPattern = #"[0-9a-f]{8} [0-9a-f]{8}"#
        let regex = try NSRegularExpression(pattern: hexPattern, options: .caseInsensitive)
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        let matches = regex.matches(in: output, options: [], range: range)
        
        XCTAssertGreaterThan(
            matches.count,
            0,
            "prettyPrint() should format hex data with spaces every 4 bytes"
        )
    }
    
    /// Test that output has proper indentation hierarchy
    func testPrettyPrintIndentation() throws {
        let output = attestation.prettyPrint()
        let lines = output.components(separatedBy: .newlines)
        
        // Count lines with different indentation levels
        var indentedLines = 0
        for line in lines {
            if line.hasPrefix("  ") {  // 2-space indent
                indentedLines += 1
            }
        }
        
        XCTAssertGreaterThan(
            indentedLines,
            5,
            "prettyPrint() should have proper hierarchical indentation"
        )
    }
    
    /// Test that flags are displayed with both raw and interpreted values
    func testPrettyPrintFlagsDisplay() throws {
        let output = attestation.prettyPrint()
        
        XCTAssertTrue(
            output.contains("rawValue"),
            "prettyPrint() should display flags rawValue"
        )
        XCTAssertTrue(
            output.contains("userPresent"),
            "prettyPrint() should display userPresent flag"
        )
        XCTAssertTrue(
            output.contains("userVerified"),
            "prettyPrint() should display userVerified flag"
        )
    }
    
    // MARK: - Error Handling Tests
    
    /// Test that prettyPrint() handles empty attestation gracefully
    func testPrettyPrintHandlesEmptyFields() throws {
        // Create minimal attestation object
        let emptyAuthData = AuthenticatorData(
            rpIdHash: Data(count: 32),
            flags: AuthenticatorFlags(rawValue: 0),
            signCount: 0,
            attestedCredentialData: nil,
            extensions: nil,
            rawData: Data()
        )
        
        let emptyAttestation = AttestationObject(
            format: "apple-appattest",
            authenticatorData: emptyAuthData,
            attestationStatement: AttestationStatement(
                alg: nil,
                signature: nil,
                x5c: [],
                rawCBOR: .map([])
            )
        )
        
        let output = emptyAttestation.prettyPrint()
        
        // Should not crash and should produce some output
        XCTAssertFalse(
            output.isEmpty,
            "prettyPrint() should handle empty attestation without crashing"
        )
        XCTAssertTrue(
            output.contains("format"),
            "prettyPrint() should include format even for empty attestation"
        )
    }
    
    // MARK: - Integration Tests
    
    /// Test end-to-end: decode attestation and pretty print
    func testPrettyPrintEndToEnd() throws {
        // This test validates the full pipeline:
        // base64 -> Data -> AttestationObject -> prettyPrint()
        
        let attestationData = try XCTUnwrap(
            Data(base64Encoded: attestationObjectBase64),
            "Attestation data should decode from base64"
        )
        
        let decoded = try decoder.decodeAttestationObject(attestationData)
        let output = decoded.prettyPrint(colorized: false)
        
        // Verify output contains expected content
        XCTAssertTrue(
            output.contains("apple-appattest"),
            "Output should contain format 'apple-appattest'"
        )
        XCTAssertTrue(
            output.contains("authenticatorData"),
            "Output should contain authenticatorData section"
        )
        XCTAssertTrue(
            output.contains("attestationStatement"),
            "Output should contain attestationStatement section"
        )
        
        // Verify output is substantial
        XCTAssertGreaterThan(
            output.count,
            500,
            "Output should be substantial for real attestation object"
        )
    }
    
    /// Test that prettyPrint() output is deterministic
    func testPrettyPrintDeterministic() throws {
        let output1 = attestation.prettyPrint()
        let output2 = attestation.prettyPrint()
        
        XCTAssertEqual(
            output1,
            output2,
            "prettyPrint() should produce deterministic output"
        )
    }
    
    // MARK: - Performance Tests
    
    /// Test that prettyPrint() completes in reasonable time
    func testPrettyPrintPerformance() throws {
        measure {
            _ = attestation.prettyPrint()
        }
    }
}

