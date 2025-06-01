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
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            dailyLogTab
            collectionsTab
            indexTab
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
            .tag(0)
    }
    
    /// Collections tab for organizing entries
    private var collectionsTab: some View {
        SimpleCollectionsView()
            .tabItem {
                Label("Collections", systemImage: "folder")
            }
            .tag(1)
    }
    
    /// Index tab for browsing all entries
    private var indexTab: some View {
        IndexView()
            .tabItem {
                Label("Index", systemImage: "list.bullet")
            }
            .tag(2)
    }
    
    /// Settings tab for app configuration
    private var settingsTab: some View {
        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
    }
}
