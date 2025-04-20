import SwiftUI

// This file serves as documentation for the app's global types.
// DO NOT add type aliases here as they're causing circular references.

/*
The app uses the following key types from other files:

1. Models (from KitchenViewModel.swift):
   - ShoppingItem: Represents an item in the shopping list
   - InventoryItem: Represents an item in the kitchen inventory
   - Group: Represents a kitchen sharing group
   - GroupInventory: Represents a group inventory

2. View Models (from KitchenViewModel.swift):
   - KitchenViewModel: Main view model for the kitchen functionality
   - AuthViewModel: Authentication view model

3. Utilities (from GroceryDatabase.swift):
   - GroceryDatabase: Database of grocery items and their units

4. UI Components (from Models.swift):
   - AlertItem: Used for displaying alerts
   - BackgroundView: Common background view
   - ProfileView: User profile view
*/

// Global constants can be defined here
struct AppConstants {
    static let appName = "Les Kitchens"
    static let version = "1.0.0"
}
