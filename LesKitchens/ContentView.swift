import SwiftUI

// Main View - TabView Container
struct ContentView: View {
    @StateObject private var viewModel = KitchenViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

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

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
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
