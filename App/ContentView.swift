//
//  ContentView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct ContentView: View {
    // MARK: - State Properties

    @State private var selectedTab: AppTab = .today

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    // MARK: - Tabs

    /// Named `AppTab` (not `Tab`) so it doesn't shadow SwiftUI's `Tab` type.
    private enum AppTab: Hashable {
        case today
        case dashboard
        case journal
        case settings
    }

    // MARK: - Body

    var body: some View {
        // `Tab` API + `.sidebarAdaptable`: bottom bar on a narrow window, top bar /
        // sidebar on a wide one (iPad, iPhone Duo unfolded). Outline symbols only —
        // the system swaps in the filled variant for the selected tab.
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max", value: .today) {
                TodayView()
            }
            Tab("Dashboard", systemImage: "chart.bar", value: .dashboard) {
                HabitDashboardView()
            }
            Tab("Journal", systemImage: "book", value: .journal) {
                DayJournalView()
            }
            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(AppTheme.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh data when app becomes active
            if newPhase == .active {
                NotificationCenter.default.post(name: .appBecameActive, object: nil)
                // bt-0017 / bt-0018 — "sync is automatic when the app opens".
                // Steps + grades every time; the fake source when the
                // Developer switch is on (debug builds); dh in Step 3.
                Task { await HabitSyncEngine.shared.refresh(in: modelContext) }
            }
            // bt-0020 — a tap still waiting when the app leaves (lock, Home)
            // goes now, inside the background window taken at the tap.
            if newPhase == .background {
                HabitSyncEngine.shared.appLeftForeground()
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appBecameActive = Notification.Name("appBecameActive")
}
