import CoreLocation
import Foundation

// This file serves as a bridge for GooglePlacesService.swift

// Define a separate grocery store location type for the Google Places Service
public struct PlacesGroceryStoreLocation: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let type: String

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(id: String, name: String, latitude: Double, longitude: Double, type: String) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
    }

    public static func == (lhs: PlacesGroceryStoreLocation, rhs: PlacesGroceryStoreLocation) -> Bool
    {
        return lhs.id == rhs.id
    }
}
