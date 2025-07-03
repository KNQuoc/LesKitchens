import AppIntents
import CoreLocation
import Intents
import SwiftUI
import WidgetKit

// MARK: - Widget Entry

struct KitchensEntry: TimelineEntry {
    let date: Date
    let shoppingItemCount: Int
    let closestStoreName: String
    let distanceToStore: Double
    let showDistanceView: Bool
}

// MARK: - Location Manager for Widget

class WidgetLocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completionHandler: ((Double, String) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func getNearestGroceryStoreInfo(completion: @escaping (Double, String) -> Void) {
        self.completionHandler = completion

        // Debug: Print all keys in shared UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: "group.KitchenLabs.LesKitchens") {
            print("🔍 Widget debug - Available UserDefaults keys in group.KitchenLabs.LesKitchens:")
            for key in sharedDefaults.dictionaryRepresentation().keys {
                let value = sharedDefaults.object(forKey: key)
                print("  - \(key): \(String(describing: value))")
            }
        } else {
            print("⚠️ Widget couldn't access shared UserDefaults suite")
        }

        // First, try to get the cached store data from shared UserDefaults
        if let storeData = getStoreDataFromUserDefaults() {
            print("✅ Successfully retrieved store data from UserDefaults")
            completion(storeData.distance, storeData.name)
            return
        }

        // Don't try to use location services in the widget at all - they typically fail
        // Instead, always use mock data as fallback if shared UserDefaults doesn't have data
        print("⚠️ No location data found in UserDefaults, using mock data instead")
        provideMockStoreData(completion)
    }

    // Get data from shared UserDefaults
    private func getStoreDataFromUserDefaults() -> (distance: Double, name: String)? {
        let userDefaults = UserDefaults(suiteName: "group.KitchenLabs.LesKitchens")

        // Enhanced debug information
        print("\n🔍 WIDGET DATA DIAGNOSTIC")
        if let userDefaults = userDefaults {
            if userDefaults.dictionaryRepresentation().keys.isEmpty {
                print("⚠️ UserDefaults group exists but is empty")
            } else {
                print("Found UserDefaults values in group.KitchenLabs.LesKitchens:")
                // Only print the store-related keys for clarity
                let storeKeys = [
                    "nearest_store_name", "nearest_store_distance", "nearest_store_latitude",
                    "nearest_store_longitude", "nearest_store_last_updated",
                ]
                for key in storeKeys {
                    if let value = userDefaults.object(forKey: key) {
                        print("  - \(key): \(value)")
                    } else {
                        print("  - \(key): <not found>")
                    }
                }
            }
        } else {
            print("⚠️ Failed to access UserDefaults for group: group.KitchenLabs.LesKitchens")
        }

        guard let name = userDefaults?.string(forKey: "nearest_store_name"),
            let distance = userDefaults?.double(forKey: "nearest_store_distance"),
            !name.isEmpty, distance > 0
        else {
            print("❌ Could not load valid store data from UserDefaults")
            return nil
        }

        print(
            "✅ Successfully loaded store data: \(name) at \(String(format: "%.2f", distance)) miles"
        )
        return (distance, name)
    }

    // Helper function to provide mock data as last resort
    private func provideMockStoreData(_ completion: @escaping (Double, String) -> Void) {
        // Use the same mock data patterns as LocationServices.swift
        let storeNames = [
            "Whole Foods Market", "Trader Joe's", "Safeway", "Target", "Metro Market",
        ]
        let randomIndex = Int.random(in: 0..<storeNames.count)
        let mockDistance = Double.random(in: 0.5...3.0)

        print(
            "⚠️ Widget using MOCK store data (fallback only): \(storeNames[randomIndex]), \(mockDistance) miles"
        )
        completion(mockDistance, storeNames[randomIndex])
    }

    // These location callbacks should never be called since we're not requesting location
    // But keep them as a safety measure
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Widget received location update (unexpected)")
        if let storeData = getStoreDataFromUserDefaults() {
            completionHandler?(storeData.distance, storeData.name)
        } else {
            provideMockStoreData { [weak self] distance, name in
                self?.completionHandler?(distance, name)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Widget location manager failed with error: \(error.localizedDescription)")

        if let storeData = getStoreDataFromUserDefaults() {
            completionHandler?(storeData.distance, storeData.name)
        } else {
            provideMockStoreData { [weak self] distance, name in
                self?.completionHandler?(distance, name)
            }
        }
    }
}

// MARK: - Widget Provider

struct KitchensProvider: TimelineProvider {
    func placeholder(in context: Context) -> KitchensEntry {
        KitchensEntry(
            date: Date(),
            shoppingItemCount: 3,
            closestStoreName: "Grocery Store",
            distanceToStore: 1.2,
            showDistanceView: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KitchensEntry) -> Void) {
        let entry = KitchensEntry(
            date: Date(),
            shoppingItemCount: 3,
            closestStoreName: "Whole Foods",
            distanceToStore: 1.2,
            showDistanceView: true
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KitchensEntry>) -> Void) {
        var entries: [KitchensEntry] = []
        let currentDate = Date()

        // Get data from shared UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.KitchenLabs.LesKitchens")
        let storeName = userDefaults?.string(forKey: "nearest_store_name") ?? "Grocery Store"
        let distance = userDefaults?.double(forKey: "nearest_store_distance") ?? 1.5
        let itemCount = userDefaults?.integer(forKey: "shopping_items_count") ?? 0

        // Check if there's a manually saved preference
        let defaultShowDistance: Bool
        if let savedPref = userDefaults?.object(forKey: "widget_show_distance_view") as? Bool {
            defaultShowDistance = savedPref
        } else {
            // If no preference is saved, use time-based rotation
            defaultShowDistance = Int(currentDate.timeIntervalSince1970 / 300) % 2 == 0
        }

        // Create entry for current time
        let entry = KitchensEntry(
            date: currentDate,
            shoppingItemCount: itemCount,
            closestStoreName: storeName,
            distanceToStore: distance,
            showDistanceView: defaultShowDistance
        )
        entries.append(entry)

        // Add future entries for rotation every 5 minutes
        let minutesToSchedule = 2  // Schedule entries for 2 minutes ahead
        let minuteInterval = 1  // 1-minute intervals

        for minute in stride(from: minuteInterval, through: minutesToSchedule, by: minuteInterval) {
            if let futureDate = Calendar.current.date(
                byAdding: .minute, value: minute, to: currentDate)
            {
                // Toggle view every 5 minutes
                let showDistance = Int(futureDate.timeIntervalSince1970 / 300) % 2 == 0

                let entry = KitchensEntry(
                    date: futureDate,
                    shoppingItemCount: itemCount,
                    closestStoreName: storeName,
                    distanceToStore: distance,
                    showDistanceView: showDistance
                )
                entries.append(entry)
            }
        }

        // Update every 5 minutes
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct KitchensDistanceView: View {
    var storeName: String
    var distance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(Color("ActionColor"))
                Text("Nearest Grocery")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text(storeName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)

            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(Color("ActionColor"))
                Text(String(format: "%.1f miles away", distance))
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("CardColor"))
        )
        .padding(8)
    }
}

struct KitchensShoppingView: View {
    var itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundColor(Color("ActionColor"))
                Text("Shopping List")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if itemCount == 0 {
                Text("Your list is empty")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Tap to view list")
                    .font(.subheadline)
                    .foregroundColor(Color("ActionColor"))
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("CardColor"))
        )
        .padding(8)
    }
}

// MARK: - Widget Entry View

struct KitchensEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: KitchensProvider.Entry

    var body: some View {
        content
            .modifier(WidgetBackgroundModifier(color: Color("BackgroundColor")))
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .systemSmall:
            // Small widget shows voice assistant button
            Link(destination: URL(string: "kitchens://assistantScreen")!) {
                smallWidget
            }
            .buttonStyle(.plain)

        case .systemMedium:
            // Medium widget shows either distance view or shopping list
            mediumWidget

        default:
            Text("Unsupported widget size")
        }
    }

    @ViewBuilder
    private var smallWidget: some View {
        VStack {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color("ActionColor"))

            Text("Ask Chef")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding()
    }

    @ViewBuilder
    private var mediumWidget: some View {
        // Use the entry's showDistanceView property to determine which view to show
        if entry.showDistanceView {
            // Make the entire distance view tappable to toggle
            Link(destination: URL(string: "kitchens://toggle-view")!) {
                KitchensDistanceView(
                    storeName: entry.closestStoreName,
                    distance: entry.distanceToStore
                )
            }
            .buttonStyle(.plain)
        } else {
            // Make the entire shopping list view tappable to toggle
            Link(destination: URL(string: "kitchens://toggle-view")!) {
                KitchensShoppingView(itemCount: entry.shoppingItemCount)
            }
            .buttonStyle(.plain)
        }
    }
}

// Compatibility modifier for widget background
struct WidgetBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    color
                }
        } else {
            content
                .background(color)
        }
    }
}

// MARK: - Widget Definition

struct KitchensWidget: Widget {
    let kind: String = "KitchensWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KitchensProvider()) { entry in
            KitchensEntryView(entry: entry)
        }
        .configurationDisplayName("Kitchen Helper")
        .description("Track shopping list and nearest grocery store.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

struct KitchensWidget_Previews: PreviewProvider {
    static var previews: some View {
        KitchensEntryView(
            entry: KitchensEntry(
                date: Date(),
                shoppingItemCount: 5,
                closestStoreName: "Whole Foods Market",
                distanceToStore: 1.2,
                showDistanceView: true
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))

        KitchensEntryView(
            entry: KitchensEntry(
                date: Date().addingTimeInterval(15),
                shoppingItemCount: 3,
                closestStoreName: "Trader Joe's",
                distanceToStore: 0.7,
                showDistanceView: true
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
