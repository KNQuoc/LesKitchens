import CoreLocation
import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

// This class is now deprecated - use LocationServicesManager instead
@available(*, deprecated, message: "Use LocationServicesManager instead")
class LocationService {
    // Singleton instance
    static let shared = LocationService()

    // Reference to location services manager
    // The LocationServicesManager is in same module but linter doesn't recognize it
    // Either ensure it's compiled first or use indirect access
    private var servicesManager: Any? = nil
    private var isServicesManagerInitialized = false

    // Flag to track if service is running
    private var isRunning = false

    // Private initializer for singleton
    private init() {
        print("⚠️ LocationService is deprecated. Use LocationServicesManager directly instead.")

        // Try to initialize using reflection to avoid direct dependency
        initializeServicesManager()
    }

    // Initialize services manager using reflection to avoid direct class dependency
    private func initializeServicesManager() {
        if let managerClass = NSClassFromString("LesKitchens.LocationServicesManager")
            as? NSObject.Type,
            let sharedProperty = managerClass.value(forKey: "shared")
        {
            servicesManager = sharedProperty
            isServicesManagerInitialized = true
            print("Successfully initialized services manager via reflection")
        } else {
            print("⚠️ Failed to initialize LocationServicesManager - some functions won't work")
        }
    }

    // Start the location service
    func start() {
        guard !isRunning else {
            print("Location service already running")
            return
        }

        print("Starting location service via LocationServicesManager")

        // Use the services manager via reflection
        if isServicesManagerInitialized,
            let manager = servicesManager as? NSObject
        {
            // Create the selector without optional binding
            let startMethod = NSSelectorFromString("startServices")

            // Check if manager responds to selector
            if manager.responds(to: startMethod) {
                manager.perform(startMethod)
                print("Successfully started location services")
            } else {
                print("⚠️ Manager doesn't respond to startServices method")
            }
        } else {
            print("⚠️ Cannot start location services - manager not initialized")
        }

        // Register for app lifecycle notifications to manage service state
        #if os(iOS)
            registerForAppStateNotifications()
        #endif

        isRunning = true
    }

    // Stop the location service
    func stop() {
        guard isRunning else {
            print("Location service not running")
            return
        }

        print("Stopping location service")

        // Stop location services via reflection
        if isServicesManagerInitialized,
            let manager = servicesManager as? NSObject
        {
            // Create the selector without optional binding
            let stopMethod = NSSelectorFromString("stopServices")

            // Check if manager responds to selector
            if manager.responds(to: stopMethod) {
                manager.perform(stopMethod)
                print("Successfully stopped location services")
            } else {
                print("⚠️ Manager doesn't respond to stopServices method")
            }
        } else {
            print("⚠️ Cannot stop location services - manager not initialized")
        }

        // Unregister from notifications
        #if os(iOS)
            unregisterFromAppStateNotifications()
        #endif

        isRunning = false
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

        // Handle app entering background
        @objc private func handleAppDidEnterBackground() {
            print("App entered background - ensuring location updates continue")
        }

        // Handle app entering foreground
        @objc private func handleAppWillEnterForeground() {
            print("App entered foreground")
            if isRunning {
                // Nothing needed - LocationServicesManager handles this
            }
        }

        // Handle app termination
        @objc private func handleAppWillTerminate() {
            print("App will terminate")
            // Do any cleanup if needed
        }
    #endif
}
