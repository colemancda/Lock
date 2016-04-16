import PackageDescription

let package = Package(
    name: "Lock",
    dependencies: [
        .Package(url: "https://github.com/PureSwift/GATT.git", majorVersion: 1)
    ],
    targets: [
        Target(
            name: "lockd",
            dependencies: [.Target(name: "CoreLock")]),
        Target(
            name: "CoreLock")
    ],
    exclude: ["Xcode"]
)