//
//  ContentView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    
    @State private var selectedTab = 0
    
    // MARK: - Constants
    
    private enum Tab: Int, CaseIterable {
        case daily = 0
        case habits = 1
        case collections = 2
        case settings = 3
    }
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            dailyLogTab
            habitsTab
            collectionsTab
            settingsTab
        }
    }
    
    // MARK: - Tab Views
    
    /// Daily log tab for current day's entries
    private var dailyLogTab: some View {
        DailyLogView()
            .tabItem {
                Label("Daily", systemImage: "calendar.day.timeline.leading")
            }
            .tag(Tab.daily.rawValue)
    }
    
    /// Habits tab for tracking daily habits
    private var habitsTab: some View {
        NavigationStack {
            HabitTrackerView()
        }
        .tabItem {
            Label("Habits", systemImage: "chart.bar.fill")
        }
        .tag(Tab.habits.rawValue)
    }
    
    /// Collections tab for organizing entries and accessing index
    private var collectionsTab: some View {
        SimpleCollectionsView()
            .tabItem {
                Label("Collections", systemImage: "folder")
            }
            .tag(Tab.collections.rawValue)
    }
    
    /// Settings tab for app configuration
    private var settingsTab: some View {
        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings.rawValue)
    }
}
