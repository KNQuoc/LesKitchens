import Foundation

/// A database of common grocery items and their standard units.
/// Used for unit detection when adding items to the shopping list.
class GroceryDatabase {

    /// Shared singleton instance
    static let shared = GroceryDatabase()

    /// Dictionary mapping grocery item names to their standard units
    private let groceryItems: [String: String] = [
        // Dairy
        "milk": "gallon",
        "cheese": "oz",
        "butter": "stick",
        "yogurt": "cup",
        "cream": "oz",
        "sour cream": "oz",

        // Meats
        "chicken": "lb",
        "beef": "lb",
        "pork": "lb",
        "turkey": "lb",
        "bacon": "oz",
        "sausage": "oz",
        "ham": "lb",

        // Produce
        "apple": "each",
        "orange": "each",
        "banana": "each",
        "potato": "lb",
        "onion": "each",
        "garlic": "clove",
        "tomato": "each",
        "lettuce": "head",
        "carrot": "lb",
        "celery": "stalk",
        "cucumber": "each",
        "bell pepper": "each",

        // Baking
        "flour": "cup",
        "sugar": "cup",
        "baking powder": "tsp",
        "baking soda": "tsp",
        "salt": "tsp",
        "vanilla extract": "tsp",
        "cinnamon": "tsp",

        // Beverages
        "water": "bottle",
        "juice": "oz",
        "soda": "can",
        "coffee": "lb",
        "tea": "bag",

        // Canned/Jarred
        "beans": "can",
        "soup": "can",
        "tuna": "can",
        "pasta sauce": "jar",
        "salsa": "jar",

        // Grains
        "bread": "loaf",
        "rice": "cup",
        "pasta": "box",
        "cereal": "box",
        "oats": "cup",

        // Oils/Condiments
        "olive oil": "tbsp",
        "vegetable oil": "tbsp",
        "vinegar": "tbsp",
        "ketchup": "bottle",
        "mustard": "bottle",
        "mayonnaise": "jar",
        "soy sauce": "tbsp",

        // Snacks
        "chips": "bag",
        "crackers": "box",
        "nuts": "oz",
        "cookies": "package",
    ]

    /// Detects the appropriate unit for a given item name
    /// - Parameter itemName: The name of the grocery item
    /// - Returns: The standard unit for the item, or "each" if no specific unit is found
    func getUnitForItem(_ itemName: String) -> String {
        let normalizedName = itemName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for exact matches first
        if let unit = groceryItems[normalizedName] {
            return unit
        }

        // Look for partial matches
        var matches: [(key: String, unit: String)] = []

        for (key, unit) in groceryItems {
            if normalizedName.contains(key) {
                matches.append((key: key, unit: unit))
            }
        }

        // Sort matches by key length (descending) to prioritize more specific matches
        matches.sort { $0.key.count > $1.key.count }

        if let bestMatch = matches.first {
            return bestMatch.unit
        }

        // Default unit if no match is found
        return "each"
    }
}
