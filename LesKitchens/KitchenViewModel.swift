import Firebase
import FirebaseAuth
import FirebaseFirestore
import Foundation
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

    private var db = Firestore.firestore()

    init() {
        // Check if user is logged in before loading data
        if let currentUser = Auth.auth().currentUser {
            loadFirebaseData()
        } else {
            loadLocalData()  // Fallback to local data if not logged in
        }
    }

    // MARK: - Grocery List Methods
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

    // MARK: - Inventory Methods
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

    // MARK: - Group List Methods
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

    // MARK: - Firebase Data Operations

    func saveItems() {
        if let currentUser = Auth.auth().currentUser {
            saveToFirebase(userId: currentUser.uid)
        } else {
            saveToLocalStorage()
        }
    }

    private func saveToFirebase(userId: String) {
        do {
            // Save grocery items
            let groceryData = try JSONEncoder().encode(groceryItems)
            if let groceryString = String(data: groceryData, encoding: .utf8) {
                db.collection("users").document(userId).collection("data").document("groceryItems")
                    .setData(["data": groceryString])
            }

            // Save inventory items
            let inventoryData = try JSONEncoder().encode(inventoryItems)
            if let inventoryString = String(data: inventoryData, encoding: .utf8) {
                db.collection("users").document(userId).collection("data").document(
                    "inventoryItems"
                )
                .setData(["data": inventoryString])
            }

            // Save group items
            let groupData = try JSONEncoder().encode(groupItems)
            if let groupString = String(data: groupData, encoding: .utf8) {
                db.collection("users").document(userId).collection("data").document("groupItems")
                    .setData(["data": groupString])
            }
        } catch {
            print("Error saving to Firebase: \(error.localizedDescription)")
            // Fall back to local storage if Firebase saving fails
            saveToLocalStorage()
        }
    }

    func loadFirebaseData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Fall back to local storage if not authenticated
            loadLocalData()
            return
        }

        // Reference to user's data collection
        let userDataRef = db.collection("users").document(userId).collection("data")

        // Load grocery items
        userDataRef.document("groceryItems").getDocument { [weak self] document, error in
            if let document = document, document.exists,
                let dataString = document.data()?["data"] as? String,
                let data = dataString.data(using: .utf8)
            {

                do {
                    let items = try JSONDecoder().decode([GroceryItem].self, from: data)
                    DispatchQueue.main.async {
                        self?.groceryItems = items
                    }
                } catch {
                    print("Error decoding grocery items: \(error.localizedDescription)")
                }
            }
        }

        // Load inventory items
        userDataRef.document("inventoryItems").getDocument { [weak self] document, error in
            if let document = document, document.exists,
                let dataString = document.data()?["data"] as? String,
                let data = dataString.data(using: .utf8)
            {

                do {
                    let items = try JSONDecoder().decode([InventoryItem].self, from: data)
                    DispatchQueue.main.async {
                        self?.inventoryItems = items
                    }
                } catch {
                    print("Error decoding inventory items: \(error.localizedDescription)")
                }
            }
        }

        // Load group items
        userDataRef.document("groupItems").getDocument { [weak self] document, error in
            if let document = document, document.exists,
                let dataString = document.data()?["data"] as? String,
                let data = dataString.data(using: .utf8)
            {

                do {
                    let items = try JSONDecoder().decode([GroupItem].self, from: data)
                    DispatchQueue.main.async {
                        self?.groupItems = items
                    }
                } catch {
                    print("Error decoding group items: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Local Storage Operations

    private func saveToLocalStorage() {
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

    private func loadLocalData() {
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
