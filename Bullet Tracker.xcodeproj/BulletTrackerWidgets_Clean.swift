//
//  BulletTrackerWidgets_Clean.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//

import WidgetKit
import SwiftUI

// MARK: - Simple Widget Entry

struct SimpleHabitEntry: TimelineEntry {
    let date: Date
    let message: String
}

// MARK: - Simple Provider

struct SimpleHabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleHabitEntry {
        SimpleHabitEntry(date: Date(), message: "Widget Ready!")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleHabitEntry) -> ()) {
        let entry = SimpleHabitEntry(date: Date(), message: "Today's Habits")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleHabitEntry>) -> ()) {
        let entry = SimpleHabitEntry(date: Date(), message: "Tracking Habits")
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Simple Widget View

struct SimpleHabitWidgetView: View {
    let entry: SimpleHabitEntry
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            Text(entry.message)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(entry.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("🎯 Bullet Tracker Widget")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Clean Habit Tracker Widget

struct CleanHabitTrackerWidget: Widget {
    let kind: String = "CleanHabitTrackerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleHabitProvider()) { entry in
            SimpleHabitWidgetView(entry: entry)
        }
        .configurationDisplayName("Habit Tracker")
        .description("Simple habit tracking widget.")
        .supportedFamilies([.systemMedium])
    }
}