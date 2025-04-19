//
//  LesKitchensApp.swift
//  LesKitchens
//
//  Created by Quoc Ngo on 4/1/25.
//

import CoreLocation
import Firebase
import GooglePlaces  // Add import for GooglePlaces
// Explicitly import our Services collection so we can access LocationServicesManager
// The "LesKitchens." prefix is optional depending on your module structure
// import LesKitchens.Services
import SwiftUI

// NOTE: These remaining linter errors require importing modules or changing app structure:
// - 'main' attribute cannot be used in a module that contains top-level code
// - Cannot find 'AuthViewModel' in scope
// - Cannot find 'ContentView' in scope
// - Cannot find 'LoginView' in scope
// They can be resolved in the full project context.

// Reference type to store location manager to avoid capture issues
final class LocationServicesReference {
  static let shared = LocationServicesReference()
  var locationManager: CLLocationManager?

  private init() {}

  func setupBasicLocationServices() {
    // Create a new manager if needed
    if locationManager == nil {
      locationManager = CLLocationManager()

      // IMPORTANT: Must request authorization BEFORE setting allowsBackgroundLocationUpdates
      locationManager?.requestAlwaysAuthorization()

      // Configure for proper background usage
      // Check authorization status using the non-deprecated API in iOS 14+
      let authStatus: CLAuthorizationStatus
      if #available(iOS 14.0, *) {
        authStatus = locationManager?.authorizationStatus ?? .notDetermined
      } else {
        // Fallback for older iOS versions
        authStatus = CLLocationManager.authorizationStatus()
      }

      if authStatus == .authorizedAlways {
        // Only enable background updates if we have proper authorization
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false

        #if os(iOS)
          // Show the indicator in iOS when running in background
          if #available(iOS 11.0, *) {
            locationManager?.showsBackgroundLocationIndicator = true
          }
        #endif

        print("Background location updates properly configured")
      } else {
        print("⚠️ Cannot enable background updates - missing always authorization")
      }
    }

    // Start on background thread - ONLY if we have the right permissions
    // Check authorization status using the non-deprecated API in iOS 14+
    let authStatus: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      authStatus = locationManager?.authorizationStatus ?? .notDetermined
    } else {
      // Fallback for older iOS versions
      authStatus = CLLocationManager.authorizationStatus()
    }

    #if os(iOS)
      if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
        startLocationUpdates()
      } else {
        print("⚠️ Cannot start location updates - missing authorization")
      }
    #else
      // On macOS or other platforms
      if authStatus == .authorizedAlways {
        startLocationUpdates()
      } else {
        print("⚠️ Cannot start location updates - missing authorization")
      }
    #endif
  }

  private func startLocationUpdates() {
    DispatchQueue.global(qos: .background).async { [weak self] in
      self?.locationManager?.startUpdatingLocation()
      print("Started basic location updates as fallback")
    }
  }
}

// Helper class to handle app initialization tasks that require classes
final class AppSetupHelper {
  static let shared = AppSetupHelper()

  private init() {}

  func initializeFirebase() {
    // Firebase will be properly initialized once you add the SDK via Swift Package Manager
    #if canImport(Firebase)
      FirebaseApp.configure()
      print("✅ Firebase initialized successfully")
    #else
      print("⚠️ Firebase SDK not available - add via Swift Package Manager")
    #endif
  }

  func initializeLocationServices() {
    print("🔍 DEBUG: App initializing location services...")

    // Start permission request process
    LocationPermissionDelegate.shared.requestLocationPermission()

    // Then try again after a delay to ensure app is fully launched
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      print("🔍 DEBUG: Checking location services after delay")
      LocationPermissionDelegate.shared.requestLocationPermission()
    }
  }

  // Extracted method to be called from the LocationPermissionDelegate
  func startLocationManagerIfAvailable() {
    // Try to start services with LocationServicesManager first (our main implementation)
    print("🔍 DEBUG: Attempting to start via LocationServicesManager...")

    // Try the direct bridge approach first - this should work if imports are correct
    do {
      print("🔍 DEBUG: Attempting to use LocationServicesBridge")
      LocationServicesBridge.bootstrap()
      print("✅ Successfully started location services via bridge")

      // Force a value update to UserDefaults to enable the UI toggle
      UserDefaults.standard.set(true, forKey: "grocery_notifications_enabled")
      return
    }

  }

  // Helper method to try finding the class at runtime
  private func tryRuntimeClassLookup() -> Bool {
    // Try to access the LocationServicesManager class directly without namespace
    if let servicesType = NSClassFromString("LocationServicesManager") as? NSObject.Type {
      print("🔍 DEBUG: Found LocationServicesManager class without namespace")
      if tryToInitializeManager(managerClass: servicesType) {
        return true
      }
    }

    // Try with the module name if the direct approach didn't work
    guard let namespaceName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String else {
      print("⚠️ Could not get bundle name")
      return false
    }

    // Try different namespace variations
    let classNameOptions = [
      "\(namespaceName).LocationServicesManager",
      "Services.LocationServicesManager",
      "\(namespaceName).Services.LocationServicesManager",
    ]

    print("🔍 DEBUG: Trying multiple class name formats:")
    for className in classNameOptions {
      print("🔍 DEBUG: Looking for class: \(className)")
      if let managerClass = NSClassFromString(className) as? NSObject.Type {
        print("🔍 DEBUG: Found LocationServicesManager class as: \(className)")
        if tryToInitializeManager(managerClass: managerClass) {
          return true
        }
      }
    }

    // If all class lookup attempts failed, try the direct call approach
    return tryDirectCall()
  }

  // Last resort direct call approach
  private func tryDirectCall() -> Bool {
    print("🔍 DEBUG: Attempting direct call to LocationServicesManager")

    do {
      // Create a selector to the bootstrap method
      let bootstrapSelectorString = "bootstrap"
      let aSelector = NSSelectorFromString(bootstrapSelectorString)

      // Try different class name variations
      let classStrings = ["LocationServicesManager", "Services.LocationServicesManager"]

      for classString in classStrings {
        if let aClass = NSClassFromString(classString) {
          print("🔍 DEBUG: Found class by name: \(classString)")

          // Try to call the static method
          if aClass.responds(to: aSelector) {
            print("🔍 DEBUG: Calling static bootstrap method")
            // Use performSelector for Objective-C compatibility
            #if swift(>=5.8)
              // Swift 5.8 and later syntax
              let _ = aClass.performSelector(
                onMainThread: aSelector, with: nil, waitUntilDone: true)
            #else
              // Older Swift syntax
              let _ = aClass.perform(aSelector)
            #endif
            print("✅ Successfully called bootstrap method")
            return true
          } else {
            print("⚠️ Class doesn't respond to bootstrap selector")
          }
        }
      }
    }

    return false
  }

  // Helper method to try initializing the manager class once found
  private func tryToInitializeManager(managerClass: NSObject.Type) -> Bool {
    // Try the bootstrap method first (preferred)
    let bootstrapSelector = NSSelectorFromString("bootstrap")
    if managerClass.responds(to: bootstrapSelector) {
      print("🔍 DEBUG: Calling bootstrap method")
      let _ = managerClass.perform(bootstrapSelector)
      print("✅ Successfully bootstrapped location services")

      // Force a value update to UserDefaults to enable the UI toggle
      UserDefaults.standard.set(true, forKey: "grocery_notifications_enabled")
      return true
    }

    // If bootstrap isn't available, try via shared instance
    print("🔍 DEBUG: Bootstrap method not found, trying via shared instance")
    if let shared = managerClass.value(forKey: "shared") as? NSObject {
      print("🔍 DEBUG: Found shared instance")
      let startServicesSelector = NSSelectorFromString("startServices:")

      if shared.responds(to: startServicesSelector) {
        print("🔍 DEBUG: Calling startServices method")
        let _ = shared.perform(startServicesSelector, with: NSNumber(value: false))
        print("✅ Successfully started location services")

        // Force a value update to UserDefaults to enable the UI toggle
        UserDefaults.standard.set(true, forKey: "grocery_notifications_enabled")
        return true
      } else {
        print("⚠️ Shared instance doesn't respond to startServices")
      }
    } else {
      print("⚠️ Couldn't get shared instance")
    }

    return false
  }

  private func fallbackToBasicServices() {
    print("⚠️ LocationServicesManager class not found")
    print("🔍 DEBUG: Falling back to basic location services...")
    LocationServicesReference.shared.setupBasicLocationServices()
  }
}

// Delegate class to properly handle location permission callbacks
class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
  // Keep a reference to prevent it from being deallocated
  static let shared = LocationPermissionDelegate()
  private var locationManager: CLLocationManager?
  private var permissionState: CLAuthorizationStatus = .notDetermined

  override init() {
    super.init()
    print("🔍 DEBUG: LocationPermissionDelegate initialized")

    // Initialize the location manager
    locationManager = CLLocationManager()
    locationManager?.delegate = self

    // Check current authorization status
    if #available(iOS 14.0, *) {
      permissionState = locationManager?.authorizationStatus ?? .notDetermined
    } else {
      permissionState = CLLocationManager.authorizationStatus()
    }

    print("🔍 DEBUG: Initial authorization status: \(permissionState.rawValue)")
  }

  func requestLocationPermission() {
    print("🔍 DEBUG: Starting location permission request sequence")

    // Instead of immediately checking system-wide settings which can block the UI,
    // we'll check authorization status first and only proceed if needed

    // Get current status - this is the recommended way as per Apple's guidelines
    if #available(iOS 14.0, *) {
      checkAuthorizationStatus(locationManager?.authorizationStatus ?? .notDetermined)
    } else {
      checkAuthorizationStatus(CLLocationManager.authorizationStatus())
    }
  }

  private func checkAuthorizationStatus(_ status: CLAuthorizationStatus) {
    permissionState = status
    print("🔍 DEBUG: Checking authorization status: \(status.rawValue)")

    // Only check if location services are enabled if we need to request permissions
    if status == .notDetermined {
      // Move the potentially UI-blocking call off the main thread
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        // Check if location services are enabled at the system level
        if !CLLocationManager.locationServicesEnabled() {
          print("⚠️ Location services are disabled system-wide")
          // Can't proceed without system location services enabled
          return
        }

        // Switch back to main thread for UI updates
        DispatchQueue.main.async {
          // First-time request - trigger the callback via When In Use request
          print("🔍 DEBUG: Status is not determined, requesting when-in-use permission")
          self?.locationManager?.requestWhenInUseAuthorization()
          // We'll handle next steps in the callback
        }
      }
      return
    }

    // Handle other permission states
    switch status {
    case .notDetermined:
      // Already handled above
      break

    case .authorizedWhenInUse:
      // Already have when-in-use, now request always
      print("🔍 DEBUG: Already have when-in-use, requesting always")
      locationManager?.requestAlwaysAuthorization()
      // Also start location services with what we have
      startLocationServicesIfNeeded()

    case .authorizedAlways:
      // Already have full permissions
      print("🔍 DEBUG: Already have always authorization")
      startLocationServicesIfNeeded()

    case .denied, .restricted:
      print("⚠️ Location authorization denied or restricted")
    // Can't proceed with location features

    @unknown default:
      print("⚠️ Unknown authorization status: \(status.rawValue)")
    }
  }

  private func startLocationServicesIfNeeded() {
    // Don't start services if we don't have any authorization
    if permissionState == .denied || permissionState == .restricted
      || permissionState == .notDetermined
    {
      print("⚠️ Cannot start location services - missing proper authorization")
      return
    }

    // Start services with a slight delay to ensure UI responsiveness
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      AppSetupHelper.shared.startLocationManagerIfAvailable()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // Handle iOS 14+ authorization changes
    if #available(iOS 14.0, *) {
      let status = manager.authorizationStatus
      print("🔍 DEBUG: Authorization changed to: \(status.rawValue)")

      // If our status has changed, handle it
      if status != permissionState {
        handleAuthorizationChange(status)
      }
    }
  }

  // For iOS 13 and earlier
  func locationManager(
    _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
  ) {
    print("🔍 DEBUG: Authorization changed to: \(status.rawValue)")

    // If our status has changed, handle it
    if status != permissionState {
      handleAuthorizationChange(status)
    }
  }

  private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
    // Update our stored state
    permissionState = status

    switch status {
    case .authorizedWhenInUse:
      print("🔍 DEBUG: Received when-in-use permission, requesting always")

      // Wait a moment before requesting the second permission for better UX
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.locationManager?.requestAlwaysAuthorization()
      }

      // Start services with what we have
      startLocationServicesIfNeeded()

    case .authorizedAlways:
      print("🔍 DEBUG: Received always permission")
      startLocationServicesIfNeeded()

    case .denied, .restricted:
      print("⚠️ Location permission denied or restricted")
    // Can't proceed with location features

    case .notDetermined:
      print("🔍 DEBUG: Authorization status is still not determined")

    @unknown default:
      print("⚠️ Unknown authorization status: \(status.rawValue)")
    }
  }
}

// Create a direct wrapper for LocationServicesManager using runtime lookup
class LocationServicesBridge {
  static func bootstrap() {
    print("🔍 DEBUG: Trying direct call to LocationServicesManager.bootstrap")

    // --- Try Direct Call First (Assuming Same Target) ---
    // If LocationServicesManager is in the same target, this direct call should work.
    LocationServicesManager.bootstrap()
    print("✅ Successfully called LocationServicesManager.bootstrap directly")
    return

    // --- Fallback to Runtime Lookup (If Direct Call Fails) ---
    /* // Uncomment this block if the direct call above fails at compile/runtime
    print("🔍 DEBUG: Direct call failed, falling back to runtime lookup via bridge")
    if let managerClass = findLocationServicesManagerClass(),
       let bootstrapSelector = NSSelectorFromString("bootstrap"),
       managerClass.responds(to: bootstrapSelector) {
    
      print("✅ Found LocationServicesManager class and bootstrap method via runtime")
    
      #if swift(>=5.8)
      let _ = managerClass.performSelector(onMainThread: bootstrapSelector, with: nil, waitUntilDone: true)
      #else
      let _ = managerClass.perform(bootstrapSelector)
      #endif
    
      return
    }
    print("⚠️ Failed to find or call LocationServicesManager.bootstrap via runtime bridge")
    */
  }

  @main
  struct LesKitchensApp: App {
    @StateObject var authViewModel = AuthViewModel()

    init() {
      // Initialize Firebase and location services using the helper class
      AppSetupHelper.shared.initializeFirebase()

      // Initialize Google Places SDK
      if let apiKey = getGooglePlacesAPIKeyFromPlist() {
        print("🔍 DEBUG: Initializing Google Places SDK with API Key")
        GMSPlacesClient.provideAPIKey(apiKey)
      } else {
        print("⚠️ WARNING: Google Places API Key not found in Info.plist")
      }

      // Initialize location services
      AppSetupHelper.shared.initializeLocationServices()
    }

    // Helper function to retrieve API key from Info.plist
    private func getGooglePlacesAPIKeyFromPlist() -> String? {
      guard let path = Bundle.main.path(forResource: "LesKitchens-Info", ofType: "plist"),
        let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject]
      else {
        print("⚠️ LesKitchens-Info.plist not found or could not be parsed")
        return nil
      }
      return dict["GooglePlacesAPIKey"] as? String
    }

    var body: some Scene {
      WindowGroup {
        if authViewModel.userSession != nil {
          ContentView()
            .environmentObject(authViewModel)
        } else {
          LoginView()
            .environmentObject(authViewModel)
        }
      }
    }
  }
}
