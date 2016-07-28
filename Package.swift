import PackageDescription

let package = Package(
    name: "SwiftNetLib",
    dependencies: [
        .Package(url: "https://github.com/open-swift/C7.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/Zewo/HTTPParser.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/Zewo/HTTPSerializer.git", majorVersion: 0, minor: 5)
     ]
)
