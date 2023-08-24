// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "BitcoinKit",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "BitcoinKit",
            targets: ["BitcoinKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ArtemZinkov/BitcoinCore.git", .branch("master")),
        .package(url: "https://github.com/ArtemZinkov/HdWalletKit.git", .branch("main")),
        .package(url: "https://github.com/ArtemZinkov/Hodler.git", .branch("master")),
        .package(url: "https://github.com/horizontalsystems/HsToolKit.Swift.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/horizontalsystems/HsCryptoKit.Swift.git", .upToNextMinor(from: "1.2.1")),
        .package(url: "https://github.com/horizontalsystems/HsExtensions.Swift.git", .upToNextMajor(from: "1.0.6")),
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "5.0.0")),
    ],
    targets: [
        .target(
            name: "BitcoinKit",
            dependencies: [
                "BigInt",
                .product(name: "BitcoinCore", package: "BitcoinCore"),
                .product(name: "Hodler", package: "Hodler"),
                .product(name: "HsCryptoKit", package: "HsCryptoKit.Swift"),
                .product(name: "HsExtensions", package: "HsExtensions.Swift"),
                .product(name: "HsToolKit", package: "HsToolKit.Swift"),
                .product(name: "HdWalletKit", package: "HdWalletKit"),
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
    ]
)
