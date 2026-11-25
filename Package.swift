// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Sieuviet",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "SieuvietCore", targets: ["SieuvietCore"]),
        .library(name: "SieuvietEngine", type: .dynamic, targets: ["SieuvietBridge"])
    ],
    targets: [
        .target(name: "SieuvietCore", path: "Sources/Core",
                exclude: ["KeyboardPreferences.swift", "KeyboardProfiles.swift"],
                sources: ["AppCopy.swift", "AppDesign.swift", "ASCIIKeyboardLayout.swift", "ASCIIPlusMapping.swift",
                          "KeyboardProfile.swift", "KeyboardEngine.swift", "PhoneticBasis.swift",
                          "PredictionEngine.swift", "AdaptivePunctuation.swift", "SuggestionNumberKeys.swift", "StandardVietnamese.swift", "SieuvietEngine.swift", "ShiftTapDetector.swift"]),
        .target(name: "SieuvietCABI", path: "Sources/CABI", publicHeadersPath: "include"),
        .target(name: "SieuvietBridge", dependencies: ["SieuvietCore", "SieuvietCABI"],
                path: "Sources/Bridge"),
        .testTarget(name: "SieuvietCoreTests", dependencies: ["SieuvietCore"],
                    path: "Tests/PackageCore")
    ],
    swiftLanguageModes: [.v5]
)
