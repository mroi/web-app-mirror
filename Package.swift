// swift-tools-version: 6.4
import PackageDescription

let package = Package(
	name: "WebAppMirror",
	platforms: [.macOS(.v27)],
	dependencies: [
		.package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")
	],
	targets: [
		.executableTarget(
			name: "WebAppMirror",
			dependencies: [ .product(name: "Hummingbird", package: "hummingbird") ],
			resources: [ .process("Resources") ],
			linkerSettings: [ .linkedFramework("WebKit") ]
		)
	]
)
