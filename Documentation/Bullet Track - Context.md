# 🎯 BULLET TRACKER MASTER CONTEXT
(December 20, 2024 - v1.1)

## 🔧 General App Overview
- **App Name**: Bullet Tracker
- **Purpose**: Comprehensive journaling and habit tracking app inspired by the bullet journal methodology
- **Core Technologies**:
  • SwiftUI for UI
  • Core Data for local database
  • CloudKit for iCloud sync
  • JSON for structured data storage within Core Data
  • File-based backup system
- **Platforms**: iOS (iPhone, iPad)
- **Distribution**: [Current distribution method - App Store/TestFlight]
- **UI Design**: Clean interface focused on habit tracking with multi-state completions

## 📊 Data Architecture

### Core Data Model
**Habit**: Main habit definition entity
- Properties: id, name, icon, color, frequency, customDays, startDate, notes, useMultipleStates, trackDetails, detailType
- Relationships: collection (many-to-one), entries (one-to-many with HabitEntry)

**HabitEntry**: Individual habit completion records
- Properties: id, date, completed, details (JSON string)
- Dynamic Properties: completionState (Int: 0=none, 1=success, 2=partial, 3=failure)
- Relationships: habit (many-to-one with Habit)

**Collection**: Organization container for habits and entries
- Properties: id, name, icon, color
- Relationships: habits (one-to-many), journalEntries (one-to-many)

**JournalEntry**: Bullet journal entries
- Properties: id, content, type (task/event/note), status, date
- Relationships: collection (many-to-one), tags (many-to-many)

**Tag**: Metadata for entries
- Properties: id, name, color
- Relationships: entries (many-to-many with JournalEntry)

### Persistence Stack
- **CoreDataManager**: Singleton manager for Core Data operations
- **Container**: NSPersistentCloudKitContainer (when sync enabled) or NSPersistentContainer (when sync disabled)
- **CloudKit Configuration**: 
  • Container ID: iCloud.db23.BulletTracker
  • History tracking enabled for sync
  • Remote notifications enabled for push updates
- **Backup System**: JSON export/import functionality for data migration

### CloudKit Implementation Details
- **Dynamic Container Selection**: Based on UserDefaults "iCloudSyncEnabled" setting
- **Required Capabilities**: 
  • CloudKit capability in Xcode
  • Remote Notifications background mode
  • Push Notifications capability
- **Sync Behavior**: Automatic background sync with ~30-60 second delay
- **Conflict Resolution**: NSMergeByPropertyObjectTrumpMergePolicy (latest change wins)

## 🏗 App Architecture

### Navigation System
- **Tab-Based Navigation**: Main tabs for different app sections
  • Daily Log tab (DailyLogView)
  • Habits tab (HabitTrackerView)
  • Collections tab (CollectionsView)
  • Index tab (IndexView)
  • Settings tab (SettingsView)

### Key UI Patterns
- **Multi-State Components**: HabitCheckboxView with cycling states
- **Detail Tracking**: Expandable habit entries with workout details
- **Statistics Display**: Toggle between percentage and fraction views
- **Entry Types**: Visual differentiation for tasks, events, and notes
- **Sync Status**: Visual indicator in settings when iCloud sync is enabled

### Habit Tracking System
- **Completion States**:
  • None (0) - Empty checkbox
  • Success (1) - Filled checkbox with habit color
  • Partial (2) - Orange indicator
  • Attempted (3) - Red indicator
- **Frequency Types**:
  • Daily - Every day
  • Weekdays - Monday through Friday
  • Weekends - Saturday and Sunday
  • Weekly - Specific days of the week
  • Custom - User-defined day pattern

## 📱 Major Features and Views

### Core Navigation
- **MainTabView**: Root container with tab navigation
- **DailyLogView**: Daily journal entries and quick habit tracking
- **HabitTrackerView**: Main habit tracking grid with multi-state support
- **CollectionsView**: Organization of habits and entries
- **IndexView**: Search and browse all entries
- **SettingsView**: App configuration, backup management, and sync settings

### Habit Management
- **AddHabitView**: Creation of new habits with customization options
- **EditHabitView**: Modification of existing habits
- **HabitDetailView**: Detailed view of habit with statistics
- **HabitCheckboxView**: Interactive multi-state completion indicator
- **HabitDetailIndicatorView**: Visual summary of habit details
- **HabitStatsView**: Progress visualization with timeframe selection

### Journal Features
- **AddEntryView**: Creation of new journal entries
- **EntryRowView**: Display of journal entries with type-specific formatting
- **EntryDetailView**: Full view of journal entry with editing

### Workout Tracking
- **WorkoutDetailView**: Specialized view for fitness habits
  • Multiple workout type selection
  • Duration and intensity tracking
  • Notes and completion state
- **JSON Structure**:
```json
{
  "types": ["Cardio", "Strength"],  // Array of workout types
  "type": "Cardio",                 // Legacy support
  "duration": "45",                  // Minutes
  "intensity": "Medium",             // Low/Medium/High
  "notes": "Morning run",            // User notes
  "completionState": 1               // Success/Partial/Attempted
}
```

### Statistics & Analytics
- **HabitStatsView**: Comprehensive statistics display
  • Success/Partial/Failure breakdown
  • Percentage or fraction toggle
  • Natural timeframes (Week/Month/Quarter)
- **Calculation Pattern**: Count expected vs actual completions based on frequency

### Backup & Restore
- **BackupManager**: Core Data serialization and restoration
- **BackupRestoreViewModel**: UI management for backup operations
- **File Format**: JSON with complete app data structure
- **Naming Convention**: "BulletTracker_Backup_YYYY-MM-DD_HHMMSS.json"

### iCloud Sync
- **Sync Toggle**: Enable/disable in Settings → Sync section
- **Implementation**: NSPersistentCloudKitContainer with automatic sync
- **Requirements**: Same iCloud account on all devices, iCloud Drive enabled
- **Sync Timing**: Automatic background sync, typically within 30-60 seconds

## 🎯 Current Major Areas Status

| Area | Status |
|------|--------|
| Core Data Stack | ✅ Fully Working |
| Habit Tracking | ✅ Fully Implemented |
| Multi-State Completions | ✅ Fully Implemented |
| Multiple Workout Types | ✅ Fully Implemented |
| Journal Entries | ✅ Basic Implementation |
| Collections | ✅ Basic Implementation |
| Statistics View | ✅ Fully Implemented |
| Backup System | ✅ Fully Implemented |
| iCloud Sync | ✅ Fully Implemented |
| Dark Mode Support | 🔧 Needs Review |
| iPad Optimization | 📋 Planned |
| Analytics Dashboard | 📋 Next Priority |

## 🎨 UI/UX Standards

### Color System
- **Habit Colors**: Stored as hex strings, converted via Color extension
- **State Colors**:
  • Success: Habit's custom color
  • Partial: Orange
  • Attempted: Red
  • None: Secondary/gray
- **System Colors**: Use semantic colors for adaptability

### Component Patterns
- **Checkbox States**: Visual cycling through tap gestures
- **Detail Indicators**: Compact summaries of workout details
- **Statistics Display**: Clean percentage/fraction toggle
- **Entry Formatting**: Type-specific visual treatments
- **Sync Status**: Green checkmark with "Syncing with iCloud" text

## 🔨 Important Developer Notes

### Core Data Best Practices
- **Dynamic Properties**: Use setValue/value(forKey:) for properties added via migrations
- **JSON Storage**: Store structured data in details field as JSON strings
- **Backward Compatibility**: Always maintain legacy data format support
- **Performance**: Use proper predicates for fetch requests
- **CloudKit Requirements**: All entities must have UUID identifiers

### State Management
- **Multi-State Logic**: Cycle through states in consistent order
- **Entry Creation**: Check for existing entries before creating new ones
- **Statistics Calculation**: Account for habit frequency and start date
- **Sync State**: Monitor UserDefaults for "iCloudSyncEnabled" preference

### Data Migration Patterns
```swift
// Reading with backward compatibility
if let types = json["types"] as? [String] {
    selectedWorkoutTypes = Set(types)
} else if let type = json["type"] as? String {
    selectedWorkoutTypes = [type]
}

// Writing with backward compatibility
"types": Array(selectedWorkoutTypes),      // New format
"type": selectedWorkoutTypes.first ?? "",   // Legacy support
```

### CloudKit Implementation Pattern
```swift
// Dynamic container selection based on sync setting
let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true

if iCloudEnabled {
    container = NSPersistentCloudKitContainer(name: "Bullet_Tracker")
    // Configure for CloudKit
} else {
    container = NSPersistentContainer(name: "Bullet_Tracker")
}
```

### Common Challenges & Solutions

**Dynamic Core Data Properties**:
- Some properties added post-launch via migrations
- Access using setValue/value(forKey:) pattern
- Always provide default values for safety

**JSON Data Integrity**:
- Validate JSON before saving to Core Data
- Handle parsing errors gracefully
- Maintain backward compatibility

**Statistics Edge Cases**:
- New habits with no entries
- Habits with future start dates
- Custom frequency patterns

**CloudKit Sync Issues**:
- Initial sync may create duplicates (resolved by establishing source of truth)
- Sync requires app restart when toggling setting (Core Data limitation)
- Both devices must have iCloud Drive enabled
- Network connectivity required for sync

## 📅 Development Roadmap

### Short-Term Priorities
1. **Analytics Dashboard** (Current Focus):
   - Visualize habit completion trends
   - Provide insights on patterns
   - Create customizable metric views

2. **UI Enhancements**:
   - Improve animations and transitions
   - Enhance visual feedback for user actions
   - Implement streak tracking visualizations

3. **Performance Optimization**:
   - Optimize for large datasets
   - Implement caching for statistics

### Medium-Term Goals
- Enhanced journal entry features
- Calendar integration for habit scheduling
- iPad-optimized layouts
- Deduplication logic for CloudKit sync
- Print view for physical bullet journals

### Long-Term Vision
- Apple Watch companion app
- Sharing and collaboration features
- Advanced analytics and insights
- AI-powered habit recommendations
- Export to physical bullet journal format

## 🔧 Technical Debt & Known Issues
- Dark mode color consistency needs review
- Some views could benefit from view model extraction
- Performance optimization needed for habits with many entries
- Statistics calculation could be more efficient with caching
- iCloud sync setting change requires app restart (Core Data limitation)

## 📝 Code Organization Patterns

### File Structure
```
BulletTracker/
├── Models/
│   ├── CoreData/
│   └── ViewModels/
├── Views/
│   ├── Habits/
│   ├── Journal/
│   ├── Collections/
│   └── Settings/
├── Managers/
│   ├── CoreDataManager.swift
│   └── BackupManager.swift
└── Extensions/
    └── Color+Hex.swift
```

### Naming Conventions
- **Views**: [Feature]View (e.g., HabitTrackerView)
- **View Models**: [Feature]ViewModel (e.g., BackupRestoreViewModel)
- **Managers**: [Function]Manager (e.g., CoreDataManager)
- **Extensions**: [Type]+[Feature] (e.g., Color+Hex)

### Key Implementation Files for iCloud
- **CoreDataManager.swift**: Container selection and CloudKit configuration
- **SettingsView.swift**: iCloud sync toggle UI
- **Info.plist**: Automatically updated with remote-notification background mode

✅ This Master Context file should be referenced for all future development.
(Version 1.1 — December 20, 2024)
