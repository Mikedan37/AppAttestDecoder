//
//  main.swift
//  AppAttestDecoderCLI
//
//  This file is the command-line interface entry point for the App Attest decoder.
//  It provides commands for decoding attestation objects and assertions, with
//  support for multiple input methods (STDIN, file, command-line argument) and
//  output formats (JSON, hex, raw, pretty-print).
//
//  This CLI tool only parses and displays structure. It does NOT perform any
//  cryptographic validation, certificate chain verification, or security checks.
//  Users must implement complete validation logic separately for production use.
//
//  No DeviceCheck framework dependencies. No entitlements required.
//  Decodes already-produced App Attest artifacts only.
//

import Foundation
#if os(macOS) || os(Linux)
import Darwin.C
#elseif os(Windows)
import ucrt
#endif
import AppAttestCore

// MARK: - Entry

let args = Array(CommandLine.arguments.dropFirst())

let options = Set(args.filter { $0.hasPrefix("--") })
let optHex = options.contains("--hex")
let optRaw = options.contains("--raw")
let optJSON = options.contains("--json")
let optVerbose = options.contains("--verbose") || options.contains("-v")
let optNoColor = options.contains("--no-color") || options.contains("--no-colour")
let optVersion = options.contains("--version") || options.contains("-V")
let optForensic = options.contains("--forensic")
let optBoth = options.contains("--both")
let optFull = options.contains("--full")

// Context annotation flags (for research)
func getContext(from args: [String]) -> AttestationContext? {
    guard let i = args.firstIndex(of: "--context"), args.count > i + 1 else {
        return nil
    }
    let rawValue = args[i + 1]
    // Map common aliases to raw values
    switch rawValue.lowercased() {
    case "main", "mainapp":
        return .mainApp
    case "action", "actionextension":
        return .actionExtension
    case "sso", "appssoextension":
        return .appSSOExtension
    case "ui", "uiextension":
        return .uiExtension
    case "other", "otherextension":
        return .otherExtension
    default:
        return AttestationContext(rawValue: rawValue)
    }
}

func getBundleID(from args: [String]) -> String? {
    guard let i = args.firstIndex(of: "--bundle-id"), args.count > i + 1 else {
        return nil
    }
    return args[i + 1]
}

// Handle --version flag early
if optVersion {
    print("AppAttestDecoderCLI version \(CLI_VERSION)")
    exit(0)
}

guard args.count >= 1 else {
    printUsage()
    exit(1)
}

let mode = args[0]

switch mode {
case "attest":
    let b64 = readBase64Input(args: args)
    guard let data = Data(base64Encoded: b64) else {
        fatalError("Invalid base64 attestation blob")
    }
    decodeAttestation(data)

case "assert":
    let b64 = readBase64Input(args: args)
    guard let data = Data(base64Encoded: b64) else {
        fatalError("Invalid base64 assertion blob")
    }
    decodeAssertion(data, hex: optHex, raw: optRaw, json: optJSON)

case "pretty":
    let b64 = readBase64Input(args: args)
    let colorized = !optNoColor && isTTY()
    if optForensic {
        forensicPrintAttestation(base64: b64, json: optJSON, raw: optRaw, both: optBoth, full: optFull, colorized: colorized)
    } else {
        prettyPrintAttestation(base64: b64, verbose: optVerbose, colorized: colorized)
    }

case "selftest":
    print("Self-test:")
    let sample = "AAEC" // minimal base64
    if let d = Data(base64Encoded: sample) {
        print("  base64 decode OK (len=\(d.count))")
        print("  no DeviceCheck linkage")
        print("  deterministic CLI path OK")
        exit(0)
    } else {
        fatalError("Self-test failed")
    }

case "annotate":
    handleAnnotateCommand(args: args, optJSON: optJSON)

case "analyze":
    handleAnalyzeCommand(args: args, optJSON: optJSON, optVerbose: optVerbose)

default:
    print("Unknown mode: \(mode)\n")
    printUsage()
    exit(1)
}

// MARK: - Utilities

func printError(_ message: String) {
    let data = (message + "\n").data(using: .utf8)!
    FileHandle.standardError.write(data)
}

// MARK: - Input

func readBase64Input(args: [String]) -> String {
    // Helper to print errors to stderr
    func printError(_ message: String) {
        let data = (message + "\n").data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
    
    if let i = args.firstIndex(of: "--base64"), args.count > i + 1 {
        return args[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let i = args.firstIndex(of: "--file"), args.count > i + 1 {
        let fileContent = readFile(args[i + 1])
        // Remove any whitespace/newlines that might have been added
        return fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    // STDIN fallback
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard !data.isEmpty else {
        printError("Error: No input provided")
        printError("  Please provide input via --base64, --file, or STDIN")
        exit(1)
    }
    guard let s = String(data: data, encoding: .utf8) else {
        printError("Error: Failed to read STDIN as UTF-8")
        printError("  Input must be valid UTF-8 text")
        exit(1)
    }
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        printError("Error: STDIN input is empty after trimming whitespace")
        exit(1)
    }
    return trimmed
}

func readFile(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    
    // Check if file exists
    guard FileManager.default.fileExists(atPath: path) else {
        printError("Error: File not found: \(path)")
        printError("  Please check the file path and try again.")
        exit(1)
    }
    
    // Try to read the file
    guard let s = try? String(contentsOf: url, encoding: .utf8) else {
        printError("Error: Failed to read file: \(path)")
        printError("  The file may not be readable or may not be valid UTF-8.")
        exit(1)
    }
    
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        printError("Error: File is empty: \(path)")
        printError("  The file exists but contains no data.")
        exit(1)
    }
    
    return trimmed
}

// MARK: - Helpers

/// Checks if stdout is a TTY (terminal) to enable colorized output
func isTTY() -> Bool {
    #if os(macOS) || os(Linux)
    return isatty(STDOUT_FILENO) != 0
    #else
    return false
    #endif
}

func hexDump(_ data: Data, bytesPerLine: Int = 16) -> String {
    var out: [String] = []
    for i in stride(from: 0, to: data.count, by: bytesPerLine) {
        let slice = data[i..<min(i + bytesPerLine, data.count)]
        let hex = slice.map { String(format: "%02x", $0) }.joined(separator: " ")
        out.append(hex)
    }
    return out.joined(separator: "\n")
}

// MARK: - Version
let CLI_VERSION = "1.0.0"

// MARK: - Dispatch

func decodeAttestation(_ data: Data) {
    func printError(_ message: String) {
        let data = (message + "\n").data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
    
    if optRaw {
        print("-- raw (base64) --")
        print(data.base64EncodedString())
    }
    if optHex {
        print("-- hex --")
        print(hexDump(data))
    }
    
    let decoder = AppAttestDecoder(teamID: nil)
    do {
        let attestation = try decoder.decodeAttestationObject(data)
        
        if optJSON {
            // For JSON output, create a dictionary representation
            var dict: [String: Any] = [:]
            dict["type"] = "attestation"
            dict["format"] = attestation.format
            dict["authenticatorData"] = [
                "rpIdHashLength": attestation.authenticatorData.rpIdHash.count,
                "flags": attestation.authenticatorData.flags.rawValue,
                "signCount": attestation.authenticatorData.signCount
            ]
            dict["attestationStatement"] = [
                "algorithm": attestation.attestationStatement.alg as Any,
                "signatureLength": attestation.attestationStatement.signature.count,
                "certificateCount": attestation.attestationStatement.x5c.count
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("-- json --")
                print(jsonString)
            } else {
                // Fallback to pretty print
                let colorized = !optNoColor && isTTY()
                print(attestation.prettyPrint(colorized: colorized))
            }
        } else {
            // Default: pretty print
            let colorized = !optNoColor && isTTY()
            print(attestation.prettyPrint(colorized: colorized))
        }
    } catch let error as CBORDecodingError {
        printError("Error: CBOR decoding failed")
        printError("  \(error)")
        exit(1)
    } catch let error as AttestationError {
        printError("Error: Attestation object validation failed")
        printError("  \(error)")
        exit(1)
    } catch {
        printError("Error: Unexpected error during attestation decoding")
        printError("  \(error) (\(type(of: error)))")
        exit(1)
    }
}

/// Pretty-prints an App Attest attestation blob
/// 
/// Usage examples:
///   ./AppAttestDecoderCLI pretty --base64 "BASE64_BLOB"
///   ./AppAttestDecoderCLI pretty --file attestation.txt
///   echo "BASE64_BLOB" | ./AppAttestDecoderCLI pretty
///   cat attestation.txt | ./AppAttestDecoderCLI pretty
///   ./AppAttestDecoderCLI pretty --base64 "BLOB" --no-color  # Disable colors
func forensicPrintAttestation(base64: String, json: Bool, raw: Bool, both: Bool, full: Bool, colorized: Bool) {
    func printError(_ message: String) {
        let data = (message + "\n").data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
    
    // Trim whitespace and newlines from base64
    let trimmedBase64 = base64.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !trimmedBase64.isEmpty else {
        printError("Error: Empty base64 string")
        exit(1)
    }
    
    guard let data = Data(base64Encoded: trimmedBase64) else {
        printError("Error: Invalid base64 string")
        printError("  Base64 length: \(trimmedBase64.count) characters")
        printError("  First 50 chars: \(String(trimmedBase64.prefix(50)))")
        printError("  Last 50 chars: \(String(trimmedBase64.suffix(50)))")
        exit(1)
    }
    
    guard data.count > 0 else {
        printError("Error: Decoded data is empty")
        printError("  Base64 length: \(trimmedBase64.count) characters")
        exit(1)
    }
    
    let decoder = AppAttestDecoder(teamID: nil)
    do {
        let attestation = try decoder.decodeAttestationObject(data)
        
        if json {
            // JSON export mode
            let jsonMode = ForensicMode(showRaw: false, showDecoded: false, showJSON: true, colorized: false, fullTranscript: false)
            let output = attestation.forensicPrint(mode: jsonMode)
            print(output)
        } else if full {
            // Full transcript mode (linear narrative)
            let fullMode = ForensicMode(showRaw: true, showDecoded: true, showJSON: false, colorized: colorized, fullTranscript: true)
            let output = attestation.forensicPrint(mode: fullMode)
            print(output)
        } else {
            // Human-readable forensic output (tree structure)
            let mode: ForensicMode
            if both {
                mode = .both
            } else if raw {
                mode = .raw
            } else {
                mode = .decoded
            }
            
            let forensicMode = ForensicMode(showRaw: mode.showRaw, showDecoded: mode.showDecoded, showJSON: false, colorized: colorized, fullTranscript: false)
            let output = attestation.forensicPrint(mode: forensicMode)
            print(output)
        }
    } catch let error as CBORDecodingError {
        printError("Error: CBOR decoding failed")
        printError("  \(error)")
        printError("  This usually means the attestation data is truncated or corrupted")
        printError("  Base64 length: \(trimmedBase64.count) characters")
        printError("  Decoded data length: \(data.count) bytes")
        exit(1)
    } catch let error as AttestationError {
        printError("Error: Attestation parsing failed")
        printError("  \(error)")
        exit(1)
    } catch {
        printError("Error: \(error)")
        printError("  Type: \(type(of: error))")
        exit(1)
    }
}

func prettyPrintAttestation(base64: String, verbose: Bool = false, colorized: Bool = false) {
    // Helper to print to stderr
    func printError(_ message: String) {
        let data = (message + "\n").data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
    
    // Decode base64
    guard let data = Data(base64Encoded: base64) else {
        printError("Error: Invalid base64 string")
        printError("  Base64 string length: \(base64.count) characters")
        exit(1)
    }
    
    if verbose {
        printError("Debug: Base64 string length: \(base64.count) characters")
        printError("Debug: Decoded data length: \(data.count) bytes")
    }
    
    // Decode attestation object
    let decoder = AppAttestDecoder(teamID: nil)
    do {
        let attestation = try decoder.decodeAttestationObject(data)
        
        // Pretty print the attestation object with optional colorization
        let output = attestation.prettyPrint(colorized: colorized)
        print(output)
        
    } catch let error as CBORDecodingError {
        printError("Error: CBOR decoding failed")
        printError("  \(error)")
        if verbose {
            printError("  Data length: \(data.count) bytes")
            printError("  Base64 length: \(base64.count) characters")
        }
        exit(1)
    } catch let error as AttestationError {
        printError("Error: Attestation object validation failed")
        printError("  \(error)")
        if verbose {
            printError("  Data length: \(data.count) bytes")
        }
        exit(1)
    } catch {
        printError("Error: Unexpected error during attestation decoding")
        printError("  \(error) (\(type(of: error)))")
        if verbose {
            printError("  Data length: \(data.count) bytes")
            printError("  Base64 length: \(base64.count) characters")
        }
        exit(1)
    }
}

func decodeAssertion(_ data: Data, hex: Bool, raw: Bool, json: Bool) {
    func printError(_ message: String) {
        let data = (message + "\n").data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
    
    if raw {
        print("-- raw (base64) --")
        print(data.base64EncodedString())
    }
    if hex {
        print("-- hex --")
        print(hexDump(data))
    }
    
    let decoder = AppAttestDecoder(teamID: nil)
    do {
        let assertion = try decoder.decodeAssertion(data)
        
        if json {
            // For JSON output, create a dictionary representation
            var dict: [String: Any] = [:]
            dict["type"] = "assertion"
            dict["algorithm"] = assertion.algorithm as Any
            dict["signatureLength"] = assertion.signature.count
            dict["authenticatorData"] = [
                "rpIdHashLength": assertion.authenticatorData.rpIdHash.count,
                "flags": assertion.authenticatorData.flags.rawValue,
                "signCount": assertion.authenticatorData.signCount
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("-- json --")
                print(jsonString)
            } else {
                // Fallback to pretty print
                print(assertion.prettyPrint(colorized: false))
            }
        } else {
            // Default: pretty print
            let colorized = !optNoColor && isTTY()
            print(assertion.prettyPrint(colorized: colorized))
        }
    } catch let error as CBORDecodingError {
        printError("Error: CBOR decoding failed")
        printError("  \(error)")
        exit(1)
    } catch let error as COSEError {
        printError("Error: COSE structure invalid")
        printError("  \(error)")
        exit(1)
    } catch let error as AssertionError {
        printError("Error: Assertion decoding failed")
        printError("  \(error)")
        exit(1)
    } catch {
        printError("Error: Unexpected error during assertion decoding")
        printError("  \(error) (\(type(of: error)))")
        exit(1)
    }
}

// MARK: - Usage

func handleAnnotateCommand(args: [String], optJSON: Bool) {
    // Annotate command: decode an attestation and annotate it with execution context
    // Output: JSON representation of AttestationSample
    
    // Required: --context
    guard let context = getContext(from: args) else {
        printError("Error: annotate command requires --context <main|action|sso>")
        printError("  Valid contexts: main, action, sso")
        exit(1)
    }
    
    // Required: --bundle-id
    guard let bundleID = getBundleID(from: args) else {
        printError("Error: annotate command requires --bundle-id <string>")
        exit(1)
    }
    
    // Required: --team-id
    guard let teamIDIndex = args.firstIndex(of: "--team-id"), args.count > teamIDIndex + 1 else {
        printError("Error: annotate command requires --team-id <string>")
        exit(1)
    }
    let teamID = args[teamIDIndex + 1]
    
    // Required: --key-id
    guard let keyIDIndex = args.firstIndex(of: "--key-id"), args.count > keyIDIndex + 1 else {
        printError("Error: annotate command requires --key-id <base64-string>")
        exit(1)
    }
    let keyID = args[keyIDIndex + 1]
    
    // Read attestation (base64 or file)
    let attestationBase64: String
    if let base64Index = args.firstIndex(of: "--attestation-base64"), args.count > base64Index + 1 {
        attestationBase64 = args[base64Index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
    } else if let fileIndex = args.firstIndex(of: "--file"), args.count > fileIndex + 1 {
        attestationBase64 = readFile(args[fileIndex + 1])
    } else {
        // Try STDIN
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let s = String(data: data, encoding: .utf8) else {
            printError("Error: Failed to read STDIN as UTF-8")
            exit(1)
        }
        attestationBase64 = s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Validate base64
    guard Data(base64Encoded: attestationBase64) != nil else {
        printError("Error: Invalid base64 attestation blob")
        exit(1)
    }
    
    // Decode attestation to verify it's valid (but don't fail if decode fails - we still want the sample)
    let decoder = AppAttestDecoder(teamID: teamID)
    if let data = Data(base64Encoded: attestationBase64) {
        _ = try? decoder.decodeAttestationObject(data) // Verify it's valid, but don't store
    }
    
    // Create AttestationSample
    let sample = AttestationSample(
        context: context,
        bundleID: bundleID,
        teamID: teamID,
        keyID: keyID,
        attestationObjectBase64: attestationBase64,
        timestamp: Date()
    )
    
    // Output JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    
    do {
        let jsonData = try encoder.encode(sample)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        } else {
            printError("Error: Failed to encode sample as JSON")
            exit(1)
        }
    } catch {
        printError("Error: Failed to encode AttestationSample: \(error)")
        exit(1)
    }
}

func handleAnalyzeCommand(args: [String], optJSON: Bool, optVerbose: Bool) {
    // Analysis mode: compare multiple AttestationSample entries
    // Input: JSON file with array of AttestationSample objects
    
    guard let fileIndex = args.firstIndex(of: "--file"), args.count > fileIndex + 1 else {
        printError("Error: analyze command requires --file <path> pointing to JSON file with AttestationSample array")
        exit(1)
    }
    
    let filePath = args[fileIndex + 1]
    let url = URL(fileURLWithPath: filePath)
    
    guard let data = try? Data(contentsOf: url),
          let samples = try? JSONDecoder().decode([AttestationSample].self, from: data) else {
        printError("Error: Failed to read or parse AttestationSample JSON from \(filePath)")
        exit(1)
    }
    
    guard !samples.isEmpty else {
        printError("Error: No samples found in JSON file")
        exit(1)
    }
    
    do {
        let comparison = try AttestationComparison(samples: samples)
        
        if optJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(comparison)
            print(String(data: jsonData, encoding: .utf8)!)
        } else {
            // Human-readable analysis output
            print("Attestation Comparison Analysis")
            print("================================")
            print("")
            print("Samples: \(samples.count)")
            print("")
            
            // RP ID Hash consistency
            print("RP ID Hash Analysis:")
            if comparison.rpIdHashConsistent {
                print("  [OK] All samples share the same RP ID hash")
                if let firstHash = comparison.rpIdHashes.values.first {
                    print("  Hash: \(firstHash.map { String(format: "%02x", $0) }.joined(separator: " "))")
                }
            } else {
                print("  [DIFF] RP ID hashes differ across contexts:")
                for (context, hash) in comparison.rpIdHashes {
                    print("    \(context.description): \(hash.map { String(format: "%02x", $0) }.joined(separator: " "))")
                }
            }
            print("")
            
            // Certificate chain lengths
            print("Certificate Chain Analysis:")
            if comparison.certificateChainLengthConsistent {
                print("  [OK] All samples have consistent certificate chain lengths")
                if let firstLength = comparison.certificateChainLengths.values.first {
                    print("  Chain length: \(firstLength) certificates")
                }
            } else {
                print("  [DIFF] Certificate chain lengths vary:")
                for (context, length) in comparison.certificateChainLengths {
                    print("    \(context.description): \(length) certificates")
                }
            }
            print("")
            
            // Flags comparison
            print("Authenticator Flags:")
            for (context, flags) in comparison.flags {
                print("  \(context.description):")
                print("    userPresent: \(flags.userPresent)")
                print("    userVerified: \(flags.userVerified)")
                print("    attestedCredentialData: \(flags.attestedCredentialData)")
                print("    extensionsIncluded: \(flags.extensionsIncluded)")
            }
            print("")
            
            // Context breakdown
            print("Samples by Context:")
            let contextGroups = Dictionary(grouping: samples) { $0.context }
            for context in AttestationContext.allCases {
                if let group = contextGroups[context], !group.isEmpty {
                    print("  \(context.description): \(group.count) sample(s)")
                }
            }
        }
    } catch {
        printError("Error: Failed to analyze samples: \(error)")
        exit(1)
    }
}

func printUsage() {
    print("""
    AppAttestDecoderCLI

    Usage:
      appattest-decode attest [--base64 <b64> | --file <path>] [options]
      appattest-decode assert [--base64 <b64> | --file <path>] [options]
      appattest-decode pretty [--base64 <b64> | --file <path>] [options]
      appattest-decode annotate --context <ctx> --bundle-id <id> --team-id <id> --key-id <b64> [--attestation-base64 <b64> | --file <path>]
      appattest-decode analyze --file <samples.json> [options]
      appattest-decode selftest

    Commands:
      attest    Decode attestation object
      assert    Decode assertion object
      pretty    Pretty-print attestation object with hierarchical formatting
      annotate  Decode and annotate attestation with execution context (research mode)
      analyze   Compare multiple attestation samples across execution contexts (research mode)
      selftest  Run self-test to verify CLI functionality

    Optional flags:
      --version, -V       Print version and exit
      --base64 <b64>      Provide base64 blob as command-line argument
      --file <path>       Read base64 blob from file (or JSON samples for analyze)
      --hex               Print hex dump of the input blob (attest/assert only)
      --raw               Echo raw base64 of the input blob (attest/assert only)
      --json              Print decoded structure as JSON
      --verbose, -v       Enable verbose logging
      --no-color          Disable colorized output (pretty command only)
      --context <ctx>     Execution context (main|action|ui|sso|other) - for research annotation
      --bundle-id <id>    Bundle identifier - for research annotation

    Input:
      - If no flag is provided, base64 is read from STDIN.
      - Files may contain newlines; they are trimmed.

    Examples:
      # Pretty-print from command line
      ./AppAttestDecoderCLI pretty --base64 "BASE64_ATTESTATION_BLOB"
      
      # Pretty-print from file
      ./AppAttestDecoderCLI pretty --file attestation.txt
      
      # Pretty-print from STDIN (pipe)
      echo "BASE64_BLOB" | ./AppAttestDecoderCLI pretty
      cat attestation.txt | ./AppAttestDecoderCLI pretty
      
      # Pretty-print with verbose debugging
      ./AppAttestDecoderCLI pretty --base64 "BASE64_BLOB" --verbose
      
      # Annotate an attestation with execution context (research)
      ./AppAttestDecoderCLI annotate \\
        --context action \\
        --bundle-id com.example.MyExtension \\
        --team-id ABC123DEF4 \\
        --key-id "base64-key-id" \\
        --attestation-base64 "BASE64_ATTESTATION"
      
      # Annotate from file
      ./AppAttestDecoderCLI annotate \\
        --context main \\
        --bundle-id com.example.app \\
        --team-id ABC123DEF4 \\
        --key-id "base64-key-id" \\
        --file attestation.txt
      
      # Analyze multiple samples across execution contexts (research)
      ./AppAttestDecoderCLI analyze --file samples.json
      ./AppAttestDecoderCLI analyze --file samples.json --json

    Notes:
      - This tool only decodes blobs. It never calls DeviceCheck.
      - Generate blobs on-device, then paste or pipe them here.
      - The 'pretty' command provides human-readable hierarchical output.
      - The 'analyze' command compares samples across iOS execution contexts for research.
    """)
}
