import PackageDescription

let package = Package(
    name: "SwiftNetLib",
    dependencies: [
//        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 13),
        .Package(url: "https://github.com/Zewo/WebSocketServer.git", majorVersion: 0, minor: 7),
          .Package(url: "https://github.com/Zewo/HTTPParser.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/Zewo/HTTPSerializer.git", majorVersion: 0, minor: 7),
     ]
)
