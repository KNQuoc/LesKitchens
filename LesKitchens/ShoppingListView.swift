import AVFoundation
import CoreLocation
import Firebase
import FirebaseAuth
import Foundation
import Speech
import SwiftUI

#if DEBUG
    import Firebase
    import FirebaseAuth
#endif

// IMPORTANT: Add Models.swift to your project and make sure it's in the compile sources
// The file should be added before all the view files

// Shopping List View (formerly Grocery List)
struct ShoppingListView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false
    @State private var showingVoiceAssistant = false
    @State private var searchText = ""

    // Extract shopping item into separate view
    private func shoppingItemView(item: ShoppingItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.body.bold())
                Text("Quantity: \(item.quantity) \(item.unitDisplay)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                viewModel.moveToInventory(from: item)
            }) {
                Text("Move to Inventory")
                    .font(.caption)
                    .foregroundColor(Color("ActionColor"))
            }

            Button(action: {
                viewModel.deleteShoppingItem(id: item.id)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.primary)
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color("CardColor"))
        .cornerRadius(10)
    }

    // Empty state view
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Image("Kinette")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.bottom, 10)

            Text("Your shopping list is empty")
                .font(.headline)

            Text("Add items to your shopping list to keep track of what you need to buy")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                showingAddItemView = true
            }) {
                Text("Add Item")
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color("ActionColor"))
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .padding()
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Use color asset that respects dark mode
                Color("BackgroundColor")
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if viewModel.shoppingItems.isEmpty {
                    emptyStateView()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            // Add custom search bar with background that respects dark mode
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)

                                TextField("Search", text: $searchText)
                                    .foregroundColor(.primary)
                                    .onChange(of: searchText) { oldValue, newValue in
                                        filterItems(searchText: newValue)
                                    }

                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color("CardColor"))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.top, 8)

                            ForEach(viewModel.shoppingItems) { item in
                                shoppingItemView(item: item)
                            }
                        }
                        .padding()
                    }
                }

                VStack {
                    Spacer()

                    HStack {
                        // Add voice assistant button
                        Button(action: {
                            showingVoiceAssistant = true
                        }) {
                            Image(systemName: "mic.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color("WaveColor"))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                        }
                        .padding()

                        Spacer()

                        // Debug button for widget data - only in DEBUG builds
                        #if DEBUG
                            Button(action: {
                                // Save debug data for widget testing
                                debugSaveWidgetData()
                            }) {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                            }
                        #endif

                        Button(action: {
                            showingAddItemView = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color("ActionColor"))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Shopping List")
            .sheet(isPresented: $showingAddItemView) {
                AddShoppingItemView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingVoiceAssistant) {
                VoiceAssistantView(viewModel: viewModel)
            }
            .onAppear {
                // If we have a user, load shopping items
                if let currentUser = Auth.auth().currentUser {
                    viewModel.loadShoppingItems(userId: currentUser.uid) { _ in
                        // Items loaded
                        // Save shopping items count to shared UserDefaults for widget access
                        self.saveShoppingItemsToUserDefaults()
                    }
                }
            }
        }
    }

    // Save shopping list info to shared UserDefaults for widget access
    private func saveShoppingItemsToUserDefaults() {
        let sharedDefaults = UserDefaults(suiteName: "group.KitchenLabs.LesKitchens")

        // Save shopping item count
        sharedDefaults?.set(viewModel.shoppingItems.count, forKey: "shopping_items_count")

        // Also save the actual items so widget can display them if needed
        let itemNames = viewModel.shoppingItems.map { $0.name }
        sharedDefaults?.set(itemNames, forKey: "shopping_items")

        // Add timestamp for when shopping list was last updated
        sharedDefaults?.set(Date(), forKey: "shopping_list_last_updated")

        sharedDefaults?.synchronize()

        print(
            "✅ Saved \(viewModel.shoppingItems.count) shopping items to shared UserDefaults for widget access"
        )
    }

    private func filterItems(searchText: String) {
        // Implementation of filterItems function
    }

    // Add Shopping Item View (formerly Add Grocery Item)
    struct AddShoppingItemView: View {
        @ObservedObject var viewModel: KitchenViewModel
        @State private var itemName = ""
        @State private var itemQuantity = "1"
        @State private var itemUnit = "each"
        @Environment(\.dismiss) private var dismiss
        @State private var isGroupItem = false

        // Update unit when item name changes
        private func updateUnitBasedOnItem() {
            if !itemName.isEmpty {
                itemUnit = GroceryDatabase.shared.getUnitForItem(itemName)
            }
        }

        var body: some View {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text("Add Shopping Item")
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.top, 5)
                        .frame(maxWidth: .infinity, alignment: .center)

                    TextField("Item Name", text: $itemName)
                        .padding()
                        .background(Color("CardColor").opacity(0.8))
                        .cornerRadius(8)
                        .onChange(of: itemName) { oldValue, newValue in
                            updateUnitBasedOnItem()
                        }

                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Quantity")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("1", text: $itemQuantity)
                                .padding()
                                .background(Color("CardColor").opacity(0.8))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Unit")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("each", text: $itemUnit)
                                .padding()
                                .background(Color("CardColor").opacity(0.8))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Spacer()

                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .foregroundColor(Color("ActionColor"))
                        }

                        Spacer()

                        Button(action: {
                            let newItem = ShoppingItem(
                                name: itemName,
                                quantity: Int(itemQuantity) ?? 1,
                                groupItem: isGroupItem
                            )
                            viewModel.addShoppingItem(
                                name: newItem.name,
                                quantity: newItem.quantity,
                                groupItem: newItem.groupItem
                            )
                            dismiss()
                        }) {
                            Text("Add")
                                .foregroundColor(Color("ActionColor"))
                        }
                        .disabled(itemName.isEmpty)
                    }
                }
                .padding()
                .background(Color("BackgroundColor"))
                .cornerRadius(16)
                .frame(width: 350, height: 250)
            }
        }
    }

    // Add the WaveShape struct definition
    struct ShoppingWaveShape: Shape {
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
            let finalY =
                sin(finalRelativeX * frequency * .pi * 2 + phase) * amplitude + rect.height / 2
            path.addLine(to: CGPoint(x: finalX, y: finalY))

            // Line to the bottom-trailing corner
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))

            // Close the path
            path.closeSubpath()

            return path
        }
    }

    #if DEBUG
        // Preview for development
        struct ShoppingListView_Previews: PreviewProvider {
            static var previews: some View {
                let viewModel = KitchenViewModel()
                ShoppingListView(viewModel: viewModel)
                    .onAppear {
                        // For previews, we'll check if Firebase is already configured
                        if FirebaseApp.app() == nil {
                            FirebaseApp.configure()
                        }
                    }
            }
        }
    #endif

    // Debug function to save test data for widget
    #if DEBUG
        private func debugSaveWidgetData() {
            print("📲 Debug: Manually saving widget test data")

            // Call the debug function in GooglePlacesService
            let placesService = GooglePlacesService()
            placesService.saveDebugStoreDataForWidget()

            // Also save shopping items to make sure they're accessible
            saveShoppingItemsToUserDefaults()
        }
    #endif

    // Debug function to analyze location data
    private func debugLocationData() {
        print("\n🔍 DEBUG - MANUALLY CHECKING LOCATION DATA")

        // Check what's in UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.KitchenLabs.LesKitchens")

        print("CURRENT USERDEFAULTS DATA:")
        print("-------------------------")
        if let storeName = sharedDefaults?.string(forKey: "nearest_store_name") {
            print("Store name: \(storeName)")
        } else {
            print("No store name found")
        }

        if let distance = sharedDefaults?.double(forKey: "nearest_store_distance") {
            print("Distance: \(String(format: "%.2f", distance)) miles")
        } else {
            print("No distance found")
        }

        if let lastUpdated = sharedDefaults?.object(forKey: "nearest_store_last_updated") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            print("Last updated: \(formatter.string(from: lastUpdated))")

            let elapsed = Date().timeIntervalSince(lastUpdated)
            print("Data age: \(Int(elapsed/60)) minutes ago")
        } else {
            print("No last updated timestamp found")
        }

        // Get location services and force an update
        let locationManager = LocationServicesManager.shared
        print("\nREQUESTING LOCATION UPDATE")
        // Request a fresh location update
        locationManager.startServices()
        print("Location update requested - check console for results")

        // Get Google Places service and force debug data save
        let googlePlacesService = GooglePlacesService()
        print("\nSAVING DEBUG STORE DATA")
        googlePlacesService.saveDebugStoreDataForWidget()

        print("-------------------------")
    }
}
