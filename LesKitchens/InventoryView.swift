import Firebase
import FirebaseAuth
import Foundation
import SwiftUI

// MARK: - Inventory View
struct InventoryView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false
    @State private var dropdownOpen = false
    @State private var selectedInventory: String?
    @State private var selectedGroupInventoryId: String?
    @AppStorage("selectedInventoryId") private var savedInventoryId: String?
    @AppStorage("selectedInventoryName") private var savedInventoryName: String?
    @State private var searchText: String = ""

    // Date formatter
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    // Load saved inventory selection
    private func loadInventoryFromUserDefaults() {
        if let savedId = savedInventoryId, let savedName = savedInventoryName {
            selectedInventory = savedName
            selectedGroupInventoryId = savedId
        }
    }

    // Filter items based on selected inventory
    private func shouldShowItem(_ item: InventoryItem) -> Bool {
        if let selectedId = selectedGroupInventoryId {
            return item.inventoryId == selectedId
        }
        return item.inventoryId == nil
    }

    // Helper view for dropdown menu
    private func dropdownMenuView() -> some View {
        VStack {
            // Dropdown header button
            Button(action: {
                withAnimation {
                    dropdownOpen.toggle()
                }
            }) {
                HStack {
                    Text(selectedInventory == nil ? "Personal Inventory" : selectedInventory!)
                        .font(.headline)

                    Image(systemName: "chevron.down")
                        .rotationEffect(Angle(degrees: dropdownOpen ? 180 : 0))
                }
                .foregroundColor(.primary)
                .padding(.vertical, 10)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Dropdown content
            if dropdownOpen {
                dropdownOptionsView()
            }
        }
        .padding(.top)
        .zIndex(1)  // Ensure dropdown appears above other content
    }

    // Helper view for dropdown options
    private func dropdownOptionsView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Personal inventory option
            Button(action: {
                selectedInventory = nil
                selectedGroupInventoryId = nil
                savedInventoryId = nil
                savedInventoryName = nil
                dropdownOpen = false
            }) {
                Text("Personal Inventory")
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(selectedInventory == nil ? Color.gray.opacity(0.2) : Color.clear)

            // Group inventory options
            ForEach(viewModel.groupInventories) { inventory in
                Button(action: {
                    selectedInventory = inventory.name
                    selectedGroupInventoryId = inventory.id
                    savedInventoryId = inventory.id
                    savedInventoryName = inventory.name
                    dropdownOpen = false
                }) {
                    Text(inventory.name)
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(
                    selectedInventory == inventory.name ? Color.gray.opacity(0.2) : Color.clear)
            }
        }
        .padding(.horizontal)
        .background(Color("CardColor"))
        .cornerRadius(10)
        .padding(.horizontal)
        .transition(.opacity)
    }

    // Extract inventory item into separate view
    private func inventoryItemView(item: InventoryItem) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(item.name)
                    .font(.body.bold())

                Spacer()

                Button(action: {
                    viewModel.deleteInventoryItem(id: item.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            Text("Quantity: \(item.quantity) \(item.unitDisplay)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let expirationDate = item.expirationDate {
                Text("Expires: \(itemFormatter.string(from: expirationDate))")
                    .font(.caption)
                    .foregroundColor(isNearExpiration(date: expirationDate) ? .orange : .secondary)
            }

            HStack {
                Spacer()

                Button(action: {
                    // Update item status to "low"
                    updateItemStatus(id: item.id, status: "low")
                }) {
                    Text("Mark Low")
                        .foregroundColor(Color("ActionColor"))
                        .font(.caption)
                }

                Button(action: {
                    // Update item status to "empty"
                    updateItemStatus(id: item.id, status: "empty")
                }) {
                    Text("Mark Empty")
                        .foregroundColor(Color("ActionColor"))
                        .font(.caption)
                }
                .padding(.leading, 10)
            }
        }
        .padding()
        .background(
            getStatusColor(status: item.status)
        )
        .cornerRadius(10)
    }

    // Helper function to check if item is near expiration (within 3 days)
    private func isNearExpiration(date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: date)
        return components.day ?? 0 <= 3 && components.day ?? 0 >= 0
    }

    // Helper function to get color based on item status
    private func getStatusColor(status: String) -> Color {
        switch status.lowercased() {
        case "low":
            return Color("CardColor").opacity(0.9)
        case "empty":
            return Color.red.opacity(0.1)
        default:
            return Color("CardColor")
        }
    }

    // Function to update item status in Firebase
    private func updateItemStatus(id: String, status: String) {
        viewModel.updateInventoryItemStatus(id: id, status: status)
    }

    // Empty state view
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No items in inventory")
                .font(.headline)

            Text("Add items to keep track of what you have in stock")
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
                Color("BackgroundColor").ignoresSafeArea()

                VStack {
                    // Inventory selector dropdown
                    dropdownMenuView()

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Spacer()
                    } else if viewModel.inventoryItems.filter(shouldShowItem).isEmpty {
                        Spacer()
                        emptyStateView()
                        Spacer()
                    } else {
                        // Inventory items list
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(viewModel.inventoryItems) { item in
                                    if shouldShowItem(item) {
                                        inventoryItemView(item: item)
                                    }
                                }
                            }
                            .padding()
                        }
                    }

                    Spacer()
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
            .navigationTitle("Kitchen Inventory")
            .sheet(isPresented: $showingAddItemView) {
                AddInventoryItemView(viewModel: viewModel)
            }
            .onAppear {
                // Check for selected inventory from groups navigation
                loadInventoryFromUserDefaults()

                // If we have a user, load inventory items
                if let currentUser = Auth.auth().currentUser {
                    viewModel.loadInventoryItems(userId: currentUser.uid) { _ in
                        // Items loaded
                    }
                }
            }
            .onTapGesture {
                // Close dropdown when tapping outside
                if dropdownOpen {
                    dropdownOpen = false
                }
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { oldValue, newValue in
                filterItems(searchText: newValue)
            }
        }
    }

    private func filterItems(searchText: String) {
        // Implementation of filterItems function
    }
}

// Add Inventory Item View
struct AddInventoryItemView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var itemName = ""
    @State private var itemQuantity = "1"
    @State private var itemUnit = "each"
    @State private var expirationDate: Date?
    @State private var hasExpirationDate = false
    @State private var selectedInventoryId: String? = nil
    @Environment(\.dismiss) private var dismiss

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
                Text("Add Inventory Item")
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.top, 5)
                    .frame(maxWidth: .infinity, alignment: .center)

                TextField("Item Name", text: $itemName)
                    .padding()
                    .background(Color.gray.opacity(0.2))
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
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Unit")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("each", text: $itemUnit)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Expiration date toggle
                Toggle("Has Expiration Date", isOn: $hasExpirationDate)
                    .padding(.vertical, 5)

                if hasExpirationDate {
                    DatePicker(
                        "Expiration Date",
                        selection: Binding<Date>(
                            get: { expirationDate ?? Date() },
                            set: { expirationDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .padding(.vertical, 5)
                }

                // Inventory selection
                if !viewModel.groupInventories.isEmpty {
                    Picker("Group Inventory", selection: $selectedInventoryId) {
                        Text("Personal Inventory").tag(nil as String?)
                        ForEach(viewModel.groupInventories) { inventory in
                            Text(inventory.name).tag(inventory.id as String?)
                        }
                    }
                    .padding(.vertical, 5)
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
                        if !itemName.isEmpty {
                            let quantity = Int(itemQuantity) ?? 1
                            let selectedDate = hasExpirationDate ? expirationDate : nil
                            let newItem = InventoryItem(
                                name: itemName,
                                quantity: quantity,
                                expirationDate: selectedDate,
                                inventoryId: selectedInventoryId
                            )
                            viewModel.addInventoryItem(
                                name: newItem.name,
                                quantity: newItem.quantity,
                                expirationDate: newItem.expirationDate,
                                inventoryId: newItem.inventoryId
                            )
                            dismiss()
                        }
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
            .frame(width: 350, height: 350)
        }
    }
}

#if DEBUG
    struct InventoryView_Previews: PreviewProvider {
        static var previews: some View {
            InventoryView(viewModel: KitchenViewModel())
                .onAppear {
                    // For previews, we'll check if Firebase is already configured
                    if FirebaseApp.app() == nil {
                        FirebaseApp.configure()
                    }
                }
        }
    }
#endif
