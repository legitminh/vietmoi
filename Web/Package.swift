// swift-tools-version: 6.3
import PackageDescription

// The web demo's WebAssembly build of the shared core. Core/ and Mobile/ are symlinks
// to the same sources the apps compile; Host/ adapts them to the browser. Build with
// scripts/build-wasm.py (Embedded Swift, wasm32-unknown-wasip1).
let package = Package(
    name: "SieuvietWeb",
    targets: [
        .executableTarget(
            name: "SieuvietWeb", path: "Sources/SieuvietWeb",
            swiftSettings: [.swiftLanguageMode(.v5), .unsafeFlags(["-Osize"])],
            linkerSettings: [.linkedLibrary("swiftUnicodeDataTables"),
                            .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"])])
    ]
)
