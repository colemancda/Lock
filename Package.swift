import PackageDescription

let package = Package(
    name: "Lock",
    targets: [
        Target(
            name: "lockd",
            dependencies: [.Target(name: "CoreLock")]
        ),
        Target(
            name: "CoreLockUnitTests",
            dependencies: [.Target(name: "CoreLock")]
        ),
        Target(
            name: "CoreLock"
        )
    ],
    dependencies: [
        .Package(url: "https://github.com/PureSwift/GATT", majorVersion: 1),
        .Package(url: "https://github.com/ColemanCDA/CryptoSwift", majorVersion: 1),
        .Package(url: "https://github.com/PureSwift/Cb64", majorVersion: 1)
    ],
    exclude: ["Xcode", "Android"]
)
