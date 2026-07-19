// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "file_jarvis_native",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "file_jarvis_native",
            targets: ["FileJarvisNative"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FileJarvisNative",
            path: "Sources/FileJarvisNative"
        )
    ]
)
