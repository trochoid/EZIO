// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "EZIO",
    platforms: [ .iOS(.v14) ],
    products: [ .library(name: "EZIO", targets: ["EZIO"]) ],
    targets: [ .target(name: "EZIO", path: "", exclude: ["README.md"]) ]
)
