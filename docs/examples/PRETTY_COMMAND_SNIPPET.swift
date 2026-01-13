//
//  PRETTY_COMMAND_SNIPPET.swift
//  AppAttestDecoderCLI
//
//  REFERENCE EXAMPLE - NOT COMPILED
//
//  This file is a reference example showing the implementation of the `pretty` command
//  for pretty-printing App Attest attestation objects with colorization.
//
//  IMPORTANT: This file is NOT part of any Xcode target and is NOT compiled.
//  The actual implementation lives in AppAttestDecoderCLI/main.swift and
//  AppAttestCore/Attestation/AttestationObject+PrettyPrint.swift
//
//  This file is kept for reference purposes only.
//
//  Usage:
//    ./AppAttestDecoderCLI pretty --base64 "BASE64_BLOB"
//    ./AppAttestDecoderCLI pretty --file attestation.txt
//    echo "BASE64_BLOB" | ./AppAttestDecoderCLI pretty
//    ./AppAttestDecoderCLI pretty --base64 "BLOB" --no-color
//    ./AppAttestDecoderCLI pretty --base64 "BLOB" --verbose
//

import Foundation
#if os(macOS) || os(Linux)
import Darwin.C
#elseif os(Windows)
import ucrt
#endif
import AppAttestCore

// MARK: - Command Handler (add to switch statement in main.swift)

/*
case "pretty":
    let b64 = readBase64Input(args: args)
    let colorized = !optNoColor && isTTY()
    prettyPrintAttestation(base64: b64, verbose: optVerbose, colorized: colorized)
*/

// MARK: - Option Parsing (add to option parsing section)

/*
let optNoColor = options.contains("--no-color") || options.contains("--no-colour")
*/

// MARK: - TTY Detection

/// Checks if stdout is a TTY (terminal) to enable colorized output
/// Returns true if output is going to a terminal, false if piped to file/command
func isTTY() -> Bool {
    #if os(macOS) || os(Linux)
    return isatty(STDOUT_FILENO) != 0
    #else
    return false
    #endif
}

// MARK: - Input Reading

/// Reads base64 input from command-line arguments, file, or STDIN
/// Priority: --base64 > --file > STDIN
/// 
/// Usage:
///   readBase64Input(args: ["pretty", "--base64", "BASE64_STRING"])
///   readBase64Input(args: ["pretty", "--file", "path/to/file.txt"])
///   readBase64Input(args: ["pretty"])  // Reads from STDIN
func readBase64Input(args: [String]) -> String {
    // Method 1: Command-line argument --base64 "<BLOB>"
    if let i = args.firstIndex(of: "--base64"), args.count > i + 1 {
        return args[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Method 2: File input --file "path/to/blob.txt"
    if let i = args.firstIndex(of: "--file"), args.count > i + 1 {
        return readFile(args[i + 1])
    }
    
    // Method 3: STDIN fallback (for piping)
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let s = String(data: data, encoding: .utf8) else {
        fatalError("Failed to read STDIN as UTF-8")
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Reads base64 string from a file
func readFile(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    let s = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    guard !s.isEmpty else { 
        fatalError("Empty or unreadable file: \(path)") 
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Main Pretty Print Function

/// Pretty-prints an App Attest attestation blob with optional colorization
///
/// This function:
/// 1. Decodes the base64 string to Data
/// 2. Uses AppAttestDecoder to parse the attestation object
/// 3. Calls prettyPrint() on the decoded object
/// 4. Prints the formatted output to stdout
/// 5. Handles errors gracefully with descriptive messages
///
/// Color Scheme:
///   - Cyan: Field names (format, authenticatorData, etc.)
///   - Green: String values
///   - Yellow: Number values
///   - Magenta: Hex/byte array values
///   - Blue: Boolean values
///   - Red: Nil/null values
///   - Dark Gray: Separators (braces, brackets)
///
/// Usage examples:
///   ./AppAttestDecoderCLI pretty --base64 "BASE64_BLOB"
///   ./AppAttestDecoderCLI pretty --file attestation.txt
///   echo "BASE64_BLOB" | ./AppAttestDecoderCLI pretty
///   cat attestation.txt | ./AppAttestDecoderCLI pretty
///   ./AppAttestDecoderCLI pretty --base64 "BLOB" --no-color  # Disable colors
///   ./AppAttestDecoderCLI pretty --base64 "BLOB" --verbose    # Enable verbose logging
///
/// - Parameters:
///   - base64: Base64-encoded attestation blob string
///   - verbose: If true, prints debug information (base64 length, decoded length) to stderr
///   - colorized: If true, adds ANSI color codes for terminal output. Automatically disabled when piped.
///
/// - Note: Errors are printed to stderr, success output goes to stdout
func prettyPrintAttestation(base64: String, verbose: Bool = false, colorized: Bool = false) {
    // Helper to print errors to stderr (keeps stdout clean for pretty output)
    func printError(_ message: String) {
        let data = (message + "\n").data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
    
    // Step 1: Decode base64 string to Data
    guard let data = Data(base64Encoded: base64) else {
        printError("Error: Invalid base64 string")
        printError("  Base64 string length: \(base64.count) characters")
        printError("  Hint: Ensure the base64 string is complete and properly formatted")
        exit(1)
    }
    
    // Step 2: Verbose logging (if enabled) - prints to stderr
    if verbose {
        printError("Debug: Base64 string length: \(base64.count) characters")
        printError("Debug: Decoded data length: \(data.count) bytes")
    }
    
    // Step 3: Decode attestation object using AppAttestDecoder
    // Note: teamID can be nil for parsing-only (no validation)
    let decoder = AppAttestDecoder(teamID: nil)
    do {
        let attestation = try decoder.decodeAttestationObject(data)
        
        // Step 4: Pretty print with optional colorization
        let output = attestation.prettyPrint(colorized: colorized)
        print(output)  // Print to stdout
        
        // Success - exit with code 0
        exit(0)
        
    } catch let error as CBORDecodingError {
        // Handle CBOR decoding errors with detailed context
        printError("Error: CBOR decoding failed")
        printError("  \(error)")
        if verbose {
            printError("  Data length: \(data.count) bytes")
            printError("  Base64 length: \(base64.count) characters")
        }
        exit(1)
        
    } catch let error as AttestationError {
        // Handle attestation-specific errors (missing fields, invalid structure)
        printError("Error: Attestation decoding failed")
        printError("  \(error)")
        if verbose {
            printError("  Data length: \(data.count) bytes")
            printError("  Base64 length: \(base64.count) characters")
        }
        exit(1)
        
    } catch {
        // Handle unexpected errors with type information
        printError("Error: Unexpected error during attestation decoding")
        printError("  Message: \(error)")
        printError("  Type: \(type(of: error))")
        if verbose {
            printError("  Data length: \(data.count) bytes")
            printError("  Base64 length: \(base64.count) characters")
        }
        exit(1)
    }
}

// MARK: - Usage Documentation (add to printUsage() function)

/*
Pretty Command:
  pretty    Pretty-print attestation object with colorization
  
  Options:
    --base64 <b64>   Provide base64 blob as command-line argument
    --file <path>    Read base64 blob from file
    --verbose, -v    Enable verbose logging (prints blob lengths)
    --no-color       Disable colorized output
  
  Examples:
    # From command-line argument
    ./AppAttestDecoderCLI pretty --base64 "BASE64_BLOB"
    
    # From file
    ./AppAttestDecoderCLI pretty --file attestation.txt
    
    # From STDIN (piping)
    echo "BASE64_BLOB" | ./AppAttestDecoderCLI pretty
    cat attestation.txt | ./AppAttestDecoderCLI pretty
    
    # Disable colors
    ./AppAttestDecoderCLI pretty --base64 "BLOB" --no-color
    
    # Verbose mode
    ./AppAttestDecoderCLI pretty --base64 "BLOB" --verbose
*/

