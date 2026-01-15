//
//  DecoderConfiguration.swift
//  AppAttestCore
//
//  Failsafe configuration for decoders to prevent resource exhaustion and handle hostile inputs
//

import Foundation

/// Configuration for decoder failsafes to prevent resource exhaustion and handle hostile inputs
public struct DecoderConfiguration {
    /// Maximum recursion depth for nested structures (CBOR maps/arrays, ASN.1 SEQUENCE)
    public let maxRecursionDepth: Int
    
    /// Maximum total bytes to process (prevents DoS from huge inputs)
    public let maxTotalBytes: Int
    
    /// Maximum size for a single container (map, array, byte string)
    public let maxContainerSize: Int
    
    /// Decoding mode: strict (fail on unknown) vs best-effort (preserve unknown)
    public let mode: DecodingMode
    
    /// Whether to enforce strict schema validation
    public let strictSchema: Bool
    
    public enum DecodingMode {
        /// Strict mode: fail on unexpected structures or unknown fields
        case strict
        
        /// Best-effort mode: preserve unknown fields, annotate uncertainty, continue decoding
        case bestEffort
    }
    
    /// Default configuration (balanced safety and flexibility)
    public static let `default` = DecoderConfiguration(
        maxRecursionDepth: 100,
        maxTotalBytes: 10 * 1024 * 1024, // 10 MB
        maxContainerSize: 5 * 1024 * 1024, // 5 MB
        mode: .bestEffort,
        strictSchema: false
    )
    
    /// Strict configuration (fails fast on any unexpected input)
    public static let strict = DecoderConfiguration(
        maxRecursionDepth: 50,
        maxTotalBytes: 5 * 1024 * 1024, // 5 MB
        maxContainerSize: 2 * 1024 * 1024, // 2 MB
        mode: .strict,
        strictSchema: true
    )
    
    /// Permissive configuration (for known-good inputs, allows deeper nesting)
    public static let permissive = DecoderConfiguration(
        maxRecursionDepth: 200,
        maxTotalBytes: 50 * 1024 * 1024, // 50 MB
        maxContainerSize: 20 * 1024 * 1024, // 20 MB
        mode: .bestEffort,
        strictSchema: false
    )
    
    public init(
        maxRecursionDepth: Int,
        maxTotalBytes: Int,
        maxContainerSize: Int,
        mode: DecodingMode,
        strictSchema: Bool
    ) {
        self.maxRecursionDepth = max(1, maxRecursionDepth)
        self.maxTotalBytes = max(1024, maxTotalBytes)
        self.maxContainerSize = max(1024, maxContainerSize)
        self.mode = mode
        self.strictSchema = strictSchema
    }
}

/// Error thrown when decoder failsafe limits are exceeded
public enum DecoderFailsafeError: Error, CustomStringConvertible {
    case recursionDepthExceeded(maxDepth: Int, currentDepth: Int)
    case totalBytesExceeded(maxBytes: Int, currentBytes: Int)
    case containerSizeExceeded(maxSize: Int, actualSize: Int)
    case strictModeViolation(field: String, reason: String)
    
    public var description: String {
        switch self {
        case .recursionDepthExceeded(let maxDepth, let currentDepth):
            return "Recursion depth exceeded: \(currentDepth) > \(maxDepth) (possible hostile input or malformed structure)"
        case .totalBytesExceeded(let maxBytes, let currentBytes):
            return "Total bytes exceeded: \(currentBytes) > \(maxBytes) (possible DoS attempt)"
        case .containerSizeExceeded(let maxSize, let actualSize):
            return "Container size exceeded: \(actualSize) > \(maxSize) (possible hostile input)"
        case .strictModeViolation(let field, let reason):
            return "Strict mode violation in \(field): \(reason)"
        }
    }
}
