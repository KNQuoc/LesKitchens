import SwiftUI

// Models
struct GroceryItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var isCompleted: Bool = false
}

struct InventoryItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var dateAdded: Date = Date()
}

struct GroupItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var assignedTo: String
    var isCompleted: Bool = false
}

// ViewModel
class KitchenViewModel: ObservableObject {
    @Published var groceryItems: [GroceryItem] = []
    @Published var inventoryItems: [InventoryItem] = []
    @Published var groupItems: [GroupItem] = []
    @Published var selectedTab = 0

    init() {
        loadItems()
    }

    // Grocery List Methods
    func addGroceryItem(name: String, quantity: Int) {
        let newItem = GroceryItem(name: name, quantity: quantity)
        groceryItems.append(newItem)
        saveItems()
    }

    func deleteGroceryItem(at indexSet: IndexSet) {
        groceryItems.remove(atOffsets: indexSet)
        saveItems()
    }

    func toggleGroceryCompletion(for item: GroceryItem) {
        if let index = groceryItems.firstIndex(where: { $0.id == item.id }) {
            groceryItems[index].isCompleted.toggle()
            saveItems()
        }
    }

    // Inventory Methods
    func addInventoryItem(name: String, quantity: Int) {
        let newItem = InventoryItem(name: name, quantity: quantity)
        inventoryItems.append(newItem)
        saveItems()
    }

    func deleteInventoryItem(at indexSet: IndexSet) {
        inventoryItems.remove(atOffsets: indexSet)
        saveItems()
    }

    func moveToInventory(item: GroceryItem) {
        // Add to inventory
        let inventoryItem = InventoryItem(name: item.name, quantity: item.quantity)
        inventoryItems.append(inventoryItem)

        // Remove from grocery list
        if let index = groceryItems.firstIndex(where: { $0.id == item.id }) {
            groceryItems.remove(at: index)
        }

        saveItems()
    }

    // Group List Methods
    func addGroupItem(name: String, assignedTo: String) {
        let newItem = GroupItem(name: name, assignedTo: assignedTo)
        groupItems.append(newItem)
        saveItems()
    }

    func deleteGroupItem(at indexSet: IndexSet) {
        groupItems.remove(atOffsets: indexSet)
        saveItems()
    }

    func toggleGroupCompletion(for item: GroupItem) {
        if let index = groupItems.firstIndex(where: { $0.id == item.id }) {
            groupItems[index].isCompleted.toggle()
            saveItems()
        }
    }

    // Data Persistence
    private func saveItems() {
        if let groceryEncoded = try? JSONEncoder().encode(groceryItems) {
            UserDefaults.standard.set(groceryEncoded, forKey: "GroceryItems")
        }

        if let inventoryEncoded = try? JSONEncoder().encode(inventoryItems) {
            UserDefaults.standard.set(inventoryEncoded, forKey: "InventoryItems")
        }

        if let groupEncoded = try? JSONEncoder().encode(groupItems) {
            UserDefaults.standard.set(groupEncoded, forKey: "GroupItems")
        }
    }

    private func loadItems() {
        // Load Grocery Items
        if let savedGroceryItems = UserDefaults.standard.data(forKey: "GroceryItems"),
            let decodedGroceryItems = try? JSONDecoder().decode(
                [GroceryItem].self, from: savedGroceryItems)
        {
            groceryItems = decodedGroceryItems
        }

        // Load Inventory Items
        if let savedInventoryItems = UserDefaults.standard.data(forKey: "InventoryItems"),
            let decodedInventoryItems = try? JSONDecoder().decode(
                [InventoryItem].self, from: savedInventoryItems)
        {
            inventoryItems = decodedInventoryItems
        }

        // Load Group Items
        if let savedGroupItems = UserDefaults.standard.data(forKey: "GroupItems"),
            let decodedGroupItems = try? JSONDecoder().decode(
                [GroupItem].self, from: savedGroupItems)
        {
            groupItems = decodedGroupItems
        }
    }
}

// Main View - TabView Container
struct ContentView: View {
    @StateObject private var viewModel = KitchenViewModel()

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            GroceryListView(viewModel: viewModel)
                .tabItem {
                    Label("Grocery", systemImage: "cart")
                }
                .tag(0)

            InventoryView(viewModel: viewModel)
                .tabItem {
                    Label("Inventory", systemImage: "archivebox")
                }
                .tag(1)

            GroupListView(viewModel: viewModel)
                .tabItem {
                    Label("Group", systemImage: "person.2")
                }
                .tag(2)
        }
    }
}

// Grocery List View
struct GroceryListView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groceryItems) { item in
                    HStack {
                        Button(action: {
                            viewModel.toggleGroceryCompletion(for: item)
                        }) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isCompleted ? .green : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())

                        VStack(alignment: .leading) {
                            Text(item.name)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                            Text("Quantity: \(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            viewModel.moveToInventory(item: item)
                        }) {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onDelete(perform: viewModel.deleteGroceryItem)
            }
            .navigationTitle("Grocery List")
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
                AddGroceryItemView(viewModel: viewModel)
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
                            Text("Added: \(item.dateAdded, formatter: itemFormatter)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: viewModel.deleteInventoryItem)
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

// Group List View
struct GroupListView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groupItems) { item in
                    HStack {
                        Button(action: {
                            viewModel.toggleGroupCompletion(for: item)
                        }) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isCompleted ? .green : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())

                        VStack(alignment: .leading) {
                            Text(item.name)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                            Text("Assigned to: \(item.assignedTo)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteGroupItem)
            }
            .navigationTitle("Group List")
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
                AddGroupItemView(viewModel: viewModel)
            }
        }
    }
}

// Add Grocery Item View
struct AddGroceryItemView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var itemName = ""
    @State private var itemQuantity = 1
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Item name", text: $itemName)

                Stepper("Quantity: \(itemQuantity)", value: $itemQuantity, in: 1...99)

                Button("Add Item") {
                    if !itemName.isEmpty {
                        viewModel.addGroceryItem(name: itemName, quantity: itemQuantity)
                        dismiss()
                    }
                }
                .disabled(itemName.isEmpty)
            }
            .navigationTitle("Add Grocery Item")
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Item name", text: $itemName)

                Stepper("Quantity: \(itemQuantity)", value: $itemQuantity, in: 1...99)

                Button("Add Item") {
                    if !itemName.isEmpty {
                        viewModel.addInventoryItem(name: itemName, quantity: itemQuantity)
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

// Add Group Item View
struct AddGroupItemView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var itemName = ""
    @State private var assignedTo = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Task name", text: $itemName)

                TextField("Assigned to", text: $assignedTo)

                Button("Add Item") {
                    if !itemName.isEmpty && !assignedTo.isEmpty {
                        viewModel.addGroupItem(name: itemName, assignedTo: assignedTo)
                        dismiss()
                    }
                }
                .disabled(itemName.isEmpty || assignedTo.isEmpty)
            }
            .navigationTitle("Add Group Task")
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

#Preview {
    ContentView()
}
