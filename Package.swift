// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipStash",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClipStash",
            path: "ClipStash",
            exclude: [
                "Resources/Info.plist",
                "Resources/Assets.xcassets",
                "Resources/AppIcon.icns",
                "Resources/AppIcon.iconset"
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "ClipStash/Resources/Info.plist"])
            ]
        ),
        .testTarget(name: "ClipStashTests", dependencies: ["ClipStash"], path: "Tests/ClipStashTests")
    ]
)
