import Firebase
import FirebaseAppCheck
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

// Alert Item for displaying errors
struct AlertItem: Identifiable {
    var id = UUID()
    var message: String
}

// Models
struct ShoppingItem: Identifiable, Codable {
    var id: String
    var name: String
    var quantity: Int
    var groupItem: Bool

    init(id: String = UUID().uuidString, name: String, quantity: Int, groupItem: Bool = false) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.groupItem = groupItem
    }

    var unitDisplay: String {
        // Retrieve unit from GroceryDatabase based on item name
        return GroceryDatabase.shared.getUnitForItem(name)
    }
}

struct InventoryItem: Identifiable, Codable {
    var id: String
    var name: String
    var quantity: Int
    var expirationDate: Date?
    var inventoryId: String?  // null for personal inventory, otherwise matches groupInventory ID
    var status: String

    init(
        id: String = UUID().uuidString, name: String, quantity: Int, expirationDate: Date? = nil,
        inventoryId: String? = nil, status: String = "active"
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.expirationDate = expirationDate
        self.inventoryId = inventoryId
        self.status = status
    }

    var unitDisplay: String {
        // Retrieve unit from GroceryDatabase based on item name
        return GroceryDatabase.shared.getUnitForItem(name)
    }
}

struct GroupInventory: Identifiable, Codable {
    var id: String
    var groupId: String
    var name: String
    var groupName: String

    init(id: String = UUID().uuidString, groupId: String, name: String, groupName: String) {
        self.id = id
        self.groupId = groupId
        self.name = name
        self.groupName = groupName
    }
}

struct Group: Identifiable, Codable {
    var id: String
    var name: String
    var memberCount: Int
    var owner: Bool

    init(id: String = UUID().uuidString, name: String, memberCount: Int = 1, owner: Bool = false) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.owner = owner
    }
}

struct UserProfile: Codable {
    var userId: String
    var displayName: String
    var username: String
    var email: String
    var createdAt: Date

    init(
        userId: String, displayName: String, username: String, email: String,
        createdAt: Date = Date()
    ) {
        self.userId = userId
        self.displayName = displayName
        self.username = username
        self.email = email
        self.createdAt = createdAt
    }
}

// ViewModel
class KitchenViewModel: ObservableObject {
    @Published var shoppingItems: [ShoppingItem] = []
    @Published var inventoryItems: [InventoryItem] = []
    @Published var groupInventories: [GroupInventory] = []
    @Published var groups: [Group] = []
    @Published var userProfile: UserProfile?
    @Published var selectedTab = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userSession: User?

    private var db: Firestore?

    init() {
        // Initialize Firestore
        db = Firestore.firestore()

        // Check if user is logged in before loading data
        if let currentUser = Auth.auth().currentUser {
            userSession = currentUser
            loadUserData(userId: currentUser.uid)
        }
    }

    // MARK: - Data Loading

    func loadUserData(userId: String) {
        isLoading = true
        errorMessage = nil

        let dispatchGroup = DispatchGroup()

        // Load profile
        dispatchGroup.enter()
        loadProfile(userId: userId) { _ in
            dispatchGroup.leave()
        }

        // Load shopping items
        dispatchGroup.enter()
        loadShoppingItems(userId: userId) { _ in
            dispatchGroup.leave()
        }

        // Load inventory items
        dispatchGroup.enter()
        loadInventoryItems(userId: userId) { _ in
            dispatchGroup.leave()
        }

        // Load groups
        dispatchGroup.enter()
        loadGroups(userId: userId) { _ in
            dispatchGroup.leave()
        }

        // Load group inventories
        dispatchGroup.enter()
        loadGroupInventories(userId: userId) { _ in
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
        }
    }

    // MARK: - Profile Methods

    func loadProfile(userId: String, completion: @escaping (Bool) -> Void) {
        guard let db = db else {
            completion(false)
            return
        }

        db.collection("users").document(userId).collection("profile").document("userProfile")
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    completion(false)
                    return
                }

                guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                    self.errorMessage = "Profile data not found"
                    completion(false)
                    return
                }

                // Process the profile data
                let createdTimestamp = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())

                let profile = UserProfile(
                    userId: data["userId"] as? String ?? userId,
                    displayName: data["displayName"] as? String ?? "",
                    username: data["username"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    createdAt: createdTimestamp.dateValue()
                )

                DispatchQueue.main.async {
                    self.userProfile = profile
                    completion(true)
                }
            }
    }

    // MARK: - Shopping Items Methods

    func loadShoppingItems(userId: String, completion: @escaping (Bool) -> Void) {
        guard let db = db else {
            completion(false)
            return
        }

        db.collection("users").document(userId).collection("shopping").getDocuments {
            [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Failed to load shopping items: \(error.localizedDescription)"
                completion(false)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(true)
                return
            }

            let items = documents.compactMap { document -> ShoppingItem? in
                let data = document.data()

                // Create the shopping item
                let item = ShoppingItem(
                    id: document.documentID,
                    name: data["name"] as? String ?? "",
                    quantity: data["quantity"] as? Int ?? 1,
                    groupItem: data["groupItem"] as? Bool ?? false
                )

                // If there's no unit in Firebase, it will use the one from GroceryDatabase
                return item
            }

            DispatchQueue.main.async {
                self.shoppingItems = items
                completion(true)
            }
        }
    }

    func addShoppingItem(name: String, quantity: Int, groupItem: Bool = false) {
        guard let userId = userSession?.uid else { return }

        let newItem = ShoppingItem(name: name, quantity: quantity, groupItem: groupItem)
        let unit = GroceryDatabase.shared.getUnitForItem(name)

        // Include all fields with default values for empty/null fields
        let data: [String: Any] = [
            "id": newItem.id,
            "name": newItem.name,
            "quantity": newItem.quantity,
            "groupItem": newItem.groupItem,
            "unit": unit,  // Add unit to Firebase document
        ]

        guard let db = db else { return }

        db.collection("users").document(userId).collection("shopping").document(newItem.id).setData(
            data
        ) { [weak self] error in
            if let error = error {
                self?.errorMessage = "Failed to add shopping item: \(error.localizedDescription)"
                return
            }

            DispatchQueue.main.async {
                self?.shoppingItems.append(newItem)
            }
        }
    }

    func deleteShoppingItem(id: String) {
        guard let userId = userSession?.uid else { return }

        guard let db = db else { return }

        db.collection("users").document(userId).collection("shopping").document(id).delete {
            [weak self] error in
            if let error = error {
                self?.errorMessage = "Failed to delete shopping item: \(error.localizedDescription)"
                return
            }

            DispatchQueue.main.async {
                self?.shoppingItems.removeAll { $0.id == id }
            }
        }
    }

    // MARK: - Inventory Methods

    func loadInventoryItems(userId: String, completion: @escaping (Bool) -> Void) {
        guard let db = db else {
            completion(false)
            return
        }

        db.collection("users").document(userId).collection("inventory").getDocuments {
            [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Failed to load inventory items: \(error.localizedDescription)"
                completion(false)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(true)
                return
            }

            let items = documents.compactMap { document -> InventoryItem? in
                let data = document.data()
                var expirationDate: Date? = nil

                if let expirationTimestamp = data["expirationDate"] as? Timestamp {
                    expirationDate = expirationTimestamp.dateValue()
                }

                // Create the inventory item
                let item = InventoryItem(
                    id: document.documentID,
                    name: data["name"] as? String ?? "",
                    quantity: data["quantity"] as? Int ?? 1,
                    expirationDate: expirationDate,
                    inventoryId: data["inventoryId"] as? String,
                    status: data["status"] as? String ?? "active"
                )

                // If there's no unit in Firebase, it will use the one from GroceryDatabase
                return item
            }

            DispatchQueue.main.async {
                self.inventoryItems = items
                completion(true)
            }
        }
    }

    func addInventoryItem(
        name: String, quantity: Int, expirationDate: Date? = nil, inventoryId: String? = nil
    ) {
        guard let userId = userSession?.uid else { return }

        let newItem = InventoryItem(
            name: name,
            quantity: quantity,
            expirationDate: expirationDate,
            inventoryId: inventoryId,
            status: "NORMAL"
        )
        let unit = GroceryDatabase.shared.getUnitForItem(name)

        // Create data dictionary without the optional fields first
        var data: [String: Any] = [
            "id": newItem.id,
            "name": newItem.name,
            "quantity": newItem.quantity,
            "status": newItem.status,
            "unit": unit,  // Add unit to Firebase document
        ]

        // Handle optional fields properly
        if let expirationDate = newItem.expirationDate {
            data["expirationDate"] = Timestamp(date: expirationDate)
        } else {
            data["expirationDate"] = ""  // Empty string for missing date
        }

        if let inventoryId = newItem.inventoryId {
            data["inventoryId"] = inventoryId
        } else {
            data["inventoryId"] = NSNull()  // Explicit null for missing inventory ID
        }

        guard let db = db else { return }

        db.collection("users").document(userId).collection("inventory").document(newItem.id)
            .setData(data) { [weak self] error in
                if let error = error {
                    self?.errorMessage =
                        "Failed to add inventory item: \(error.localizedDescription)"
                    return
                }

                DispatchQueue.main.async {
                    self?.inventoryItems.append(newItem)
                }
            }
    }

    func deleteInventoryItem(id: String) {
        guard let userId = userSession?.uid else { return }

        guard let db = db else { return }

        db.collection("users").document(userId).collection("inventory").document(id).delete {
            [weak self] error in
            if let error = error {
                self?.errorMessage =
                    "Failed to delete inventory item: \(error.localizedDescription)"
                return
            }

            DispatchQueue.main.async {
                self?.inventoryItems.removeAll { $0.id == id }
            }
        }
    }

    func updateInventoryItemStatus(id: String, status: String) {
        guard let userId = userSession?.uid else { return }

        // First update local state
        DispatchQueue.main.async {
            if let index = self.inventoryItems.firstIndex(where: { $0.id == id }) {
                self.inventoryItems[index].status = status
            }
        }

        // Then update in Firestore
        guard let db = db else { return }

        db.collection("users").document(userId).collection("inventory").document(id)
            .updateData(["status": status]) { [weak self] error in
                if let error = error {
                    self?.errorMessage =
                        "Failed to update item status: \(error.localizedDescription)"
                    return
                }
            }
    }

    // MARK: - Groups Methods

    func loadGroups(userId: String, completion: @escaping (Bool) -> Void) {
        guard let db = db else {
            completion(false)
            return
        }

        db.collection("users").document(userId).collection("groups").getDocuments {
            [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Failed to load groups: \(error.localizedDescription)"
                completion(false)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(true)
                return
            }

            let items = documents.compactMap { document -> Group? in
                let data = document.data()

                return Group(
                    id: document.documentID,
                    name: data["name"] as? String ?? "",
                    memberCount: data["memberCount"] as? Int ?? 1,
                    owner: data["owner"] as? Bool ?? false
                )
            }

            DispatchQueue.main.async {
                self.groups = items
                completion(true)
            }
        }
    }

    func createGroup(name: String) {
        guard let userId = userSession?.uid else { return }

        let newGroup = Group(name: name, memberCount: 1, owner: true)

        let data: [String: Any] = [
            "id": newGroup.id,
            "name": newGroup.name,
            "memberCount": newGroup.memberCount,
            "owner": newGroup.owner,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        // Show loading indicator
        isLoading = true

        guard let db = db else { return }

        db.collection("users").document(userId).collection("groups").document(newGroup.id)
            .setData(data) { [weak self] error in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Failed to create group: \(error.localizedDescription)"
                    return
                }

                // Create a default inventory for the new group
                self.createGroupInventory(
                    groupId: newGroup.id,
                    name: "\(newGroup.name) Kitchen",
                    groupName: newGroup.name
                )

                DispatchQueue.main.async {
                    self.groups.append(newGroup)
                }
            }
    }

    // MARK: - Group Inventories Methods

    func loadGroupInventories(userId: String, completion: @escaping (Bool) -> Void) {
        guard let db = db else {
            completion(false)
            return
        }

        db.collection("users").document(userId).collection("groupInventories").getDocuments {
            [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage =
                    "Failed to load group inventories: \(error.localizedDescription)"
                completion(false)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(true)
                return
            }

            let items = documents.compactMap { document -> GroupInventory? in
                let data = document.data()

                return GroupInventory(
                    id: document.documentID,
                    groupId: data["groupId"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    groupName: data["groupName"] as? String ?? ""
                )
            }

            DispatchQueue.main.async {
                self.groupInventories = items
                completion(true)
            }
        }
    }

    func createGroupInventory(groupId: String, name: String, groupName: String) {
        guard let userId = userSession?.uid else { return }

        let newInventory = GroupInventory(groupId: groupId, name: name, groupName: groupName)

        let data: [String: Any] = [
            "id": newInventory.id,
            "groupId": newInventory.groupId,
            "name": newInventory.name,
            "groupName": newInventory.groupName,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        guard let db = db else { return }

        db.collection("users").document(userId).collection("groupInventories").document(
            newInventory.id
        )
        .setData(data) { [weak self] error in
            if let error = error {
                self?.errorMessage =
                    "Failed to create group inventory: \(error.localizedDescription)"
                return
            }

            DispatchQueue.main.async {
                self?.groupInventories.append(newInventory)
            }
        }
    }

    func deleteGroupInventory(id: String) {
        guard let userId = userSession?.uid else { return }
        guard let db = self.db else { return }

        // First remove all inventory items that belong to this group inventory
        db.collection("users").document(userId).collection("inventory")
            .whereField("inventoryId", isEqualTo: id)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage =
                        "Failed to find inventory items: \(error.localizedDescription)"
                    return
                }

                let batch = db.batch()

                snapshot?.documents.forEach { document in
                    batch.deleteDocument(
                        db.collection("users").document(userId).collection("inventory")
                            .document(document.documentID))
                }

                // Then delete the group inventory
                batch.deleteDocument(
                    db.collection("users").document(userId).collection("groupInventories")
                        .document(id))

                batch.commit { error in
                    if let error = error {
                        self.errorMessage =
                            "Failed to delete group inventory: \(error.localizedDescription)"
                        return
                    }

                    DispatchQueue.main.async {
                        // Remove items from memory
                        self.inventoryItems.removeAll { $0.inventoryId == id }
                        self.groupInventories.removeAll { $0.id == id }
                    }
                }
            }
    }

    // MARK: - Move Item Methods

    func moveToInventory(
        from shoppingItem: ShoppingItem, expirationDate: Date? = nil, inventoryId: String? = nil
    ) {
        addInventoryItem(
            name: shoppingItem.name,
            quantity: shoppingItem.quantity,
            expirationDate: expirationDate,
            inventoryId: inventoryId
        )

        deleteShoppingItem(id: shoppingItem.id)
    }
}

// End of file
