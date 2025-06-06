//
//  MonthlyLogContainerView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/4/25.
//

import SwiftUI

struct MonthlyLogContainerView: View {
    // MARK: - State Properties
    
    @State private var currentYear: Int
    @State private var currentMonth: Int
    
    // MARK: - Private Properties
    
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        _currentYear = State(initialValue: calendar.component(.year, from: now))
        _currentMonth = State(initialValue: calendar.component(.month, from: now))
    }
    
    // MARK: - Body
    
    var body: some View {
        MonthLogView(
            year: currentYear,
            month: currentMonth,
            onNavigatePrevious: navigateToPreviousMonth,
            onNavigateNext: navigateToNextMonth
        )
        .id("\(currentYear)-\(currentMonth)") // Force view refresh on navigation
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToPreviousMonth() {
        adjustMonth(by: -1)
    }
    
    private func navigateToNextMonth() {
        adjustMonth(by: 1)
    }
    
    private func adjustMonth(by value: Int) {
        let components = DateComponents(year: currentYear, month: currentMonth)
        
        if let currentDate = calendar.date(from: components),
           let newDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentYear = calendar.component(.year, from: newDate)
            currentMonth = calendar.component(.month, from: newDate)
        }
    }
}
