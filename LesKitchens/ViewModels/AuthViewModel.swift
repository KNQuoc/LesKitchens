import Firebase
import FirebaseAuth
import Foundation
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var userSession: String?
    @Published var isAuthenticating = false
    @Published var error: String?
    @Published var isLoading = false

    init() {
        // Check if user is logged in
        self.userSession = UserDefaults.standard.string(forKey: "user_session")

        // Check if Firebase Auth already has a user
        if userSession == nil, let currentUser = Auth.auth().currentUser {
            // If Firebase has a user but our UserDefaults doesn't, update it
            userSession = currentUser.uid
            UserDefaults.standard.set(currentUser.uid, forKey: "user_session")
            print("Restored user session from Firebase Auth")
        }
    }

    func login(withEmail email: String, password: String) {
        isAuthenticating = true
        error = nil
        isLoading = true

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isLoading = false

                if let error = error {
                    self.error = error.localizedDescription
                    print("Login error: \(error.localizedDescription)")
                    return
                }

                guard let user = result?.user else {
                    self.error = "Unknown error occurred"
                    return
                }

                // Save user info to UserDefaults
                UserDefaults.standard.set(user.uid, forKey: "user_session")
                UserDefaults.standard.set(user.displayName ?? "", forKey: "user_displayname")
                UserDefaults.standard.set(user.email ?? "", forKey: "user_email")

                self.userSession = user.uid
                print("User logged in successfully: \(user.uid)")
            }
        }
    }

    func register(withEmail email: String, password: String, username: String) {
        isAuthenticating = true
        error = nil
        isLoading = true

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isLoading = false

                if let error = error {
                    self.error = error.localizedDescription
                    print("Registration error: \(error.localizedDescription)")
                    return
                }

                guard let user = result?.user else {
                    self.error = "Unknown error occurred"
                    return
                }

                // Create user profile
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("Failed to set display name: \(error.localizedDescription)")
                    } else {
                        print("Display name set successfully: \(username)")
                    }
                }

                // Save user info to UserDefaults
                UserDefaults.standard.set(user.uid, forKey: "user_session")
                UserDefaults.standard.set(username, forKey: "user_displayname")
                UserDefaults.standard.set(email, forKey: "user_email")

                self.userSession = user.uid
                print("User registered successfully: \(user.uid)")
            }
        }
    }

    func signOut() {
        do {
            // Sign out from Firebase
            try Auth.auth().signOut()

            // Clear user session
            UserDefaults.standard.removeObject(forKey: "user_session")
            UserDefaults.standard.removeObject(forKey: "user_displayname")
            UserDefaults.standard.removeObject(forKey: "user_email")
            self.userSession = nil

            print("User signed out successfully")
        } catch let error {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    func signIn(email: String, password: String) {
        isLoading = true

        // Simulate sign in process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Save user session and info
            UserDefaults.standard.set("user-123", forKey: "user_session")
            UserDefaults.standard.set("John Doe", forKey: "user_displayname")
            UserDefaults.standard.set(email, forKey: "user_email")

            self.userSession = "user-123"
            self.isLoading = false
        }
    }
}
