//
//  DecodeCommand.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//  CLI entrypoint glue between main.swift and decoder logic
//

import Foundation

enum DecodeCommand {

    enum Mode {
        case attestation
        case assertion
    }

    static func run(
        mode: Mode,
        base64Input: String,
        pretty: Bool
    ) throws {

        guard let data = Data(base64Encoded: base64Input) else {
            throw CLIError.invalidBase64
        }

        let decoded: Any

        switch mode {
        case .attestation:
            decoded = try AppAttestDecoder.decodeAttestation(data)
        case .assertion:
            decoded = try AppAttestDecoder.decodeAssertion(data)
        }

        if pretty {
            if let json = PrettyPrinter.printJSON(decoded) {
                Swift.print(json)
            } else {
                Swift.print(decoded)
            }
        } else {
            Swift.print(decoded)
        }
    }
}

// MARK: - Errors

enum CLIError: Error, CustomStringConvertible {
    case invalidBase64

    var description: String {
        switch self {
        case .invalidBase64:
            return "Input is not valid base64"
        }
    }
}
