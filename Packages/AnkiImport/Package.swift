// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnkiImport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AnkiImport", targets: ["AnkiImport"])],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20"),
        .package(url: "https://github.com/facebook/zstd.git", exact: "1.5.7"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.11.2")
    ],
    targets: [
        .target(name: "AnkiImport", dependencies: [
            "ZIPFoundation", "SwiftSoup", .product(name: "libzstd", package: "zstd")
        ], linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "AnkiImportTests", dependencies: ["AnkiImport", "ZIPFoundation",
            .product(name: "libzstd", package: "zstd")])
    ]
)
