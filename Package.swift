// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShinaraSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ShinaraSDK",
            targets: ["ShinaraSDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.4.0")
    ],
    targets: [
        .target(
            name: "ShinaraSDK",
            dependencies: ["Alamofire"],
            path: "Sources"
        ),
        .testTarget(
            name: "ShinaraSDKTests",
            dependencies: ["ShinaraSDK"]
        )
    ]
)
