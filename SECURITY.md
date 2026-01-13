# Security Policy

## Supported Versions

We currently support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | Yes                |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email security concerns to the project maintainers (if contact information is available)
3. Alternatively, use GitHub's private vulnerability reporting feature if enabled

### What to Include

When reporting a vulnerability, please include:
- Description of the vulnerability
- Steps to reproduce (if applicable)
- Potential impact
- Suggested fix (if you have one)

### Response Time

We will acknowledge receipt of your report within 48 hours and provide an initial assessment within 7 days.

### Important Notes

**This project is a decoder library only.** It does not perform cryptographic validation or security checks. Security vulnerabilities in this project would typically relate to:
- Memory safety issues (buffer overflows, use-after-free)
- Denial of service (infinite loops, excessive memory allocation)
- Information disclosure (unintended data exposure)

**This project does NOT provide security validation.** If you are using this decoder in production, you must implement complete server-side validation as described in the [Security Notes](README.md#security-notes) section of the README.

### Non-Official Parser Scope

The ASN.1, CBOR, COSE, and X.509 parsing logic in this project:

- Is NOT a complete implementation of the respective standards (ASN.1/DER, CBOR, COSE, X.509)
- Is NOT a reference or authoritative parser for these standards
- Is NOT intended for general-purpose use outside of App Attest artifact decoding
- Exists solely to decode structures required for App Attest attestation and assertion artifacts

These parsers:

- Do not perform cryptographic verification
- Do not enforce trust or policy decisions
- Should not be used as a replacement for full-featured cryptographic libraries
- Are purpose-built for the specific encoding patterns found in App Attest artifacts

This project is not affiliated with or endorsed by Apple.

---

**Last Updated:** January 2026

