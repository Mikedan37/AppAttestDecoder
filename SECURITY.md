# Security Policy

## Supported Versions

This tool is currently in active development. Security updates will be applied to the latest version.

## Reporting Security Issues

**This tool does not accept reports about "verification bugs" or "validation failures".**

This is an inspection tool, not a validator. It does not perform cryptographic verification, certificate chain validation, or make trust decisions. If you believe there is a security issue with App Attest itself, report it to Apple.

## Scope of Security Reports

We accept reports about:
- Memory safety issues in the decoder (buffer overflows, use-after-free)
- Denial of service vulnerabilities (malformed input causing crashes)
- Information disclosure (leaking unintended data in output)

We do not accept reports about:
- "The tool doesn't verify signatures" (by design)
- "The tool doesn't validate certificate chains" (by design)
- "The tool doesn't reject invalid attestations" (by design)
- "Apple changed a format and the decoder broke" (expected, will be fixed)

## Security Boundaries

**This tool does not make trust decisions.**
- It parses structure only
- It does not verify cryptographic signatures
- It does not validate certificate chains
- It does not check RP ID hashes or nonces

**This tool should not be used to gate production traffic.**
- Inspection results must not be used to accept or reject API requests
- All verification must happen server-side
- This tool is for debugging, analysis, and research

**If Apple changes formats, this tool will adapt but not guarantee semantics.**
- The decoder will be updated to parse new structures
- Decoded fields may change meaning or encoding
- Apple-private fields are explicitly unstable
- Do not hardcode expectations based on decoded output

## Security Model

This tool operates under the following security model:

1. **Inspection only** - Parse structure, expose raw materials
2. **No trust decisions** - Verification happens elsewhere
3. **Best-effort decoding** - Unknown structures are preserved, not discarded
4. **Explicit boundaries** - Clear documentation of what is and isn't done

If you need cryptographic verification or trust decisions, implement them separately using the raw materials exposed by this tool.
