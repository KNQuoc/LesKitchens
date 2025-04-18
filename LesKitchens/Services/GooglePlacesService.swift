import CoreLocation
import Foundation
import UserNotifications

// MARK: - Models
/// Grocery store location with geographic coordinates
struct GroceryStoreLocation: Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let type: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func == (lhs: GroceryStoreLocation, rhs: GroceryStoreLocation) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Google Places Service
/// Service to handle interactions with Google Places API
class GooglePlacesService {
    // API Key loaded from Info.plist
    private let apiKey: String

    // Base URL for Google Places API
    private let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"

    // Cache for storing search results
    private var cachedResults: [String: [GroceryStoreLocation]] = [:]
    private var lastSearchTime: [String: Date] = [:]
    private let cacheExpirationTime: TimeInterval = 3600  // 1 hour cache

    // Initialize with API key from Info.plist
    init() {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String {
            self.apiKey = apiKey
        } else {
            self.apiKey = ""
            print("⚠️ No Google Places API Key found in Info.plist!")
        }
    }

    /// Search for grocery stores near a given location
    /// - Parameters:
    ///   - location: The user's current location
    ///   - radius: Search radius in meters
    ///   - completion: Callback with results or error
    func searchNearbyGroceryStores(
        near location: CLLocation,
        radius: Double,
        completion: @escaping ([GroceryStoreLocation]?, Error?) -> Void
    ) {
        // Check if API key is available
        guard !apiKey.isEmpty else {
            let error = NSError(
                domain: "GooglePlacesService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Google Places API Key not configured"]
            )
            completion(nil, error)
            return
        }

        // Create a cache key based on location and radius
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)-\(radius)"

        // Check if we have cached results that are still valid
        if let cachedStores = cachedResults[cacheKey],
            let lastTime = lastSearchTime[cacheKey],
            Date().timeIntervalSince(lastTime) < cacheExpirationTime
        {
            print("Using cached grocery store results")
            completion(cachedStores, nil)
            return
        }

        // Build URL components
        var urlComponents = URLComponents(string: baseURL)
        urlComponents?.queryItems = [
            URLQueryItem(
                name: "location",
                value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(
                name: "type", value: "grocery_or_supermarket|supermarket|convenience_store"),
            URLQueryItem(name: "key", value: apiKey),
        ]

        guard let url = urlComponents?.url else {
            let error = NSError(
                domain: "GooglePlacesService",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create URL for request"]
            )
            completion(nil, error)
            return
        }

        // Create and execute request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Handle request errors
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }

            // Check for valid response
            guard let data = data else {
                let error = NSError(
                    domain: "GooglePlacesService",
                    code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "No data received from API"]
                )
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }

            // Parse JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let results = json["results"] as? [[String: Any]]
                {
                    // Map results to GroceryStoreLocation objects
                    let stores = results.compactMap { result -> GroceryStoreLocation? in
                        guard let name = result["name"] as? String,
                            let placeId = result["place_id"] as? String,
                            let geometry = result["geometry"] as? [String: Any],
                            let location = geometry["location"] as? [String: Any],
                            let lat = location["lat"] as? Double,
                            let lng = location["lng"] as? Double,
                            let types = result["types"] as? [String]
                        else {
                            return nil
                        }

                        // Determine the store type from the types array
                        let storeType: String
                        if types.contains("supermarket") {
                            storeType = "supermarket"
                        } else if types.contains("grocery_or_supermarket") {
                            storeType = "grocery_store"
                        } else if types.contains("convenience_store") {
                            storeType = "convenience_store"
                        } else {
                            storeType = "store"
                        }

                        return GroceryStoreLocation(
                            id: placeId,
                            name: name,
                            latitude: lat,
                            longitude: lng,
                            type: storeType
                        )
                    }

                    // Cache the results
                    self.cachedResults[cacheKey] = stores
                    self.lastSearchTime[cacheKey] = Date()

                    // Return results on main thread
                    DispatchQueue.main.async {
                        completion(stores, nil)
                    }
                } else {
                    let error = NSError(
                        domain: "GooglePlacesService",
                        code: 1004,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]
                    )
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }

        task.resume()
    }

    /// Get details for a specific place
    /// - Parameters:
    ///   - placeId: The Google Place ID
    ///   - completion: Callback with detailed place information or error
    func getPlaceDetails(
        placeId: String,
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
        // Construct URL for place details
        let detailsBaseURL = "https://maps.googleapis.com/maps/api/place/details/json"
        var components = URLComponents(string: detailsBaseURL)
        components?.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(
                name: "fields",
                value: "name,formatted_address,formatted_phone_number,opening_hours,website"),
            URLQueryItem(name: "key", value: apiKey),
        ]

        guard let url = components?.url else {
            let error = NSError(
                domain: "GooglePlacesService",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL for place details"]
            )
            completion(nil, error)
            return
        }

        // Make API request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Handle errors
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }

            // Check for data
            guard let data = data else {
                let error = NSError(
                    domain: "GooglePlacesService",
                    code: 9,
                    userInfo: [NSLocalizedDescriptionKey: "No data received for place details"]
                )
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }

            // Parse JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let result = json["result"] as? [String: Any]
                {
                    DispatchQueue.main.async {
                        completion(result, nil)
                    }
                } else {
                    let error = NSError(
                        domain: "GooglePlacesService",
                        code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse place details"]
                    )
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }

        task.resume()
    }
}
