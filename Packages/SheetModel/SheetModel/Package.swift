// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SheetModel",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SheetModel",
            targets: ["SheetModel"]
        ),
    ],
    targets: [
        .target(
            name: "SheetModel",
            path: "Sources/SheetModel"
        ),
    ]
)
