import Firebase
import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var groceryNotificationsEnabled = false

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    // User info section
                    VStack(alignment: .center) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(Color("ActionColor"))
                            .padding(.top, 30)

                        Text(userDisplayName)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(userEmail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 30)

                    // Settings list
                    List {
                        Section(header: Text("Notifications")) {
                            Toggle(isOn: $groceryNotificationsEnabled) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                        .foregroundColor(Color("ActionColor"))
                                    Text("Grocery Store Notifications")
                                }
                            }
                            .onChange(of: groceryNotificationsEnabled) {
                                toggleLocationServices(enabled: groceryNotificationsEnabled)
                            }
                        }

                        Section(header: Text("Account")) {
                            Button(action: {
                                authViewModel.signOut()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.square")
                                        .foregroundColor(.red)
                                    Text("Sign Out")
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        Section(header: Text("App Info")) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Color("ActionColor"))
                                Text("Version 1.0")
                                Spacer()
                            }

                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(Color("ActionColor"))
                                Text("Contact Support")
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .background(Color.clear)
                }
            }
            .navigationTitle("User Profile")
            .onAppear {
                checkLocationServicesStatus()
            }
        }
    }

    // Get the user's display name or fallback to "User"
    private var userDisplayName: String {
        let userDefaults = UserDefaults.standard
        return userDefaults.string(forKey: "user_displayname") ?? "User"
    }

    // Get the user's email or fallback to empty string
    private var userEmail: String {
        let userDefaults = UserDefaults.standard
        return userDefaults.string(forKey: "user_email") ?? ""
    }

    // Toggle location services
    private func toggleLocationServices(enabled: Bool) {
        #if canImport(CoreLocation)
            if enabled {
                // Start location services
                if let servicesManager = NSClassFromString("LesKitchens.LocationServicesManager")
                    as? NSObject.Type,
                    let shared = servicesManager.value(forKey: "shared") as? NSObject
                {
                    // Call the startServices method
                    _ = shared.perform(Selector(("startServices")))
                    print("Location services started")
                    UserDefaults.standard.set(true, forKey: "grocery_notifications_enabled")
                }
            } else {
                // Stop location services
                if let servicesManager = NSClassFromString("LesKitchens.LocationServicesManager")
                    as? NSObject.Type,
                    let shared = servicesManager.value(forKey: "shared") as? NSObject
                {
                    // Call the stopServices method
                    _ = shared.perform(Selector(("stopServices")))
                    print("Location services stopped")
                    UserDefaults.standard.set(false, forKey: "grocery_notifications_enabled")
                }
            }
        #endif
    }

    // Check if location services are enabled
    private func checkLocationServicesStatus() {
        #if canImport(CoreLocation)
            // Check user defaults first
            let userDefaults = UserDefaults.standard
            self.groceryNotificationsEnabled = userDefaults.bool(
                forKey: "grocery_notifications_enabled")

            // Also verify with the actual service
            if let servicesManager = NSClassFromString("LesKitchens.LocationServicesManager")
                as? NSObject.Type,
                let shared = servicesManager.value(forKey: "shared") as? NSObject,
                let isEnabledMethod = shared.perform(Selector(("isEnabled")))
            {
                // Update the toggle if there's a mismatch
                if let isEnabled = isEnabledMethod.takeRetainedValue() as? Bool {
                    if isEnabled != groceryNotificationsEnabled {
                        self.groceryNotificationsEnabled = isEnabled
                        UserDefaults.standard.set(
                            isEnabled, forKey: "grocery_notifications_enabled")
                    }
                }
            }
        #endif
    }
}
