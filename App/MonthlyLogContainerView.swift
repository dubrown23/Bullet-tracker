//
//  MonthlyLogContainerView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/4/25.
//


//
//  MonthlyLogContainerView.swift
//  Bullet Tracker
//
//  Created on June 4, 2025
//

import SwiftUI

struct MonthlyLogContainerView: View {
    // MARK: - State Properties
    
    @State private var currentYear: Int
    @State private var currentMonth: Int
    
    // MARK: - Initialization
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        _currentYear = State(initialValue: calendar.component(.year, from: now))
        _currentMonth = State(initialValue: calendar.component(.month, from: now))
    }
    
    // MARK: - Body
    
    var body: some View {
        MonthLogViewWrapper(year: currentYear, month: currentMonth)
            .id("\(currentYear)-\(currentMonth)") // Force view refresh on navigation
    }
}

// Wrapper to handle navigation state
struct MonthLogViewWrapper: View {
    let year: Int
    let month: Int
    
    @State private var navigationYear: Int
    @State private var navigationMonth: Int
    
    init(year: Int, month: Int) {
        self.year = year
        self.month = month
        _navigationYear = State(initialValue: year)
        _navigationMonth = State(initialValue: month)
    }
    
    var body: some View {
        MonthLogView(
            year: navigationYear,
            month: navigationMonth,
            onNavigatePrevious: navigateToPreviousMonth,
            onNavigateNext: navigateToNextMonth
        )
    }
    
    private func navigateToPreviousMonth() {
        let calendar = Calendar.current
        let components = DateComponents(year: navigationYear, month: navigationMonth)
        
        if let currentDate = calendar.date(from: components),
           let newDate = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            navigationYear = calendar.component(.year, from: newDate)
            navigationMonth = calendar.component(.month, from: newDate)
        }
    }
    
    private func navigateToNextMonth() {
        let calendar = Calendar.current
        let components = DateComponents(year: navigationYear, month: navigationMonth)
        
        if let currentDate = calendar.date(from: components),
           let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            navigationYear = calendar.component(.year, from: newDate)
            navigationMonth = calendar.component(.month, from: newDate)
        }
    }
}