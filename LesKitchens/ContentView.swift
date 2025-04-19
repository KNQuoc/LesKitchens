import Firebase
import FirebaseAuth
import SwiftUI
import UIKit

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

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.shoppingItems) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.body.bold())
                                    Text("Quantity: \(item.quantity)")
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
                            Text("Add Item")
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color("ActionColor"))
                                .cornerRadius(25)
                        }
                    }
                    .padding()
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

    // Date formatter
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

                VStack {
                    // Inventory selector dropdown
                    HStack {
                        Button(action: {
                            withAnimation {
                                dropdownOpen.toggle()
                            }
                        }) {
                            HStack {
                                Text(
                                    selectedInventory == nil
                                        ? "Personal Inventory" : selectedInventory!
                                )
                                .font(.headline)

                                Image(systemName: "chevron.down")
                                    .rotationEffect(Angle(degrees: dropdownOpen ? 180 : 0))
                            }
                            .foregroundColor(.primary)
                            .padding(.vertical, 10)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Inventory items list
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.inventoryItems) { item in
                                // Only show items for the selected inventory
                                if (selectedInventory == nil && item.inventoryId == nil)
                                    || (item.inventoryId == selectedInventory)
                                {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.body.bold())

                                        Text("Quantity: \(item.quantity)")
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
        }
    }
}

// Groups View (formerly Group List)
struct GroupsView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var showingAddItemView = false

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
                                            HStack {
                                                Text(inventory.name)
                                                    .font(.caption)
                                                    .foregroundColor(Color("ActionColor"))

                                                Spacer()

                                                Button(action: {
                                                    // Delete inventory
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.primary)
                                                }
                                            }
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
                            Text("Create Group")
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color("ActionColor"))
                                .cornerRadius(25)
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
    @State private var itemQuantity = 1
    @State private var isGroupItem = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

                VStack {
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
                        .foregroundColor(Color("ActionColor"))
                    }
                }
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
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()

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
                    .foregroundColor(Color("ActionColor"))
                }
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

#Preview {
    ContentView()
}
