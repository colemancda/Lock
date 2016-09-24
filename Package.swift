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
        .Package(url: "https://github.com/ColemanCDA/CryptoSwift", majorVersion: 1)
        .Package(url: "https://github.com/OpenKitten/BSON", majorVersion: 3)
    ],
    exclude: ["Xcode", "Android"]
)
