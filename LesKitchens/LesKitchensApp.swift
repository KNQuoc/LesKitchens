//
//  LesKitchensApp.swift
//  LesKitchens
//
//  Created by Quoc Ngo on 4/1/25.
//

import CoreLocation
import Firebase
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

    // Start background location services immediately and after a delay
    // Try immediate startup first
    setupLocationServices()

    // Then try again after a delay to ensure app is fully launched
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      print("🔍 DEBUG: Starting location services after delay")
      self.setupLocationServices()
    }
  }

  private func setupLocationServices() {
    #if canImport(CoreLocation)
      print("🔍 DEBUG: CoreLocation is available")

      // Create location manager for permissions
      let manager = CLLocationManager()

      // Request permissions - make sure to set a delegate to trigger the permission dialog
      print("🔍 DEBUG: Requesting location permissions")
      let delegate = LocationPermissionDelegate()
      manager.delegate = delegate  // Keep a strong reference via the delegate property
      manager.requestWhenInUseAuthorization()  // Start with when in use

      // After a short delay, request always authorization
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        manager.requestAlwaysAuthorization()
      }

      // Log current status using the non-deprecated API in iOS 14+
      let authStatus: CLAuthorizationStatus
      if #available(iOS 14.0, *) {
        authStatus = manager.authorizationStatus
      } else {
        // Fallback for older iOS versions
        authStatus = CLLocationManager.authorizationStatus()
      }
      print("🔍 DEBUG: Current location authorization: \(authStatus.rawValue)")

      // Try to start services with LocationServicesManager first (our main implementation)
      print("🔍 DEBUG: Attempting to start via LocationServicesManager...")

      // More direct approach using the LocationServicesManager we created
      guard let namespaceName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String else {
        print("⚠️ Could not get bundle name")
        return
      }

      let className = "\(namespaceName).LocationServicesManager"
      print("🔍 DEBUG: Looking for class: \(className)")

      if let managerClass = NSClassFromString(className) as? NSObject.Type {
        print("🔍 DEBUG: Found LocationServicesManager class")

        // Try the bootstrap method first (preferred)
        let bootstrapSelector = NSSelectorFromString("bootstrap")
        if managerClass.responds(to: bootstrapSelector) {
          print("🔍 DEBUG: Calling bootstrap method")
          let _ = managerClass.perform(bootstrapSelector)
          print("✅ Successfully bootstrapped location services")

          // Force a value update to UserDefaults to enable the UI toggle
          UserDefaults.standard.set(true, forKey: "grocery_notifications_enabled")
          return
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
            return
          } else {
            print("⚠️ Shared instance doesn't respond to startServices")
          }
        } else {
          print("⚠️ Couldn't get shared instance")
        }
      } else {
        print("⚠️ LocationServicesManager class not found")
      }

      // Fallback to basic implementation if the main one didn't work
      print("🔍 DEBUG: Falling back to basic location services...")
      LocationServicesReference.shared.setupBasicLocationServices()
    #else
      print("⚠️ CoreLocation not available on this platform")
    #endif
  }
}

// Delegate class to properly handle location permission callbacks
class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
  // Keep a reference to prevent it from being deallocated
  static let shared = LocationPermissionDelegate()

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // Handle iOS 14+ authorization changes
    if #available(iOS 14.0, *) {
      let status = manager.authorizationStatus
      print("🔍 DEBUG: LocationPermissionDelegate - Authorization changed to: \(status.rawValue)")

      // If we have permission, try to start the location services manager
      if status == .authorizedAlways || status == .authorizedWhenInUse {
        print(
          "🔍 DEBUG: LocationPermissionDelegate - We have permission, trying to restart services")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          AppSetupHelper.shared.initializeLocationServices()
        }
      }
    }
  }

  // For iOS 13 and earlier
  func locationManager(
    _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
  ) {
    print("🔍 DEBUG: LocationPermissionDelegate - Authorization changed to: \(status.rawValue)")

    // If we have permission, try to start the location services manager
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      print("🔍 DEBUG: LocationPermissionDelegate - We have permission, trying to restart services")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        AppSetupHelper.shared.initializeLocationServices()
      }
    }
  }
}

@main
struct LesKitchensApp: App {
  @StateObject var authViewModel = AuthViewModel()

  init() {
    // Initialize Firebase and location services using the helper class
    AppSetupHelper.shared.initializeFirebase()
    AppSetupHelper.shared.initializeLocationServices()
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
