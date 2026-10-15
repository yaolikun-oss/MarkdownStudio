// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownReader",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MarkdownReader", targets: ["MarkdownReader"])],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.9.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
    ],
    targets: [
        .target(name: "EPUBCore", dependencies: [
            .product(name: "ZIPFoundation", package: "ZIPFoundation")
        ]),
        .executableTarget(name: "MarkdownReader", dependencies: [
        .product(name: "Markdown", package: "swift-markdown"),
        "EPUBCore"
        ]),
        .testTarget(name: "EPUBCoreTests", dependencies: ["EPUBCore", .product(name: "ZIPFoundation", package: "ZIPFoundation")]),
        .testTarget(name: "MarkdownReaderTests", dependencies: ["MarkdownReader", "EPUBCore"])
    ]
)
