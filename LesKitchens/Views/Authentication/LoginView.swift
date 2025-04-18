import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegistration = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color("BackgroundColor")
                    .ignoresSafeArea()

                // Content
                VStack {
                    // Logo
                    Image(systemName: "basket.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color("ActionColor"))
                        .padding(.top, 50)

                    Text("Kitchen Assistant")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 50)

                    // Login Form
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color("CardColor"))
                            .cornerRadius(8)

                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color("CardColor"))
                            .cornerRadius(8)

                        // Error message
                        if let error = authViewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }

                        // Login button
                        Button(action: {
                            authViewModel.login(withEmail: email, password: password)
                        }) {
                            Text("Log In")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("ActionColor"))
                                .cornerRadius(8)
                        }
                        .disabled(
                            email.isEmpty || password.isEmpty || authViewModel.isAuthenticating
                        )
                        .opacity(
                            email.isEmpty || password.isEmpty || authViewModel.isAuthenticating
                                ? 0.6 : 1)

                        // Register navigation
                        Button(action: {
                            showRegistration = true
                        }) {
                            Text("Don't have an account? Sign Up")
                                .foregroundColor(Color("ActionColor"))
                        }
                        .padding(.top)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showRegistration) {
                RegisterView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
