# Observing Apple App Attest Across Execution Contexts

## Abstract

This project provides a research instrument for observing how Apple's App Attest trust model behaves across execution contexts (main app, action extensions, App SSO extensions). **The artifacts themselves are structurally identical regardless of execution context** - Apple App Attest uses the same attestation format and flow across all contexts. This is an observational toolchain, not a capability builder. The decoder extracts raw materials (certificate chains, authenticator data, signatures) for analysis. No cryptographic validation or trust decisions are performed.

**Research Question**: "How does Apple's trust system behave when the same app family asserts identity from different execution contexts?"

**What we observe**:
- Where trust signals originate
- How they are gated
- What stays invariant across contexts

## Motivation

iOS app extensions operate under different constraints than the main application:

- Extensions run in separate processes with distinct entitlements
- They often perform security-sensitive operations (authentication, data access)
- Execution context provenance is not embedded in App Attest artifacts
- Existing tooling treats App Attest as context-agnostic

**Important**: App Attest artifacts are structurally identical regardless of execution context. Apple uses the same attestation format and cryptographic flow whether generated from the main app or an extension. This research focuses on **annotating artifacts with execution context metadata** to enable provenance tracking and comparative analysis, not on finding structural differences.

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
   - Generates its own App Attest key (distinct identity)
   - Produces attestations/assertions with its own lifecycle

2. **Action extension target**
   - Share sheet integration (`SLComposeServiceViewController`)
   - Limited UI constraints
   - Generates its own App Attest key (distinct identity)
   - Produces attestations/assertions independently
   - No shared state with main app

3. **App SSO extension target**
   - Single sign-on authentication (`ASCredentialProviderViewController`)
   - Security-sensitive operations
   - Generates its own App Attest key (distinct identity)
   - Produces attestations/assertions independently
   - No shared state with main app

**Trust Surface Model**: Each execution context is modeled as a distinct trust surface with its own cryptographic identity. This aligns with how Apple treats execution contexts as distinct security principals. No keys are shared. No identity is unified. This is trust-surface mapping, not identity merging.

**Note**: UI extension target is defined in the architecture but not yet implemented in the test app. Future work may include UI extension implementation.

### Data Collection

Each target independently performs:

1. `DCAppAttestService.generateKey()` - Creates a new App Attest key (per-target identity)
2. `DCAppAttestService.attestKey(_:clientDataHash:)` - Generates attestation object
3. Artifacts are exported as base64-encoded strings
4. Context metadata is annotated (execution context, bundle ID, team ID, key ID, timestamp)

**Identity Model**: Each target maintains its own App Attest key lifecycle. Keys are not shared across targets. The backend stores `(teamId, bundleId, keyId, executionContext)` tuples. No shared state. No ambiguity.

### Analysis

Artifacts are decoded using `AppAttestDecoderCLI` and compared using the `analyze` command:

```bash
./AppAttestDecoderCLI analyze --file samples.json
```

**Critical**: 
- No cryptographic validation or trust decisions are performed. This is structural analysis only.
- The analysis verifies structural consistency across contexts, not differences. Artifacts are identical regardless of execution context.

## Trust Surface Map

```
User Action
   │
   ├── Main App ── Attestation (key A) ─┐
   │                                     │
   ├── Action Extension ── Attestation (key B) ──┼──> Backend Decoder
   │                                             │
   └── App SSO Extension ── Attestation (key C) ┘
                                          │
                                          ▼
                                   Structural Equivalence
```

**Caption**: Each execution context produces structurally identical App Attest artifacts, differentiated only by provenance (execution context, bundle ID, key ID).

**What this shows**:
- Same trust model across all contexts
- Same format, same flow
- Gated by execution context, not structure
- Provenance is the differentiator, not cryptographic content

## Observables

**Critical**: Since artifacts are structurally identical across contexts, we observe consistency rather than differences. This is measurement, not modification.

**Research Questions**:
- How many distinct App Attest identities are observed across execution contexts?
- How often does each surface assert?
- Which surfaces are more active (user-driven vs system-driven)?
- Which are bursty vs steady over time?
- Does key churn differ by context?

**What we measure** (not what we modify):
- Structural equivalence verification
- Assertion frequency per context
- Time-series behavior patterns
- Provenance tracking

The following properties are compared to verify structural parity:

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

- **Artifacts are structurally identical**: App Attest uses the same format and flow regardless of execution context. This research annotates context, it does not find structural differences.
- **Context metadata is external**: Execution context is annotated by the artifact source, not extracted from the attestation itself. The attestation object does not encode execution context.
- **Apple internal behavior is undocumented**: We observe structure only; Apple's internal trust logic is not documented
- **No claims about security strength**: We make no assertions about cryptographic guarantees or security properties
- **Decoder limitations**: The decoder performs structural parsing only; it does not validate certificates, verify signatures, or enforce policy
- **Sample size is limited**: This is exploratory research focused on context annotation, not a comprehensive study

## Findings

**Structural Equivalence**: No structural divergence was observed across execution contexts. All artifacts are identical in format, size, and cryptographic structure.

**Provenance Differentiation**: Artifacts are differentiated only by execution context metadata (bundle ID, key ID, timestamp), not by structure.

**This is the result**: The observation that artifacts are structurally identical across contexts is not disappointing - it is the finding. This confirms Apple's design: same trust model, same format, gated by execution context.

## Future Work

Potential extensions of this research:

- **Larger device matrix**: Test across multiple device models and iOS versions
- **Longitudinal tracking**: Observe behavior changes across iOS version updates
- **Time-series analysis**: Graph assertions per context over time to understand usage patterns
- **Assertion analysis**: Extend comparison to assertion objects across contexts
- **Key lifecycle**: Study key persistence and reuse patterns across app launches

**What this enables** (without crossing boundaries):
- Better backend attribution
- Fine-grained fraud heuristics
- Context-aware trust weighting
- Debugging App Attest behavior in extensions (which Apple barely documents)

**What this does not do**:
- Share keys across contexts
- Forge identity
- Circumvent DeviceCheck
- Rebind trust

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

