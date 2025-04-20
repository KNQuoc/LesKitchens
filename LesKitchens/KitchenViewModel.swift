import Firebase
import FirebaseAppCheck
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

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

    private var db = Firestore.firestore()

    init() {
        // Check if user is logged in before loading data
        if let currentUser = Auth.auth().currentUser {
            loadUserData(userId: currentUser.uid)
        }

        // BEFORE FirebaseApp.configure()
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

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
        db.collection("users").document(userId).collection("profile").document("userProfile")
            .getDocument {
                [weak self] (snapshot: DocumentSnapshot?, error: Error?) in
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

                return ShoppingItem(
                    id: document.documentID,
                    name: data["name"] as? String ?? "",
                    quantity: data["quantity"] as? Int ?? 1,
                    groupItem: data["groupItem"] as? Bool ?? false
                )
            }

            DispatchQueue.main.async {
                self.shoppingItems = items
                completion(true)
            }
        }
    }

    func addShoppingItem(name: String, quantity: Int, groupItem: Bool = false) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let newItem = ShoppingItem(name: name, quantity: quantity, groupItem: groupItem)

        // Include all fields with default values for empty/null fields
        let data: [String: Any] = [
            "id": newItem.id,
            "name": newItem.name,
            "quantity": newItem.quantity,
            "groupItem": newItem.groupItem,
        ]

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
        guard let userId = Auth.auth().currentUser?.uid else { return }

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

                return InventoryItem(
                    id: document.documentID,
                    name: data["name"] as? String ?? "",
                    quantity: data["quantity"] as? Int ?? 1,
                    expirationDate: expirationDate,
                    inventoryId: data["inventoryId"] as? String,
                    status: data["status"] as? String ?? "active"
                )
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
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let newItem = InventoryItem(
            name: name,
            quantity: quantity,
            expirationDate: expirationDate,
            inventoryId: inventoryId,
            status: "NORMAL"
        )

        // Create data dictionary without the optional fields first
        var data: [String: Any] = [
            "id": newItem.id,
            "name": newItem.name,
            "quantity": newItem.quantity,
            "status": newItem.status,
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
        guard let userId = Auth.auth().currentUser?.uid else { return }

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

    // MARK: - Groups Methods

    func loadGroups(userId: String, completion: @escaping (Bool) -> Void) {
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

    // MARK: - Group Inventories Methods

    func loadGroupInventories(userId: String, completion: @escaping (Bool) -> Void) {
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
