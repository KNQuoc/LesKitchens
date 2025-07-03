import Firebase
import FirebaseAuth
import Foundation
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var isAuthenticating = false
    @Published var error: String?
    @Published var isLoading = false
    @Published var userEmail: String = ""
    @Published var isAuthenticated: Bool = false
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        // Check if user is already logged in
        self.userSession = Auth.auth().currentUser
        self.userEmail = Auth.auth().currentUser?.email ?? ""
        self.isAuthenticated = Auth.auth().currentUser != nil

        // Listen for auth state changes
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.userSession = user
                self?.userEmail = user?.email ?? ""
                self?.isAuthenticated = user != nil
            }
        }

        #if DEBUG
            // For preview purposes only
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                // Provide mock data for previews
                self.userEmail = "user@example.com"
                self.isAuthenticated = true
            }
        #endif
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func login(withEmail email: String, password: String) {
        isAuthenticating = true
        error = nil
        isLoading = true

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isLoading = false

                if let error = error {
                    self.error = error.localizedDescription
                    print("Error signing in: \(error.localizedDescription)")
                    return
                }

                // Successfully signed in
                self.userSession = result?.user
                self.userEmail = result?.user.email ?? ""
                self.isAuthenticated = true
                print("User login successful")
            }
        }
    }

    func register(withEmail email: String, password: String, username: String) {
        isAuthenticating = true
        error = nil
        isLoading = true

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isLoading = false

                if let error = error {
                    self.error = error.localizedDescription
                    print("Error creating user: \(error.localizedDescription)")
                    return
                }

                guard let user = result?.user else {
                    self.error = "Unknown error occurred"
                    return
                }

                // Set display name
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("Error updating user profile: \(error.localizedDescription)")
                    }
                }

                // Set up user in Firestore
                self.setupUserInDatabase(user: user, username: username)

                // Successfully registered
                self.userSession = user
                self.userEmail = user.email ?? ""
                self.isAuthenticated = true
                print("User registration successful")
            }
        }
    }

    private func setupUserInDatabase(user: FirebaseAuth.User, username: String) {
        let db = Firestore.firestore()

        // Create user profile document
        let userData: [String: Any] = [
            "userId": user.uid,
            "email": user.email ?? "",
            "displayName": username,
            "username": username.lowercased().replacingOccurrences(of: " ", with: ""),
            "createdAt": FieldValue.serverTimestamp(),
        ]

        db.collection("users").document(user.uid).collection("profile").document("userProfile")
            .setData(userData) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.error = error.localizedDescription
                        print("Error setting up user in database: \(error.localizedDescription)")
                    } else {
                        print("User profile created successfully in Firestore")
                    }
                }
            }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()

            DispatchQueue.main.async {
                self.userSession = nil
                self.userEmail = ""
                self.isAuthenticated = false
                print("User signed out successfully")
            }
        } catch let error {
            self.error = error.localizedDescription
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    func resetPassword(withEmail email: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }

    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw NSError(
                    domain: "", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Client ID not found"])
            }

            // Configure Google Sign-In on main thread
            await MainActor.run {
                let config = GIDConfiguration(clientID: clientID)
                GIDSignIn.sharedInstance.configuration = config
            }

            // Get the root view controller on main thread
            let rootViewController = await MainActor.run {
                let scenes = UIApplication.shared.connectedScenes.first
                guard let windowScene = scenes as? UIWindowScene,
                    let window = windowScene.windows.first,
                    let rootVC = window.rootViewController
                else {
                    return nil as UIViewController?
                }
                return rootVC
            }

            guard let rootViewController = rootViewController else {
                throw NSError(
                    domain: "", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
            }

            // Perform Google Sign-In on main thread
            let result: GIDSignInResult = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController
            )

            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                throw NSError(
                    domain: "", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "ID token not found"])
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            await MainActor.run {
                self.userSession = authResult.user
                self.userEmail = authResult.user.email ?? ""
                self.isAuthenticated = true
                self.isLoading = false
            }

            // Set up user in database
            await MainActor.run {
                setupUserInDatabase(
                    user: authResult.user,
                    username: user.profile?.name ?? "User"
                )
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
                print("Error signing in with Google: \(error.localizedDescription)")
            }
        }
    }
}
