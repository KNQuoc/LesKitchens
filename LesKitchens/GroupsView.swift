import FirebaseAuth
import FirebaseCore
import SwiftUI

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
        UserDefaults.standard.set(inventory.id, forKey: "selectedInventoryId")
        UserDefaults.standard.set(inventory.name, forKey: "selectedInventoryName")

        // Reset selection after navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedInventoryToView = nil
        }
    }

    // Empty state view for no groups
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No groups yet")
                .font(.headline)

            Text("Create a group to share inventories with family or roommates")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                showingAddItemView = true
            }) {
                Text("Create Group")
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

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if viewModel.groups.isEmpty {
                    emptyStateView()
                } else {
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
                                            let groupInventories = viewModel.groupInventories.filter
                                            {
                                                $0.groupId == group.id
                                            }

                                            if groupInventories.isEmpty {
                                                Text("No inventories yet")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .padding(.vertical, 8)
                                            } else {
                                                ForEach(groupInventories) { inventory in
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

                                                                    Image(
                                                                        systemName: "chevron.right"
                                                                    )
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
                                                                viewModel.deleteGroupInventory(
                                                                    id: inventory.id)
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
                                            }

                                            Button(action: {
                                                // Add inventory
                                                showingAddItemView = true
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
                CreateGroupView(viewModel: viewModel)
            }
            .onAppear {
                // If we have a user, load groups data
                if let currentUser = Auth.auth().currentUser {
                    viewModel.loadGroups(userId: currentUser.uid) { _ in
                        // Groups loaded
                    }
                    viewModel.loadGroupInventories(userId: currentUser.uid) { _ in
                        // Group inventories loaded
                    }
                }
            }
        }
    }
}

// Create Group View
struct CreateGroupView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @State private var groupName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Create Group")
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.top, 5)
                    .frame(maxWidth: .infinity, alignment: .center)

                TextField("Group Name", text: $groupName)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

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
                        if !groupName.isEmpty {
                            // Create group
                            viewModel.createGroup(name: groupName)
                            dismiss()
                        }
                    }) {
                        Text("Create")
                            .foregroundColor(Color("ActionColor"))
                    }
                    .disabled(groupName.isEmpty)
                }
            }
            .padding()
            .background(Color("BackgroundColor"))
            .cornerRadius(16)
            .frame(width: 350, height: 200)
        }
    }
}

#if DEBUG
    struct GroupsView_Previews: PreviewProvider {
        static var previews: some View {
            GroupsView(viewModel: KitchenViewModel())
                .onAppear {
                    // For previews, we'll check if Firebase is already configured
                    if FirebaseApp.app() == nil {
                        FirebaseApp.configure()
                    }
                }
        }
    }
#endif
