// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipStash",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClipStash",
            path: "ClipStash",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "ClipStash/Resources/Info.plist"])
            ]
        )
    ]
)
