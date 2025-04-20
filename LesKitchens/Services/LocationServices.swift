import CoreLocation
import Foundation
import GooglePlaces
import GooglePlacesSwift
import SwiftUI
import UserNotifications

// This file serves as a connector for all location-related services

// MARK: - Models
/// Data model for grocery store locations
public struct LocationServicesStore: Identifiable, Hashable, Codable {
    public var id: String
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var type: String

    public init(id: String, name: String, latitude: Double, longitude: Double, type: String) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Mock Data
// Mock data for testing geofences
extension LocationServicesStore {
    public static var mockGroceryStores: [LocationServicesStore] {
        return [
            LocationServicesStore(
                id: "store1",
                name: "Whole Foods Market",
                latitude: 37.7749,  // Example latitude
                longitude: -122.4194,  // Example longitude
                type: "supermarket"
            ),
            LocationServicesStore(
                id: "store2",
                name: "Trader Joe's",
                latitude: 37.7749 - 0.001,  // Small offset
                longitude: -122.4194 - 0.001,
                type: "grocery_store"
            ),
            LocationServicesStore(
                id: "store3",
                name: "Safeway",
                latitude: 37.7749,
                longitude: -122.4194 + 0.002,
                type: "supermarket"
            ),
        ]
    }
}

// MARK: - Location Services Manager
/// Single entry point for all location-based services
public class LocationServicesManager {
    // Singleton instance
    public static let shared = LocationServicesManager()

    // Location managers
    private let locationManager: LocationManager
    private let geofencingManager: GeofencingManager

    // Service state
    private var isRunning = false

    // Initialization
    private init() {
        self.locationManager = LocationManager()
        self.geofencingManager = GeofencingManager()
    }

    // MARK: - Public API

    /// Send a notification when app launches
    private static func sendLaunchNotification() {
        print("🔔 Attempting to send launch notification...")

        // First check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Current notification settings: \(settings.authorizationStatus.rawValue)")

            guard settings.authorizationStatus == .authorized else {
                print(
                    "⚠️ Notifications not authorized. Current status: \(settings.authorizationStatus.rawValue)"
                )
                // Request authorization if not determined yet
                if settings.authorizationStatus == .notDetermined {
                    print("🔔 Requesting notification authorization...")
                    UNUserNotificationCenter.current().requestAuthorization(options: [
                        .alert, .sound, .badge,
                    ]) { granted, error in
                        if granted {
                            print("✅ Notification permission granted, sending notification...")
                            sendNotificationContent()
                        } else {
                            print(
                                "❌ Notification permission denied: \(error?.localizedDescription ?? "No error details")"
                            )
                        }
                    }
                }
                return
            }

            // If authorized, send the notification
            sendNotificationContent()
        }
    }

    /// Helper method to create and send the actual notification content
    private static func sendNotificationContent() {
        print("🔔 Creating notification content...")
        let content = UNMutableNotificationContent()
        content.title = "Location Tracking Enabled!"
        content.body = "Tracking your location for nearby grocery stores."
        content.sound = UNNotificationSound.default

        // Create trigger (1 second delay to ensure app is fully launched)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request with unique identifier
        let request = UNNotificationRequest(
            identifier: "app-launch-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        print("🔔 Scheduling notification...")
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending launch notification: \(error.localizedDescription)")
            } else {
                print("✅ Launch notification scheduled successfully")
            }
        }
    }

    /// Bootstrap method for initializing location services from app startup
    /// Handles delayed start and adds verbose logging
    public static func bootstrap() {
        print("🔍 DEBUG: LocationServicesManager - Bootstrapping location services...")

        // Send launch notification with a slight delay to ensure proper initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔔 Triggering launch notification...")
            sendLaunchNotification()
        }

        // Add debug to verify the class is accessible
        print(
            "🔍 DEBUG: LocationServicesManager class exists: \(NSStringFromClass(LocationServicesManager.self))"
        )
        print("🔍 DEBUG: Shared instance initialized")

        // Log permission status before starting
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            let manager = CLLocationManager()
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        print(
            "🔍 DEBUG: LocationServicesManager - Permission status before start: \(status.rawValue)")

        // Ensure we're on the main thread for UI operations
        DispatchQueue.main.async {
            // Start services immediately first
            print("🔍 DEBUG: LocationServicesManager - Immediate startup attempt")
            shared.startServices(isRetry: false)

            // Then start again with a delay to ensure app is fully initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("🔍 DEBUG: LocationServicesManager - Delayed startup attempt")
                shared.startServices(isRetry: true)

                // Log permission status using the non-deprecated API in iOS 14+
                let status: CLAuthorizationStatus
                if #available(iOS 14.0, *) {
                    let manager = CLLocationManager()
                    status = manager.authorizationStatus
                } else {
                    status = CLLocationManager.authorizationStatus()
                }

                print(
                    "🔍 DEBUG: LocationServicesManager - Current permission status: \(status.rawValue)"
                )

                // Set up a timer for periodic status logging
                Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    if shared.isEnabled {
                        print("✅ LocationServicesManager: Services are running")
                    } else {
                        print("⚠️ LocationServicesManager: Services are NOT running")
                    }
                }
            }
        }
    }

    /// Start all location services
    public func startServices(isRetry: Bool = false) {
        if isRunning {
            print("📌 LocationServicesManager: Services already running - no action needed")
            return
        }

        print("🔍 DEBUG: LocationServicesManager - Starting location services")

        // Request permissions first
        requestPermissions()

        // Add small delay to allow OS to process permission request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else {
                print("⚠️ LocationServicesManager instance was deallocated")
                return
            }

            // Check authorization status using the non-deprecated API in iOS 14+
            #if os(iOS)
                let authStatus: CLAuthorizationStatus
                if #available(iOS 14.0, *) {
                    let clLocationManager = self.locationManager.clLocationManager
                    authStatus = clLocationManager.authorizationStatus
                } else {
                    // Fallback for older iOS versions
                    authStatus = CLLocationManager.authorizationStatus()
                }

                print(
                    "🔍 DEBUG: LocationServicesManager - Authorization status: \(authStatus.rawValue)"
                )

                // Start on any level of authorization for simulator testing
                if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse
                    || (isRetry
                        && ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil)
                {
                    // We have permission or we're on simulator, start services
                    print(
                        "🔍 DEBUG: LocationServicesManager - Have permission or on simulator, starting services"
                    )

                    // Start location tracking
                    self.locationManager.startLocationUpdates()

                    // Setup geofencing
                    self.geofencingManager.setupGroceryGeofences()

                    // Register for app lifecycle notifications
                    self.registerForAppStateNotifications()

                    self.isRunning = true

                    // Store the status in user defaults so UI can reflect it
                    UserDefaults.standard.set(true, forKey: "grocery_notifications_enabled")

                    print("✅ LocationServicesManager: Services started successfully")
                } else {
                    print(
                        "⚠️ LocationServicesManager: Cannot start services - missing proper authorization"
                    )

                    // If this is a retry, we won't try again automatically
                    if !isRetry {
                        print(
                            "🔍 DEBUG: LocationServicesManager - Will retry after permissions dialog"
                        )
                    }
                }
            #else
                print("⚠️ LocationServicesManager: Location services not supported on this platform")
            #endif
        }
    }

    /// Stop all location services
    public func stopServices() {
        guard isRunning else {
            print("Location services not running")
            return
        }

        print("Stopping location services")

        // Stop location tracking
        locationManager.stopLocationUpdates()

        // Remove geofences
        geofencingManager.removeAllGeofences()

        // Unregister notifications
        #if os(iOS)
            unregisterFromAppStateNotifications()
        #endif

        isRunning = false
    }

    /// Check if services are enabled
    public var isEnabled: Bool {
        return isRunning
    }

    // MARK: - Private methods

    private func requestPermissions() {
        // Request location permissions
        locationManager.requestLocationPermissions()

        // Request notification permissions with enhanced options and debug logging
        print("🔔 Requesting notification permissions...")
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .provisional]
        ) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                // Register for remote notifications (important for iOS/iPadOS)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Notification permission denied")
                if let error = error {
                    print("⚠️ Notification permission error: \(error.localizedDescription)")
                }
            }

            // Check current notification settings
            self.checkNotificationStatus()
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 Device notification settings:")
            print("- Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("- Alert Setting: \(settings.alertSetting.rawValue)")
            print("- Sound Setting: \(settings.soundSetting.rawValue)")
            print("- Badge Setting: \(settings.badgeSetting.rawValue)")
            print("- Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
            print("- Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
            print("- Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
            if #available(iOS 15.0, *) {
                print("- Scheduled Delivery Setting: \(settings.scheduledDeliverySetting.rawValue)")
                print("- Direct Messages Setting: \(settings.directMessagesSetting.rawValue)")
            }
        }
    }

    private func sendProximityNotification(for store: LocationServicesStore) {
        print("🔔 Attempting to send proximity notification for \(store.name)...")

        // Get shopping items from UserDefaults
        let content = UNMutableNotificationContent()
        if let shoppingItems = UserDefaults.standard.array(forKey: "shopping_items") as? [String],
            !shoppingItems.isEmpty
        {
            content.title = "📍 You're near \(store.name)!"
            content.body = "Remember to get: \(shoppingItems.joined(separator: ", "))"
            content.sound = UNNotificationSound.default
            content.badge = NSNumber(value: shoppingItems.count)

            // Add thread identifier for proper grouping
            content.threadIdentifier = "store-proximity-\(store.id)"

            // Add relevant information for the notification
            content.userInfo = [
                "storeId": store.id,
                "storeName": store.name,
                "notificationType": "proximity",
            ]
        } else {
            content.title = "📍 You're near \(store.name)!"
            content.body = "Check your shopping list!"
            content.sound = UNNotificationSound.default
            content.threadIdentifier = "store-proximity-\(store.id)"
        }

        // Create trigger with a 1-second delay to ensure proper delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request with unique identifier
        let identifier = "grocery-proximity-\(store.id)-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Request authorization and schedule notification
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Current notification settings for proximity alert:")
            print("- Authorization Status: \(settings.authorizationStatus.rawValue)")

            guard
                settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            else {
                print("⚠️ Notifications not authorized for proximity alerts")
                // Re-request permissions if denied
                self.requestPermissions()
                return
            }

            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error sending proximity notification: \(error.localizedDescription)")
                } else {
                    print(
                        "✅ Proximity notification scheduled for \(store.name) with ID: \(identifier)"
                    )
                }
            }
        }
    }

    private func sendGeofenceEntryNotification(for store: LocationServicesStore) {
        print("🔔 Attempting to send geofence entry notification for \(store.name)...")

        // Get shopping items from UserDefaults
        let content = UNMutableNotificationContent()
        if let shoppingItems = UserDefaults.standard.array(forKey: "shopping_items") as? [String],
            !shoppingItems.isEmpty
        {
            content.title = "🏪 Welcome to \(store.name)!"
            content.body = "Shopping List: \(shoppingItems.joined(separator: ", "))"
            content.sound = UNNotificationSound.default
            content.badge = NSNumber(value: shoppingItems.count)

            // Add thread identifier for proper grouping
            content.threadIdentifier = "store-entry-\(store.id)"

            // Add relevant information
            content.userInfo = [
                "storeId": store.id,
                "storeName": store.name,
                "notificationType": "geofence",
            ]
        } else {
            content.title = "🏪 Welcome to \(store.name)!"
            content.body = "Check your shopping list!"
            content.sound = UNNotificationSound.default
            content.threadIdentifier = "store-entry-\(store.id)"
        }

        // Create trigger with a 1-second delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request with unique identifier
        let identifier = "geofence-entry-\(store.id)-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Request authorization and schedule notification
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Current notification settings for geofence alert:")
            print("- Authorization Status: \(settings.authorizationStatus.rawValue)")

            guard
                settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            else {
                print("⚠️ Notifications not authorized for geofence alerts")
                // Re-request permissions if denied
                self.requestPermissions()
                return
            }

            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error sending geofence notification: \(error.localizedDescription)")
                } else {
                    print(
                        "✅ Geofence notification scheduled for \(store.name) with ID: \(identifier)"
                    )
                }
            }
        }
    }

    #if os(iOS)
        // Register for app lifecycle notifications
        private func registerForAppStateNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppWillTerminate),
                name: UIApplication.willTerminateNotification,
                object: nil
            )
        }

        // Unregister from notifications
        private func unregisterFromAppStateNotifications() {
            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )

            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )

            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.willTerminateNotification,
                object: nil
            )
        }

        // Handle app lifecycle events
        @objc private func handleAppDidEnterBackground() {
            print("App entered background - ensuring location updates continue")
        }

        @objc private func handleAppWillEnterForeground() {
            print("App entered foreground")
            if isRunning {
                // Restart location updates if necessary
                locationManager.startLocationUpdates()
            }
        }

        @objc private func handleAppWillTerminate() {
            print("App will terminate")
        }
    #endif
}

// MARK: - Location Manager
/// Handles standard location updates and proximity checks
private class LocationManager: NSObject, CLLocationManagerDelegate {
    // Location manager - expose publicly within the file for access
    let clLocationManager = CLLocationManager()

    // Properties for location tracking
    private var currentLocation: CLLocation?

    // Nearby grocery stores
    private var groceryStoreLocations: [LocationServicesStore] = []

    // Constants
    private let searchRadius: Double = 5000  // 5 km (approximately 3 miles)
    private let proximityRadius: Double = 100  // 100 meters for proximity check

    // Track last notification time to avoid spamming
    private var lastProximityNotificationTime: Date = Date.distantPast
    private var lastNearbySearchTime: Date = Date.distantPast

    // Timer for periodic distance checks
    private var distanceCheckTimer: Timer?

    override init() {
        super.init()

        // Configure location manager
        clLocationManager.delegate = self
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        clLocationManager.distanceFilter = 50  // Update location only when moved by 50 meters
        clLocationManager.allowsBackgroundLocationUpdates = true
        clLocationManager.pausesLocationUpdatesAutomatically = false

        #if os(iOS)
            clLocationManager.showsBackgroundLocationIndicator = true
        #endif
    }

    private func requestPermissions() {
        // Request location permissions
        clLocationManager.requestAlwaysAuthorization()

        // Request notification permissions with enhanced options and debug logging
        print("🔔 Requesting notification permissions...")
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .provisional]
        ) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                // Register for remote notifications (important for iOS/iPadOS)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Notification permission denied")
                if let error = error {
                    print("⚠️ Notification permission error: \(error.localizedDescription)")
                }
            }

            // Check current notification settings
            self.checkNotificationStatus()
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 Device notification settings:")
            print("- Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("- Alert Setting: \(settings.alertSetting.rawValue)")
            print("- Sound Setting: \(settings.soundSetting.rawValue)")
            print("- Badge Setting: \(settings.badgeSetting.rawValue)")
            print("- Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
            print("- Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
            print("- Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
            if #available(iOS 15.0, *) {
                print("- Scheduled Delivery Setting: \(settings.scheduledDeliverySetting.rawValue)")
                print("- Direct Messages Setting: \(settings.directMessagesSetting.rawValue)")
            }
        }
    }

    private func sendProximityNotification(for store: LocationServicesStore) {
        print("🔔 Attempting to send proximity notification for \(store.name)...")

        // Get shopping items from UserDefaults
        let content = UNMutableNotificationContent()
        if let shoppingItems = UserDefaults.standard.array(forKey: "shopping_items") as? [String],
            !shoppingItems.isEmpty
        {
            content.title = "📍 You're near \(store.name)!"
            content.body = "Remember to get: \(shoppingItems.joined(separator: ", "))"
            content.sound = UNNotificationSound.default
            content.badge = NSNumber(value: shoppingItems.count)

            // Add thread identifier for proper grouping
            content.threadIdentifier = "store-proximity-\(store.id)"

            // Add relevant information for the notification
            content.userInfo = [
                "storeId": store.id,
                "storeName": store.name,
                "notificationType": "proximity",
            ]
        } else {
            content.title = "📍 You're near \(store.name)!"
            content.body = "Check your shopping list!"
            content.sound = UNNotificationSound.default
            content.threadIdentifier = "store-proximity-\(store.id)"
        }

        // Create trigger with a 1-second delay to ensure proper delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request with unique identifier
        let identifier = "grocery-proximity-\(store.id)-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Request authorization and schedule notification
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Current notification settings for proximity alert:")
            print("- Authorization Status: \(settings.authorizationStatus.rawValue)")

            guard
                settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            else {
                print("⚠️ Notifications not authorized for proximity alerts")
                // Re-request permissions if denied
                self.requestPermissions()
                return
            }

            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error sending proximity notification: \(error.localizedDescription)")
                } else {
                    print(
                        "✅ Proximity notification scheduled for \(store.name) with ID: \(identifier)"
                    )
                }
            }
        }
    }

    func requestLocationPermissions() {
        clLocationManager.requestAlwaysAuthorization()
    }

    func startLocationUpdates() {
        print("Starting location updates...")
        clLocationManager.startUpdatingLocation()

        // Start periodic distance checks
        startPeriodicDistanceChecks()
    }

    func stopLocationUpdates() {
        print("Stopping location updates...")
        clLocationManager.stopUpdatingLocation()

        // Stop periodic distance checks
        stopPeriodicDistanceChecks()
    }

    // MARK: - Periodic Distance Checks

    private func startPeriodicDistanceChecks() {
        // Invalidate existing timer if any
        distanceCheckTimer?.invalidate()

        // Create new timer that fires every 30 seconds
        distanceCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
            [weak self] _ in
            guard let self = self, let currentLocation = self.currentLocation else {
                print("📍 No current location available for distance check")
                return
            }

            self.logDistancesToStores(from: currentLocation)
        }

        print("✅ Started periodic distance checks (every 30 seconds)")
    }

    private func stopPeriodicDistanceChecks() {
        distanceCheckTimer?.invalidate()
        distanceCheckTimer = nil
        print("❌ Stopped periodic distance checks")
    }

    private func logDistancesToStores(from location: CLLocation) {
        print(
            "\n📍 Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)"
        )

        if groceryStoreLocations.isEmpty {
            print("ℹ️ No grocery stores to check distances")
            return
        }

        print("🏪 Distances to nearby stores:")
        print("------------------------------")

        // Sort stores by distance
        let storesWithDistances = groceryStoreLocations.map {
            store -> (store: LocationServicesStore, distance: CLLocationDistance) in
            let storeLocation = CLLocation(latitude: store.latitude, longitude: store.longitude)
            let distance = location.distance(from: storeLocation)
            return (store, distance)
        }.sorted { $0.distance < $1.distance }

        for (store, distance) in storesWithDistances {
            let distanceKm = distance / 1000.0
            print("📌 \(store.name): \(String(format: "%.2f", distanceKm))km")

            if distance <= proximityRadius {
                print("🎯 Within proximity radius! (\(Int(distance))m)")
            }
        }
        print("------------------------------\n")
    }

    // MARK: - Location updates

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = location

        // Check proximity to grocery stores
        checkProximityToGroceryStores(userLocation: location)

        // Search for nearby stores if needed
        searchNearbyStores(at: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("Location authorization: Always")
            startLocationUpdates()
        case .authorizedWhenInUse:
            print("Location authorization: When In Use")
            startLocationUpdates()
        case .denied, .restricted:
            print("Location authorization: Denied or Restricted")
            stopLocationUpdates()
        case .notDetermined:
            print("Location authorization: Not Determined")
        @unknown default:
            print("Location authorization: Unknown")
        }
    }

    // MARK: - Grocery store proximity

    private func checkProximityToGroceryStores(userLocation: CLLocation) {
        if groceryStoreLocations.isEmpty {
            print("No grocery stores to check proximity against")
            return
        }

        // Reduce notification cooldown to 5 minutes instead of 10
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastProximityNotificationTime) < 300 {
            print("Skipping proximity check - last notification was less than 5 minutes ago")
            return
        }

        print("🔍 Checking proximity to \(groceryStoreLocations.count) grocery stores")

        // Sort stores by distance and check the closest ones first
        let nearbyStores = groceryStoreLocations.map {
            store -> (store: LocationServicesStore, distance: CLLocationDistance) in
            let storeLocation = CLLocation(latitude: store.latitude, longitude: store.longitude)
            let distance = userLocation.distance(from: storeLocation)
            return (store, distance)
        }.sorted { $0.distance < $1.distance }

        for (store, distance) in nearbyStores {
            print("📍 Distance to \(store.name): \(Int(distance))m")

            if distance <= proximityRadius {
                print("🎯 User is within \(proximityRadius)m of \(store.name)!")
                sendProximityNotification(for: store)
                lastProximityNotificationTime = currentTime
                break  // Only send one notification even if multiple stores are nearby
            }
        }
    }

    private func searchNearbyStores(at location: CLLocation) {
        // Check if enough time has passed since last search
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastNearbySearchTime) < 3600 {  // 1 hour
            print("Skipping nearby search - last search was less than 1 hour ago")
            return
        }

        print(
            "Searching for grocery stores near \(location.coordinate.latitude), \(location.coordinate.longitude)"
        )

        // Create a new nearby search request using Google Places SDK
        let placeClient = GMSPlacesClient.shared()

        // Define the search area as a circle around the user's location
        let circularLocationRestriction = GMSPlaceCircularLocationOption(
            location.coordinate, searchRadius)

        // Specify the fields to return in the GMSPlace object
        let placeProperties = [GMSPlaceProperty.name, GMSPlaceProperty.coordinate].map {
            $0.rawValue
        }

        // Create the GMSPlaceSearchNearbyRequest
        let request = GMSPlaceSearchNearbyRequest(
            locationRestriction: circularLocationRestriction, placeProperties: placeProperties)
        let includedTypes = ["grocery_store", "supermarket", "wholesaler"]
        request.includedTypes = includedTypes

        let callback: GMSPlaceSearchNearbyResultCallback = { [weak self] results, error in
            guard let self = self, error == nil else {
                if let error = error {
                    print("⚠️ Error searching for grocery stores: \(error.localizedDescription)")
                    // Fallback to mock data if Google Places fails
                    let storesNearby = LocationServicesStore.mockGroceryStores
                    print(
                        "⚠️ Falling back to \(storesNearby.count) mock grocery stores due to API error"
                    )
                    self?.groceryStoreLocations = storesNearby
                    self?.lastNearbySearchTime = currentTime
                }
                return
            }

            guard let results = results else {
                print("⚠️ No results returned, falling back to mock data")
                self.groceryStoreLocations = LocationServicesStore.mockGroceryStores
                self.lastNearbySearchTime = currentTime
                return
            }

            print("✅ Found \(results.count) grocery stores")

            if !results.isEmpty {
                var stores: [LocationServicesStore] = []

                for place in results {
                    let store = LocationServicesStore(
                        id: place.placeID ?? UUID().uuidString,
                        name: place.name ?? "Unknown Store",
                        latitude: place.coordinate.latitude,
                        longitude: place.coordinate.longitude,
                        type: "grocery_store"
                    )
                    stores.append(store)
                }

                print("✅ Successfully processed \(stores.count) grocery stores")
                self.groceryStoreLocations = stores
                self.lastNearbySearchTime = currentTime
            } else {
                print("⚠️ No grocery stores found in this area, falling back to mock data")
                // Fallback to mock data if no stores found
                self.groceryStoreLocations = LocationServicesStore.mockGroceryStores
                self.lastNearbySearchTime = currentTime
            }
        }

        placeClient.searchNearby(with: request, callback: callback)
    }
}

// MARK: - Geofencing Manager
/// Handles geofence creation and monitoring
private class GeofencingManager: NSObject, CLLocationManagerDelegate {
    // Location manager dedicated to geofencing
    private let clLocationManager = CLLocationManager()

    // Constants
    private let proximityRadius: Double = 100.0  // 100 meters

    // Store monitored geofences
    private var monitoredGeofences: [CLCircularRegion] = []

    // Store grocery store locations
    private var groceryStoreLocations: [LocationServicesStore] = []

    // Track when we last sent a notification to avoid spamming
    private var lastGeofenceNotificationTime: Date = Date.distantPast

    override init() {
        super.init()

        // Configure location manager for geofencing
        clLocationManager.delegate = self
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        clLocationManager.allowsBackgroundLocationUpdates = true
        clLocationManager.pausesLocationUpdatesAutomatically = false

        #if os(iOS)
            clLocationManager.showsBackgroundLocationIndicator = true
        #endif
    }

    // Changed from private to internal for access from LocationServicesManager
    func setupGroceryGeofences() {
        print("🔍 DEBUG: GeofencingManager - Setting up grocery geofences")

        #if os(iOS)
            let authStatus: CLAuthorizationStatus
            if #available(iOS 14.0, *) {
                authStatus = clLocationManager.authorizationStatus
            } else {
                authStatus = CLLocationManager.authorizationStatus()
            }

            if authStatus == .authorizedAlways {
                print(
                    "🔍 DEBUG: GeofencingManager - Have proper authorization, setting up geofences")

                // If we have the current location, use it to search for real stores
                if let location = clLocationManager.location {
                    searchNearbyStoresForGeofencing(at: location)
                } else {
                    // Fallback to mock data if location isn't available
                    print("⚠️ GeofencingManager - No location available, using mock data")
                    createGeofencesFromStores(LocationServicesStore.mockGroceryStores)
                }

                print("✅ GeofencingManager: Grocery geofences setup initiated")
            } else {
                print("⚠️ GeofencingManager: Cannot setup geofences - missing proper authorization")

                // Request authorization
                requestGeofencingAuthorization()

                // Retry after delay
                retryGeofenceSetup()
            }
        #else
            print("⚠️ GeofencingManager: Geofencing not supported on this platform")
        #endif
    }

    private func retryGeofenceSetup() {
        print("🔍 DEBUG: GeofencingManager - Scheduling retry for geofence setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.setupGroceryGeofences()
        }
    }

    func removeAllGeofences() {
        // Stop monitoring all regions
        for region in clLocationManager.monitoredRegions {
            clLocationManager.stopMonitoring(for: region)
        }

        // Clear our tracking list
        monitoredGeofences.removeAll()

        print("Removed all geofences")
    }

    // MARK: - Location updates

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print(
            "Geofencing location update: \(location.coordinate.latitude), \(location.coordinate.longitude)"
        )

        // Use the current location to search for real grocery stores
        searchNearbyStoresForGeofencing(at: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Geofencing location manager error: \(error.localizedDescription)")
    }

    // MARK: - Geofence monitoring

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("🛒 Entered region: \(region.identifier)")
        sendGeofenceEntryNotification(for: region)
    }

    func locationManager(
        _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
    ) {
        if let region = region {
            print("Failed to monitor region \(region.identifier): \(error.localizedDescription)")
        } else {
            print("Failed to monitor an unknown region: \(error.localizedDescription)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Started monitoring region: \(region.identifier)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("Geofencing location authorization: Always")
            setupGroceryGeofences()
        case .authorizedWhenInUse:
            print(
                "Geofencing location authorization: When In Use - need Always for proper geofencing"
            )
        case .denied, .restricted:
            print("Geofencing location authorization: Denied or Restricted")
        case .notDetermined:
            print("Geofencing location authorization: Not Determined")
        @unknown default:
            print("Geofencing location authorization: Unknown")
        }
    }

    // MARK: - Geofence management

    private func createGeofencesFromStores(_ stores: [LocationServicesStore]) {
        // Remove any existing geofences
        removeAllGeofences()

        // Get current location
        guard let currentLocation = clLocationManager.location else {
            print("⚠️ Cannot create geofences: Current location not available")
            return
        }

        // Sort stores by distance to current location
        let sortedStores = stores.sorted { store1, store2 in
            let location1 = CLLocation(latitude: store1.latitude, longitude: store1.longitude)
            let location2 = CLLocation(latitude: store2.latitude, longitude: store2.longitude)
            return currentLocation.distance(from: location1)
                < currentLocation.distance(from: location2)
        }

        // Take only the closest 20 stores (iOS limit)
        let maxRegions = 20
        let nearestStores = Array(sortedStores.prefix(maxRegions))

        print(
            "Creating geofences for \(nearestStores.count) nearest stores (out of \(stores.count) total)"
        )

        // Create a geofence for each nearest store
        for store in nearestStores {
            let identifier = "store_\(store.id)"
            let center = CLLocationCoordinate2D(
                latitude: store.latitude, longitude: store.longitude)

            // Create the circular region (geofence)
            let region = CLCircularRegion(
                center: center, radius: proximityRadius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false

            // Start monitoring the region
            clLocationManager.startMonitoring(for: region)

            // Add to our tracking list
            monitoredGeofences.append(region)

            let distance = currentLocation.distance(
                from: CLLocation(latitude: store.latitude, longitude: store.longitude))
            print(
                "✅ Added geofence for: \(store.name) at \(String(format: "%.2f", distance/1000))km away"
            )
        }

        print("Now monitoring \(monitoredGeofences.count) nearest geofences")

        // Store all grocery locations for later reference, even those we're not monitoring
        self.groceryStoreLocations = stores

        // Log stores that couldn't be monitored
        if stores.count > maxRegions {
            print(
                "⚠️ Note: \(stores.count - maxRegions) stores are beyond the monitoring limit and will be checked using proximity instead"
            )
        }
    }

    private func sendGeofenceEntryNotification(for region: CLRegion) {
        guard let identifier = region.identifier.split(separator: "_").last else {
            print("Invalid geofence identifier format")
            return
        }

        // Find the store that corresponds to this geofence
        guard let store = groceryStoreLocations.first(where: { $0.id == String(identifier) }) else {
            sendGenericGroceryNotification()
            return
        }

        print("🏪 Entered geofence for: \(store.name)")

        // Reduce notification cooldown to 5 minutes
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastGeofenceNotificationTime) < 300 {
            print("Skipping notification - last one was less than 5 minutes ago")
            return
        }

        // Get shopping items from UserDefaults
        let content = UNMutableNotificationContent()
        if let shoppingItems = UserDefaults.standard.array(forKey: "shopping_items") as? [String],
            !shoppingItems.isEmpty
        {
            content.title = "🏪 Welcome to \(store.name)!"
            content.body = "Shopping List: \(shoppingItems.joined(separator: ", "))"
            content.sound = UNNotificationSound.default

            // Add shopping list count as badge
            content.badge = NSNumber(value: shoppingItems.count)
        } else {
            content.title = "🏪 Welcome to \(store.name)!"
            content.body = "Check your shopping list!"
            content.sound = UNNotificationSound.default
        }

        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request with unique identifier that includes store ID
        let request = UNNotificationRequest(
            identifier: "geofence-entry-\(store.id)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        // Request authorization before sending notification
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("⚠️ Notifications not authorized")
                return
            }

            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error sending geofence notification: \(error.localizedDescription)")
                } else {
                    print("✅ Geofence notification sent for \(store.name)")
                    self.lastGeofenceNotificationTime = currentTime
                }
            }
        }
    }

    private func sendGenericGroceryNotification() {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "You're at a grocery store!"
        content.body = "Time to check your shopping list"
        content.sound = UNNotificationSound.default

        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request
        let request = UNNotificationRequest(
            identifier: "geofence-generic-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending generic geofence notification: \(error.localizedDescription)")
            } else {
                print("✅ Generic geofence notification sent")
                self.lastGeofenceNotificationTime = Date()
            }
        }
    }

    private func requestGeofencingAuthorization() {
        print("🔍 DEBUG: GeofencingManager - Requesting authorization")
        clLocationManager.requestAlwaysAuthorization()
    }

    private func searchNearbyStoresForGeofencing(at location: CLLocation) {
        print("🔍 DEBUG: GeofencingManager - Searching for real grocery stores near location")

        // Create a new nearby search request
        let placeClient = GMSPlacesClient.shared()

        // Define the search area as a circle around the user's location with a larger radius for geofencing
        let circularLocationRestriction = GMSPlaceCircularLocationOption(location.coordinate, 20000)  // 20km radius for geofencing

        // Specify the fields to return in the GMSPlace object
        let placeProperties = [GMSPlaceProperty.name, GMSPlaceProperty.coordinate].map {
            $0.rawValue
        }

        // Create the GMSPlaceSearchNearbyRequest
        let request = GMSPlaceSearchNearbyRequest(
            locationRestriction: circularLocationRestriction, placeProperties: placeProperties)
        let includedTypes = ["grocery_store", "supermarket", "wholesaler"]
        request.includedTypes = includedTypes

        let callback: GMSPlaceSearchNearbyResultCallback = { [weak self] results, error in
            guard let self = self else { return }

            if let error = error {
                print(
                    "⚠️ GeofencingManager - Error searching for grocery stores: \(error.localizedDescription)"
                )
                // Fallback to mock data if Places API fails
                print("⚠️ GeofencingManager - Falling back to mock data")
                self.createGeofencesFromStores(LocationServicesStore.mockGroceryStores)
                return
            }

            guard let results = results else {
                print("⚠️ GeofencingManager - Unexpected results format, falling back to mock data")
                self.createGeofencesFromStores(LocationServicesStore.mockGroceryStores)
                return
            }

            if !results.isEmpty {
                print("✅ GeofencingManager - Found \(results.count) grocery stores")

                var stores: [LocationServicesStore] = []

                for place in results {
                    let store = LocationServicesStore(
                        id: place.placeID ?? UUID().uuidString,
                        name: place.name ?? "Unknown Store",
                        latitude: place.coordinate.latitude,
                        longitude: place.coordinate.longitude,
                        type: "grocery_store"
                    )
                    stores.append(store)
                }

                print("✅ GeofencingManager - Successfully processed \(stores.count) grocery stores")
                self.createGeofencesFromStores(stores)
            } else {
                print("⚠️ GeofencingManager - No grocery stores found in this area, using mock data")
                self.createGeofencesFromStores(LocationServicesStore.mockGroceryStores)
            }
        }

        placeClient.searchNearby(with: request, callback: callback)
    }
}
