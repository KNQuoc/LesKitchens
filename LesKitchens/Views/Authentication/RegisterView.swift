import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var passwordsMatch = true

    var body: some View {
        VStack {
            // Title
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 30)
                .padding(.bottom, 30)

            // Registration Form
            VStack(spacing: 20) {
                TextField("Username", text: $username)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: confirmPassword) { oldValue, newValue in
                        passwordsMatch = password == newValue || newValue.isEmpty
                    }

                if !passwordsMatch {
                    Text("Passwords do not match")
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                // Error message
                if let error = authViewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                // Register button
                Button(action: {
                    if password == confirmPassword {
                        authViewModel.register(
                            withEmail: email, password: password, username: username)
                    } else {
                        passwordsMatch = false
                    }
                }) {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(
                    email.isEmpty || password.isEmpty || username.isEmpty || !passwordsMatch
                        || authViewModel.isAuthenticating
                )
                .opacity(
                    email.isEmpty || password.isEmpty || username.isEmpty || !passwordsMatch
                        || authViewModel.isAuthenticating ? 0.6 : 1)

                // Back to login button
                Button(action: {
                    dismiss()
                }) {
                    Text("Already have an account? Log In")
                        .foregroundColor(.blue)
                }
                .padding(.top)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
