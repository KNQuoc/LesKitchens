import Firebase
import FirebaseAuth
import SwiftUI
import UIKit

// Extensions to provide unit information
extension ShoppingItem {
    var unitDisplay: String {
        // Retrieve unit from a database or use a default based on item name
        // This is a temporary solution until the model is updated with a proper unit property
        return GroceryDatabase.shared.getUnitForItem(name)
    }
}

extension InventoryItem {
    var unitDisplay: String {
        // Retrieve unit from a database or use a default based on item name
        return GroceryDatabase.shared.getUnitForItem(name)
    }
}

// Main View - TabView Container
struct ContentView: View {
    @StateObject private var viewModel = KitchenViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    // Create a computed property for the alert instead of modifying @Published property directly in body
    private var errorAlert: Binding<AlertItem?> {
        Binding(
            get: {
                self.viewModel.errorMessage.map { AlertItem(message: $0) }
            },
            set: { _ in
                // Use DispatchQueue to move this state change outside the view update cycle
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            // Background view
            BackgroundView()

            // Tab view content
            TabView(selection: $viewModel.selectedTab) {
                ShoppingListView(viewModel: viewModel)
                    .tabItem {
                        Label("Shopping List", systemImage: "cart")
                    }
                    .tag(0)

                InventoryView(viewModel: viewModel)
                    .tabItem {
                        Label("Inventory", systemImage: "archivebox")
                    }
                    .tag(1)

                GroupsView(viewModel: viewModel)
                    .tabItem {
                        Label("Group", systemImage: "person.2")
                    }
                    .tag(2)

                ProfileView()
                    .tabItem {
                        Label("User", systemImage: "person.circle")
                    }
                    .tag(3)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .background(Color.black.opacity(0.2))
                        .ignoresSafeArea()
                }
            }
            .alert(item: errorAlert) { alertItem in
                Alert(
                    title: Text("Error"),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                // Set tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color("TabBarColor"))

                // Configure item appearance for both normal and selected states
                let itemAppearance = UITabBarItemAppearance()
                itemAppearance.normal.iconColor = .white
                itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
                itemAppearance.selected.iconColor = .white
                itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

                appearance.stackedLayoutAppearance = itemAppearance
                appearance.inlineLayoutAppearance = itemAppearance
                appearance.compactInlineLayoutAppearance = itemAppearance

                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance

                // Set nav bar appearance
                let navAppearance = UINavigationBarAppearance()
                navAppearance.configureWithOpaqueBackground()
                navAppearance.backgroundColor = UIColor(Color("BackgroundColor"))
                UINavigationBar.appearance().standardAppearance = navAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            }
        }
    }
}

// Shopping List View (formerly Grocery List)
struct ShoppingListView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false

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

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.shoppingItems) { item in
                            shoppingItemView(item: item)
                        }
                    }
                    .padding()
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
        }
    }
}

// Inventory View
struct InventoryView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false
    @State private var selectedInventory: String? = nil
    @State private var dropdownOpen = false
    @State private var selectedGroupInventoryId: String? = nil

    // Date formatter
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    // Helper function to load inventory selection from UserDefaults
    private func loadInventoryFromUserDefaults() {
        if let inventoryName = UserDefaults.standard.string(forKey: "selected_inventory_name"),
            let inventoryId = UserDefaults.standard.string(forKey: "selected_inventory_id")
        {
            selectedInventory = inventoryName
            selectedGroupInventoryId = inventoryId

            // Clear the values
            UserDefaults.standard.removeObject(forKey: "selected_inventory_name")
            UserDefaults.standard.removeObject(forKey: "selected_inventory_id")
        }
    }

    // Helper function to check if an item should be shown
    private func shouldShowItem(_ item: InventoryItem) -> Bool {
        // Show personal inventory items when no inventory is selected
        let isPersonalItem = selectedInventory == nil && item.inventoryId == nil

        // Show items that belong to the selected group inventory
        let isSelectedGroupItem = item.inventoryId == selectedGroupInventoryId

        return isPersonalItem || isSelectedGroupItem
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

            HStack {
                Spacer()

                Button(action: {
                    // Mark as low
                }) {
                    Text("Mark Low")
                        .foregroundColor(Color("ActionColor"))
                        .font(.caption)
                }

                Button(action: {
                    // Mark as empty
                }) {
                    Text("Mark Empty")
                        .foregroundColor(Color("ActionColor"))
                        .font(.caption)
                }
                .padding(.leading, 10)
            }
        }
        .padding()
        .background(Color("CardColor"))
        .cornerRadius(10)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

                VStack {
                    // Inventory selector dropdown
                    dropdownMenuView()

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
            }
            .onTapGesture {
                // Close dropdown when tapping outside
                if dropdownOpen {
                    dropdownOpen = false
                }
            }
        }
    }
}

// Groups View (formerly Group List)
struct GroupsView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false
    @State private var selectedInventoryToView: GroupInventory? = nil

    // Helper functions to simplify complex operations
    private func navigateToInventory(_ inventory: GroupInventory?) {
        guard let inventory = inventory else { return }

        // Navigate to inventory tab
        viewModel.selectedTab = 1

        // Save inventory selection to UserDefaults
        UserDefaults.standard.set(inventory.name, forKey: "selected_inventory_name")
        UserDefaults.standard.set(inventory.id, forKey: "selected_inventory_id")

        // Reset selection after navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedInventoryToView = nil
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(viewModel.groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.name)
                                    .font(.headline)

                                Text("\(group.memberCount) members")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if group.owner {
                                    Text("Inventories:")
                                        .font(.caption)
                                        .padding(.top, 4)

                                    VStack(spacing: 8) {
                                        // Filter inventories by group
                                        ForEach(
                                            viewModel.groupInventories.filter {
                                                $0.groupId == group.id
                                            }
                                        ) { inventory in
                                            // Separate the nested buttons to simplify the structure
                                            VStack {
                                                HStack {
                                                    // Main navigation button
                                                    Button(action: {
                                                        // Navigate to this inventory view
                                                        selectedInventoryToView = inventory
                                                        navigateToInventory(inventory)
                                                    }) {
                                                        HStack {
                                                            Text(inventory.name)
                                                                .font(.caption)
                                                                .foregroundColor(
                                                                    Color("ActionColor"))

                                                            Spacer()

                                                            Image(systemName: "chevron.right")
                                                                .foregroundColor(
                                                                    Color("ActionColor")
                                                                )
                                                                .font(.caption)
                                                        }
                                                    }
                                                    .buttonStyle(PlainButtonStyle())

                                                    // Separate delete button
                                                    Button(action: {
                                                        // Delete inventory
                                                    }) {
                                                        Image(systemName: "trash")
                                                            .foregroundColor(.primary)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                            .contentShape(Rectangle())
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color("CardColor").opacity(0.5))
                                            .cornerRadius(8)
                                        }

                                        Button(action: {
                                            // Add inventory
                                        }) {
                                            Text("Add Inventory")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity)
                                                .background(Color("ActionColor"))
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                            .padding()
                            .background(Color("CardColor"))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
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
            .navigationTitle("Group Kitchens")
            .sheet(isPresented: $showingAddItemView) {
                Text("Group creation would go here")
            }
        }
    }
}

// Add Shopping Item View (formerly Add Grocery Item)
struct AddShoppingItemView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var itemName = ""
    @State private var itemQuantity = "1"
    @State private var itemUnit = "each"
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
                Text("Add Shopping Item")
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.top, 5)
                    .frame(maxWidth: .infinity, alignment: .center)

                TextField("Item Name", text: $itemName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: itemName) { _ in
                        updateUnitBasedOnItem()
                    }

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("1", text: $itemQuantity)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Unit")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("each", text: $itemUnit)
                            .padding()
                            .background(Color(.systemGray6))
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
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Button(action: {
                        if !itemName.isEmpty {
                            let quantity = Int(itemQuantity) ?? 1
                            viewModel.addShoppingItem(
                                name: itemName, quantity: quantity, groupItem: false)
                            dismiss()
                        }
                    }) {
                        Text("Add")
                            .foregroundColor(.green)
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
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: itemName) { _ in
                        updateUnitBasedOnItem()
                    }

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("1", text: $itemQuantity)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Unit")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("each", text: $itemUnit)
                            .padding()
                            .background(Color(.systemGray6))
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
                            viewModel.addInventoryItem(
                                name: itemName,
                                quantity: quantity,
                                expirationDate: hasExpirationDate ? expirationDate : nil,
                                inventoryId: selectedInventoryId
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

// Alert Item for displaying errors
struct AlertItem: Identifiable {
    var id = UUID()
    var message: String
}

#Preview {
    ContentView()
}
