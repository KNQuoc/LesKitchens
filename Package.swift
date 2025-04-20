// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LesKitchens",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "LesKitchens",
            targets: ["LesKitchens"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "11.11.0"),
        .package(url: "https://github.com/googlemaps/ios-places-sdk", exact: "9.4.1"),
    ],
    targets: [
        .target(
            name: "LesKitchens",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuthCombine-Community", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreCombine-Community", package: "firebase-ios-sdk"),
                .product(name: "GooglePlaces", package: "ios-places-sdk"),
                .product(name: "GooglePlacesSwift", package: "ios-places-sdk"),
            ],
            path: "LesKitchens"
        )
    ]
)
