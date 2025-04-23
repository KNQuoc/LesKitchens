import Firebase
import FirebaseAuth
import Foundation
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
                        Spacer()

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
            .onAppear {
                // If we have a user, load shopping items
                if let currentUser = Auth.auth().currentUser {
                    viewModel.loadShoppingItems(userId: currentUser.uid) { _ in
                        // Items loaded
                    }
                }
            }
        }
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
}
