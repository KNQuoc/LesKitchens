//
//  AppIntent.swift
//  Widget
//
//  Created by Quoc Ngo on 5/7/25.
//

import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configure Widget" }
    static var description: IntentDescription { "Show distance view or shopping list" }

    // Parameter to control which view to display
    @Parameter(title: "Show Distance View", default: true)
    var showDistanceView: Bool
}

// Intent for toggling the widget view
struct ToggleWidgetViewIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Widget View"
    static var description = IntentDescription("Switch between store distance and shopping list")

    @Parameter(title: "Current View is Distance", default: true)
    var currentViewIsDistance: Bool

    init() {}

    init(currentViewIsDistance: Bool) {
        self.currentViewIsDistance = currentViewIsDistance
    }

    func perform() async throws -> some IntentResult {
        // Save the toggled preference in UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.KitchenLabs.LesKitchens")
        let newValue = !currentViewIsDistance
        sharedDefaults?.set(newValue, forKey: "widget_show_distance_view")
        sharedDefaults?.synchronize()

        return .result()
    }
}
