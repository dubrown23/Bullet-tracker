//
//  BulletTrackerWidgets.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//

import WidgetKit
import SwiftUI

@main
struct BulletTrackerWidgets: WidgetBundle {
    var body: some Widget {
        HabitTrackerWidget()
    }
}

// MARK: - Habit Tracker Widget

struct HabitTrackerWidget: Widget {
    let kind: String = "HabitTrackerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitWidgetProvider()) { entry in
            HabitWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Habits")
        .description("Track your daily habits right from your home screen.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

struct BulletTrackerWidgets_Previews: PreviewProvider {
    static var previews: some View {
        HabitWidgetView(entry: HabitWidgetEntry.placeholder)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}