import Firebase
import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var groceryNotificationsEnabled = false

    var body: some View {
        NavigationView {
            ZStack {
                // Use color asset that respects dark mode
                Color("BackgroundColor")
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image("Kinette")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .padding(.top, 40)

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

// Add the WaveShape struct definition for ProfileView
struct ProfileWaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Safety check for zero width
        if rect.width <= 0 {
            return path
        }

        // Move to the bottom-leading corner
        path.move(to: CGPoint(x: 0, y: rect.height))

        // Draw the wave
        let step: CGFloat = 5
        for x in stride(from: 0, to: rect.width, by: step) {
            let relativeX = x / rect.width
            let y = sin(relativeX * frequency * .pi * 2 + phase) * amplitude + rect.height / 2
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Add final point
        let finalX = rect.width
        let finalRelativeX = finalX / rect.width
        let finalY = sin(finalRelativeX * frequency * .pi * 2 + phase) * amplitude + rect.height / 2
        path.addLine(to: CGPoint(x: finalX, y: finalY))

        // Line to the bottom-trailing corner
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))

        // Close the path
        path.closeSubpath()

        return path
    }
}
