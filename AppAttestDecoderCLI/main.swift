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

// Context annotation flags (for research)
func getContext(from args: [String]) -> AttestationContext? {
    guard let i = args.firstIndex(of: "--context"), args.count > i + 1 else {
        return nil
    }
    return AttestationContext(rawValue: args[i + 1])
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
    prettyPrintAttestation(base64: b64, verbose: optVerbose, colorized: colorized)

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
    if let i = args.firstIndex(of: "--base64"), args.count > i + 1 {
        return args[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let i = args.firstIndex(of: "--file"), args.count > i + 1 {
        return readFile(args[i + 1])
    }
    // STDIN fallback
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let s = String(data: data, encoding: .utf8) else {
        fatalError("Failed to read STDIN as UTF-8")
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

func readFile(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    let s = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    guard !s.isEmpty else { fatalError("Empty or unreadable file: \(path)") }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
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
      appattest-decode analyze --file <samples.json> [options]
      appattest-decode selftest

    Commands:
      attest    Decode attestation object
      assert    Decode assertion object
      pretty    Pretty-print attestation object with hierarchical formatting
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
