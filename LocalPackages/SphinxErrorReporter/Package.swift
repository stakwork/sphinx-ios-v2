// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SphinxErrorReporter",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SphinxErrorReporter",
            targets: ["SphinxErrorReporter"]
        )
    ],
    targets: [
        .target(
            name: "CrashSignalTrampoline",
            path: "Sources/CrashSignalTrampoline",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SphinxErrorReporter",
            dependencies: ["CrashSignalTrampoline"],
            path: "Sources/SphinxErrorReporter"
        ),
        .testTarget(
            name: "SphinxErrorReporterTests",
            dependencies: ["SphinxErrorReporter", "CrashSignalTrampoline"],
            path: "Tests/SphinxErrorReporterTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
