// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ical",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "ical", targets: ["ical"])
    ],
    targets: [
        .executableTarget(
            name: "ical",
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        )
    ]
)
