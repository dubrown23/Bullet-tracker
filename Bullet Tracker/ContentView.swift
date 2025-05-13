//
//  ContentView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DailyLogView()
                .tabItem {
                    Label("Daily", systemImage: "calendar.day.timeline.leading")
                }
                .tag(0)
            
            SimpleCollectionsView()
                .tabItem {
                    Label("Collections", systemImage: "folder")
                }
                .tag(1)
            
            IndexView()
                .tabItem {
                    Label("Index", systemImage: "list.bullet")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}
