import PackageDescription

let package = Package(
    name: "Lock",
    targets: [
        Target(
            name: "lockd",
            dependencies: [.Target(name: "CoreLock")]
        ),
        Target(
            name: "CoreLock"
        )
    ],
    dependencies: [
        .Package(url: "https://github.com/PureSwift/GATT", majorVersion: 1),
        .Package(url: "https://github.com/PureSwift/JSON", majorVersion: 1),
        .Package(url: "https://github.com/krzyzanowskim/CryptoSwift", majorVersion: 0),
        .Package(url: "https://github.com/ColemanCDA/BSON", majorVersion: 4)
    ],
    exclude: ["Xcode", "Android"]
)
