import GoogleSignInSwift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegistration = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Use color asset that respects dark mode
                Color("BackgroundColor")
                    .ignoresSafeArea()

                // Content
                VStack {
                    // Logo
                    Image("Kinette")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding(.top, 50)

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

                        // Divider with "or" text
                        HStack {
                            VStack { Divider() }.padding(.horizontal, 8)
                            Text("or")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                            VStack { Divider() }.padding(.horizontal, 8)
                        }
                        .padding(.vertical, 8)

                        // Google Sign-In button
                        GoogleSignInButton(action: {
                            Task {
                                await authViewModel.signInWithGoogle()
                            }
                        })
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .cornerRadius(8)
                        .padding(.horizontal, 0)

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

// Add the WaveShape struct definition for LoginView
struct LoginWaveShape: Shape {
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

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
