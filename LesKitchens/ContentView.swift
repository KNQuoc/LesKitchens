import Firebase
import FirebaseAuth
import SwiftUI

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
        TabView(selection: $viewModel.selectedTab) {
            ShoppingListView(viewModel: viewModel)
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }
                .tag(0)

            InventoryView(viewModel: viewModel)
                .tabItem {
                    Label("Inventory", systemImage: "archivebox")
                }
                .tag(1)

            GroupsView(viewModel: viewModel)
                .tabItem {
                    Label("Groups", systemImage: "person.2")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
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
    }
}

// Shopping List View (formerly Grocery List)
struct ShoppingListView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.shoppingItems) { item in
                    HStack {
                        Button(action: {
                            // Toggle completed status (we'd need to add this feature to our model)
                            // For now, let's just delete the item as a placeholder
                            viewModel.deleteShoppingItem(id: item.id)
                        }) {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())

                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text("Quantity: \(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if item.groupItem {
                                Text("Group Item")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        Spacer()

                        Button(action: {
                            viewModel.moveToInventory(from: item)
                        }) {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let item = viewModel.shoppingItems[index]
                        viewModel.deleteShoppingItem(id: item.id)
                    }
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddItemView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
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

    // Date formatter
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.inventoryItems) { item in
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)

                        HStack {
                            Text("Quantity: \(item.quantity)")
                            Spacer()
                            if let expirationDate = item.expirationDate {
                                Text("Expires: \(expirationDate, formatter: itemFormatter)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        if let inventoryId = item.inventoryId, !inventoryId.isEmpty {
                            let groupInventory = viewModel.groupInventories.first(where: {
                                $0.id == inventoryId
                            })
                            Text("Group: \(groupInventory?.groupName ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let item = viewModel.inventoryItems[index]
                        viewModel.deleteInventoryItem(id: item.id)
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddItemView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItemView) {
                AddInventoryItemView(viewModel: viewModel)
            }
        }
    }
}

// Groups View (formerly Group List)
struct GroupsView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groups) { group in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.headline)
                            Text("Members: \(group.memberCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if group.owner {
                                Text("Owner")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                Section("Group Inventories") {
                    ForEach(viewModel.groupInventories) { inventory in
                        VStack(alignment: .leading) {
                            Text(inventory.name)
                                .font(.headline)
                            Text("Group: \(inventory.groupName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddItemView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
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
    @State private var itemQuantity = 1
    @State private var isGroupItem = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Item name", text: $itemName)

                Stepper("Quantity: \(itemQuantity)", value: $itemQuantity, in: 1...99)

                Toggle("Group Item", isOn: $isGroupItem)

                Button("Add Item") {
                    if !itemName.isEmpty {
                        viewModel.addShoppingItem(
                            name: itemName, quantity: itemQuantity, groupItem: isGroupItem)
                        dismiss()
                    }
                }
                .disabled(itemName.isEmpty)
            }
            .navigationTitle("Add Shopping Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Add Inventory Item View
struct AddInventoryItemView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var itemName = ""
    @State private var itemQuantity = 1
    @State private var expirationDate: Date?
    @State private var hasExpirationDate = false
    @State private var selectedInventoryId: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Item name", text: $itemName)

                Stepper("Quantity: \(itemQuantity)", value: $itemQuantity, in: 1...99)

                Toggle("Has Expiration Date", isOn: $hasExpirationDate)

                if hasExpirationDate {
                    DatePicker(
                        "Expiration Date",
                        selection: Binding<Date>(
                            get: { expirationDate ?? Date() },
                            set: { expirationDate = $0 }
                        ), displayedComponents: .date)
                }

                if !viewModel.groupInventories.isEmpty {
                    Picker("Group Inventory", selection: $selectedInventoryId) {
                        Text("Personal Inventory").tag(nil as String?)
                        ForEach(viewModel.groupInventories) { inventory in
                            Text(inventory.name).tag(inventory.id as String?)
                        }
                    }
                }

                Button("Add Item") {
                    if !itemName.isEmpty {
                        viewModel.addInventoryItem(
                            name: itemName,
                            quantity: itemQuantity,
                            expirationDate: hasExpirationDate ? expirationDate : nil,
                            inventoryId: selectedInventoryId
                        )
                        dismiss()
                    }
                }
                .disabled(itemName.isEmpty)
            }
            .navigationTitle("Add Inventory Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Alert Item for displaying errors
struct AlertItem: Identifiable {
    var id = UUID()
    var message: String
}

// Profile View placeholder

#Preview {
    ContentView()
}
