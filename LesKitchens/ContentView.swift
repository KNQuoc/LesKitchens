import Firebase
import FirebaseAuth
import SwiftUI

// Main View - TabView Container
struct ContentView: View {
    @StateObject private var kitchenViewModel = KitchenViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertItem: AlertItem?

    private var errorAlert: AlertItem? {
        if let errorMessage = kitchenViewModel.errorMessage {
            return AlertItem(message: errorMessage)
        }
        return nil
    }

    var body: some View {
        ZStack {
            if authViewModel.isAuthenticated {
                // Main app content without separate BackgroundView
                VStack(spacing: 0) {
                    // Tab view content
                    TabView(selection: $selectedTab) {
                        ShoppingListView(viewModel: kitchenViewModel)
                            .tabItem {
                                Label("Shopping", systemImage: "cart")
                            }
                            .tag(0)

                        InventoryView(viewModel: kitchenViewModel)
                            .tabItem {
                                Label("Inventory", systemImage: "archivebox")
                            }
                            .tag(1)

                        GroupsView(viewModel: kitchenViewModel)
                            .tabItem {
                                Label("Group", systemImage: "person.3")
                            }
                            .tag(2)

                        ProfileView()
                            .tabItem {
                                Label("User", systemImage: "person.circle")
                            }
                            .tag(3)
                    }
                }
                .overlay {
                    if kitchenViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.4))
                    }
                }
                .onAppear {
                    // Load data when user is authenticated
                    if let userId = authViewModel.userSession?.uid {
                        kitchenViewModel.loadUserData(userId: userId)
                    }
                }
            } else {
                LoginView()
            }
        }
        .alert(
            item: Binding(
                get: { errorAlert },
                set: { _ in kitchenViewModel.errorMessage = nil }
            )
        ) { alert in
            Alert(
                title: Text("Error"),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#if DEBUG
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
#endif
