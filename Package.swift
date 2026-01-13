// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppAttestCore",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "AppAttestCore",
            targets: ["AppAttestCore"]
        ),
    ],
    dependencies: [
        // No external dependencies - pure Swift implementation
    ],
    targets: [
        .target(
            name: "AppAttestCore",
            dependencies: [],
            path: "AppAttestCore",
            exclude: [
                "AppAttestCore.docc"  // Documentation catalog excluded from package
            ],
            sources: [
                "AppAttestCore.swift",
                "ASN1",
                "CBOR",
                "COSE",
                "Attestation",
                "X509"
            ]
        ),
        .testTarget(
            name: "AppAttestCoreTests",
            dependencies: ["AppAttestCore"],
            path: "AppAttestCoreTests"
        ),
    ]
)

