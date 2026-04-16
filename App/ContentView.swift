//
//  ContentView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct ContentView: View {
    // MARK: - State Properties

    @State private var selectedTab: Tab = .today
    @State private var previousTab: Tab = .today

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Constants

    private enum Tab: Int, CaseIterable, Identifiable {
        case today = 0
        case dashboard = 1
        case journal = 2
        case settings = 3

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .today: return "Today"
            case .dashboard: return "Dashboard"
            case .journal: return "Journal"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .today: return "sun.max"
            case .dashboard: return "chart.bar.fill"
            case .journal: return "book"
            case .settings: return "gear"
            }
        }

        var selectedIcon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .dashboard: return "chart.bar.fill"
            case .journal: return "book.fill"
            case .settings: return "gear"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            todayTab
            dashboardTab
            journalTab
            settingsTab
        }
        .tint(AppTheme.accent)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Soft haptic feedback on tab change
            if oldValue != newValue {
                let impact = UIImpactFeedbackGenerator(style: .soft)
                impact.impactOccurred(intensity: 0.5)
                previousTab = oldValue
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh data when app becomes active
            if newPhase == .active {
                NotificationCenter.default.post(name: .appBecameActive, object: nil)
            }
        }
    }

    // MARK: - Tab Views

    /// Today tab - daily habit checklist (default landing)
    private var todayTab: some View {
        TodayView()
            .tabItem {
                Label(Tab.today.title, systemImage: selectedTab == .today ? Tab.today.selectedIcon : Tab.today.icon)
            }
            .tag(Tab.today)
    }

    /// Dashboard tab for habit analytics
    private var dashboardTab: some View {
        HabitDashboardView()
            .tabItem {
                Label(Tab.dashboard.title, systemImage: selectedTab == .dashboard ? Tab.dashboard.selectedIcon : Tab.dashboard.icon)
            }
            .tag(Tab.dashboard)
    }

    /// Journal tab - view any day's habits + notes
    private var journalTab: some View {
        DayJournalView()
            .tabItem {
                Label(Tab.journal.title, systemImage: selectedTab == .journal ? Tab.journal.selectedIcon : Tab.journal.icon)
            }
            .tag(Tab.journal)
    }

    /// Settings tab for app configuration
    private var settingsTab: some View {
        SettingsView()
            .tabItem {
                Label(Tab.settings.title, systemImage: selectedTab == .settings ? Tab.settings.selectedIcon : Tab.settings.icon)
            }
            .tag(Tab.settings)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appBecameActive = Notification.Name("appBecameActive")
}
