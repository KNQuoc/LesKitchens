import Firebase
import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var groceryNotificationsEnabled = false

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color("ActionColor"))
                        .padding(.top, 50)

                    Text(authViewModel.userEmail)
                        .font(.headline)

                    Button(action: {
                        authViewModel.signOut()
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("ActionColor"))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 50)
                    .padding(.top, 30)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
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

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}
