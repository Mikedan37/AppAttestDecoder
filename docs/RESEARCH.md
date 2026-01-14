# Observing Apple App Attest Across Execution Contexts

## Abstract

This project studies the structural properties of Apple App Attest artifacts when generated from different execution contexts (main app, action extensions, App SSO extensions). We decode and compare attestation objects without performing validation to understand how trust signals vary across runtime environments. The decoder extracts raw materials (certificate chains, authenticator data, signatures) for analysis. No cryptographic validation or trust decisions are performed. This research enables first-of-its-kind comparative analysis of App Attest behavior across iOS execution surfaces.

## Motivation

iOS app extensions operate under different constraints than the main application:

- Extensions run in separate processes with distinct entitlements
- They often perform security-sensitive operations (authentication, data access)
- Trust behavior across execution contexts is poorly documented
- Existing tooling treats App Attest as context-agnostic

This research identifies a blind spot: how do App Attest artifacts differ when generated from different execution contexts, and what does this reveal about Apple's trust surface architecture?

## Methodology

### Device and Environment

- **Physical device(s)**: [To be documented when samples are collected]
- **iOS version(s)**: [To be documented when samples are collected]
- **Xcode version**: 14.0+
- **Swift version**: 5.7+

### App Targets

A single container iOS app with App Attest capability enabled, containing:

1. **Main application target**
   - Full app lifecycle
   - Standard UI presentation
   - App Attest key generation and attestation
   - Reference implementation for comparison

2. **Action extension target**
   - Share sheet integration (`SLComposeServiceViewController`)
   - Limited UI constraints
   - Independent App Attest key generation
   - Generates attestation from within Share Sheet context
   - Saves artifacts to App Group container for analysis

3. **App SSO extension target**
   - Single sign-on authentication (`ASCredentialProviderViewController`)
   - Security-sensitive operations
   - Demonstrates trust delegation (uses assertions from main app)
   - Identity-adjacent trust surfaces
   - Non-primary execution context signaling

**Note**: UI extension target is defined in the architecture but not yet implemented in the test app. Future work may include UI extension implementation.

### Data Collection

Each target independently performs:

1. `DCAppAttestService.generateKey()` - Creates a new App Attest key
2. `DCAppAttestService.attestKey(_:clientDataHash:)` - Generates attestation object
3. Artifacts are exported as base64-encoded strings
4. Context metadata is annotated (execution context, bundle ID, team ID, key ID, timestamp)

### Analysis

Artifacts are decoded using `AppAttestDecoderCLI` and compared using the `analyze` command:

```bash
./AppAttestDecoderCLI analyze --file samples.json
```

**Critical**: No cryptographic validation or trust decisions are performed. This is structural analysis only.

## Trust Surface Map

```
┌─────────────────┐
│   Main App      │ ─┐
│   (Full UI)     │  │
└─────────────────┘  │
                     │
┌─────────────────┐  │
│ Action Extension│  │
│ (Share Sheet)   │  ├──> App Attest Artifact ──> Decoder ──> Observables
└─────────────────┘  │
                     │
┌─────────────────┐  │
│  UI Extension   │  │
│  (Widget/UI)    │  │
└─────────────────┘  │
                     │
┌─────────────────┐  │
│ App SSO Ext     │ ─┘
│ (Auth)          │
└─────────────────┘

Each execution context:
- Runs in separate process
- Has distinct entitlements
- May generate independent keys
- Produces structurally identical attestation objects
```

## Observables

The following properties are compared across execution contexts:

### Authenticator Data

- **Flags**: `userPresent`, `userVerified`, `attestedCredentialData`, `extensionsIncluded`
- **RP ID hash**: SHA256 of bundle identifier (should be consistent for same app)
- **Sign count**: Initial counter value
- **AAGUID**: Authenticator attestation GUID

### Certificate Chain

- **Chain length**: Number of certificates in `x5c` array
- **Leaf certificate**: First certificate in chain
- **Issuer chain**: Intermediate and root certificates
- **Certificate extensions**: OIDs and values present

### Attestation Statement

- **Algorithm**: COSE algorithm identifier (typically -7 for ES256)
- **Signature**: Raw signature bytes (not verified)
- **Format**: Attestation format identifier (typically "apple-appattest")

### Key Characteristics

- **Key ID stability**: Whether keys are reused or regenerated per context
- **Key ID format**: Base64 encoding and length
- **Artifact size**: Total attestation object size in bytes

### Temporal Properties

- **Timestamp**: When attestation was generated (if available)
- **Nonce presence**: Whether nonce/challenge is embedded in certificate extensions

## Limitations

This research has several important constraints:

- **Apple internal behavior is undocumented**: We observe structure only; Apple's internal trust logic is not documented
- **Results may vary by OS version**: Different iOS versions may exhibit different behavior
- **Sample size is limited**: This is exploratory research, not a comprehensive study
- **No claims about security strength**: We make no assertions about cryptographic guarantees or security properties
- **Decoder limitations**: The decoder performs structural parsing only; it does not validate certificates, verify signatures, or enforce policy
- **Context metadata is external**: Execution context is annotated by the artifact source, not extracted from the attestation itself

## Future Work

Potential extensions of this research:

- **Larger device matrix**: Test across multiple device models and iOS versions
- **Longitudinal tracking**: Observe behavior changes across iOS version updates
- **Policy engines**: Build validation and policy engines on top of decoded artifacts
- **Assertion analysis**: Extend comparison to assertion objects across contexts
- **Key lifecycle**: Study key persistence and reuse patterns across app launches

## Data Format

Samples are stored as JSON arrays of `AttestationSample` objects:

```json
[
  {
    "context": "main",
    "bundleID": "com.example.app",
    "teamID": "ABC123DEF4",
    "keyID": "base64-encoded-key-id",
    "attestationObjectBase64": "base64-encoded-attestation",
    "timestamp": "2026-01-13T00:00:00Z"
  }
]
```

## Analysis Output

The `analyze` command produces:

- **RP ID hash consistency**: Whether all samples share the same RP ID hash
- **Certificate chain comparison**: Chain lengths and structure across contexts
- **Flag patterns**: Authenticator flags across different execution contexts
- **Context breakdown**: Sample counts per execution context

Output is available in human-readable or JSON format.

## References

- [Apple App Attest Documentation](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations)
- [WebAuthn Specification](https://www.w3.org/TR/webauthn-2/)
- [CBOR Specification (RFC 8949)](https://www.rfc-editor.org/rfc/rfc8949.html)
- [COSE Specification (RFC 8152)](https://www.rfc-editor.org/rfc/rfc8152.html)

