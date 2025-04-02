import Firebase
import FirebaseAuth
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var isAuthenticating = false
    @Published var error: String?

    init() {
        self.userSession = Auth.auth().currentUser
    }

    func login(withEmail email: String, password: String) {
        isAuthenticating = true
        error = nil

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false

                if let error = error {
                    self.error = error.localizedDescription
                    return
                }

                self.userSession = result?.user
            }
        }
    }

    func register(withEmail email: String, password: String, username: String) {
        isAuthenticating = true
        error = nil

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false

                if let error = error {
                    self.error = error.localizedDescription
                    return
                }

                guard let user = result?.user else { return }

                // Create user profile
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("Failed to set display name: \(error.localizedDescription)")
                    }
                }

                self.userSession = user
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
