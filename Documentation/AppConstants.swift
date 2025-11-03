//  AppConstants.swift
//  Bullet Tracker
//
//  Created for app optimization on 11/03/25.
//

import Foundation

/// Centralized constants for the Bullet Tracker app
struct AppConstants {
    
    // MARK: - App Group
    
    /// App Group identifier for sharing data between main app and widget
    static let appGroupIdentifier = "group.db23.Bullet-Tracker"
    
    // MARK: - Widget Configuration
    
    /// Maximum number of habits displayed in medium widget
    static let maxHabitsInMediumWidget = 6
    
    /// Maximum number of habits displayed in large widget  
    static let maxHabitsInLargeWidget = 12
    
    /// Widget kind identifier
    static let habitWidgetKind = "HabitTrackerWidget"
    
    // MARK: - Cache Configuration
    
    /// Cache expiration time in minutes
    static let cacheExpirationMinutes = 5
    
    /// Maximum number of months to keep in cache
    static let maxCachedMonths = 5
    
    // MARK: - Core Data Configuration
    
    /// Core Data model name
    static let coreDataModelName = "Bullet_Tracker"
    
    /// SQLite database filename
    static let databaseFilename = "BulletTracker.sqlite"
    
    // MARK: - User Defaults Keys
    
    /// Key for iCloud sync setting
    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    
    /// Key for reminder setting
    static let reminderEnabledKey = "reminderEnabled"
    
    /// Key for reminder time setting
    static let reminderTimeKey = "reminderTime"
    
    /// Key for widget update timestamp
    static let lastWidgetUpdateKey = "lastWidgetUpdate"
    
    // MARK: - UI Configuration
    
    /// Number of days displayed in habit tracker
    static let daysToShowInTracker = 4
    
    /// Auto-save interval for special entries (seconds)
    static let autoSaveIntervalSeconds: TimeInterval = 30
    
    /// Debouncing delay for form inputs (seconds)
    static let formDebounceDelaySeconds: TimeInterval = 0.3
    
    // MARK: - Migration Configuration
    
    /// Days after which old tasks prompt for Future Log migration
    static let oldTaskPromptThreshold = 5
    
    /// Maximum age indicators to show for migrated tasks
    static let maxAgeIndicators = 3
    
    // MARK: - File Names
    
    /// Widget commands file name
    static let widgetCommandsFileName = "widget_commands.json"
    
    /// Backup file prefix
    static let backupFilePrefix = "BulletTracker_Backup_"
    
    /// Backup file extension
    static let backupFileExtension = ".json"
}