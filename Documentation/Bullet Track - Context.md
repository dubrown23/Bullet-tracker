# 🎯 BULLET TRACKER MASTER CONTEXT
(November 3, 2025 - v1.5)

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
- **Code Quality**: Production-ready with modern Swift patterns and zero DEBUG statements
- **Widget Support**: Home screen widgets with interactive habit tracking

## 📊 Data Architecture

### Core Data Model
**Habit**: Main habit definition entity
- Properties: id, name, icon, color, frequency, customDays, startDate, notes, useMultipleStates, trackDetails, detailType, isNegativeHabit
- Relationships: collection (many-to-one - deprecated), entries (one-to-many with HabitEntry)

**HabitEntry**: Individual habit completion records
- Properties: id, date, completed, details (JSON string)
- Dynamic Properties: completionState (Int: 0=none, 1=success, 2=partial, 3=failure)
- Relationships: habit (many-to-one with Habit)

**Collection**: Organization container for journal entries
- Properties: id, name, icon, color, isAutomatic, sortOrder, collectionType
- Relationships: habits (one-to-many - deprecated), journalEntries (one-to-many)
- Note: Automatic collections created for Future Log, Years, and Monthly Log

**JournalEntry**: Bullet journal entries
- Properties: id, content, type (task/event/note), status, date, scheduledDate, isFutureEntry, hasMigrated, isSpecialEntry, specialEntryType, originalDate
- Relationships: collection (many-to-one), tags (many-to-many)
- Special Types: "review" and "outlook" for monthly planning

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
- **Tab-Based Navigation**: 4 main tabs
  • Daily Log tab (DailyLogView)
  • Habits tab (HabitTrackerView) - Primary feature
  • Collections tab (SimpleCollectionsView)
  • Settings tab (SettingsView)
- **Journal Flow Hierarchy**:
  • Future Log → Monthly Log → Daily Log
  • Year Archives → Month Archives
- **Note**: Index is now accessible as a Special Collection within Collections tab

### Key UI Patterns
- **Multi-State Components**: HabitCheckboxView with cycling states
- **Detail Tracking**: Expandable habit entries with workout details
- **Statistics Display**: Toggle between percentage and fraction views
- **Entry Types**: Visual differentiation for tasks, events, and notes
- **Sync Status**: Visual indicator in settings when iCloud sync is enabled
- **Traffic Light Colors**: Universal green/yellow/red for habit states with habit color borders
- **Future Entry Parsing**: @mention support for scheduling (@december, @dec-25)
- **Migration Indicators**: Age dots (•, ••, •••) for old tasks

### Habit Tracking System
- **Completion States**:
  • None (0) - Empty checkbox
  • Success (1) - Green fill with checkmark
  • Partial (2) - Yellow fill with half-circle icon
  • Attempted (3) - Red fill with X icon
- **Frequency Types**:
  • Daily - Every day
  • Weekdays - Monday through Friday
  • Weekends - Saturday and Sunday
  • Weekly - Specific days of the week
  • Custom - User-defined day pattern
- **Negative Habits**:
  • Red X when checked (indicates failure/relapse)
  • No multi-state support (simple toggle only)

### Digital Bullet Journal System
- **Future Log**:
  • Central scheduling for future entries
  • @mention parsing for dates
  • Month-grouped display
- **Monthly Log**:
  • Single navigable log with month switching
  • Shows entries from Future Log when due
  • Calendar view of current month
- **Daily Log**:
  • Today's entries and migrated tasks
  • Quick entry creation
  • "Schedule for Later" option
- **Migration System**:
  • Daily: Incomplete tasks → next day with age indicators
  • Monthly: All entries → year/month archives
  • Future: Scheduled entries → Daily Log when due
- **Special Entries**:
  • Monthly Reviews (📝)
  • Monthly Outlooks (📅)
  • Full-screen editors with templates

## 📱 Major Features and Views

### Core Navigation
- **ContentView**: Root container with 4-tab navigation
- **DailyLogView**: Daily journal entries with calendar picker and migration display
- **HabitTrackerView**: Main habit tracking grid with multi-state support
- **SimpleCollectionsView**: Organization of journal entries with Index access
- **IndexView**: Search and browse all entries (accessed via Collections)
- **SettingsView**: App configuration, backup management, and sync settings

### Habit Management
- **AddHabitView**: Creation of new habits (uses shared HabitFormView)
- **EditHabitView**: Modification of existing habits (uses shared HabitFormView)
- **HabitFormView**: Shared form component for habit creation/editing
- **HabitDetailView**: Detailed view of habit with statistics
- **HabitCheckboxView**: Interactive multi-state completion indicator
- **HabitDetailIndicatorView**: Visual summary of habit details
- **HabitStatsView**: Progress visualization with timeframe selection
- **HabitCompletionDetailView**: Log details with workout tracking

### Journal Features
- **NewEntryView**: Creation of new journal entries with "Schedule for Later"
- **EditEntryView**: Full entry editing with type, status, tags
- **EntryRowView**: Display of journal entries with type-specific formatting
- **EntryListItem**: Compact entry display for lists
- **FutureLogView**: Future entry management with @mention parsing
- **MonthLogView**: Current month view with navigation
- **MonthlyLogContainerView**: Navigation state management for months
- **YearLogView**: Year archive with month listing
- **MonthArchiveView**: Archived entries for specific months
- **SpecialEntryEditorView**: Full-screen editor for reviews/outlooks
- **SpecialEntryDetailView**: Display for review/outlook entries

### Workout Tracking
- **WorkoutDetailView**: Integrated into HabitCompletionDetailView
  • 2-column LazyVGrid for workout type selection
  • Duration picker with +5 minute increments
  • Intensity tracking (1-5 scale)
  • Structured note format with workout types
- **JSON Structure**:
```json
{
  "types": ["Cardio", "Strength"],  // Array of workout types
  "type": "Cardio",                 // Legacy support
  "duration": "45",                  // Minutes
  "intensity": "Medium",             // Now 1-5 scale
  "notes": "45 min\nCardio:\nStrength:",  // Structured format
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
- **DataExportManager**: Export functionality for data archiving
- **File Format**: JSON with complete app data structure
- **Naming Convention**: "BulletTracker_Backup_YYYY-MM-DD_HHMMSS.json"

### iCloud Sync
- **Sync Toggle**: Enable/disable in Settings → Sync section
- **Implementation**: NSPersistentCloudKitContainer with automatic sync
- **Requirements**: Same iCloud account on all devices, iCloud Drive enabled
- **Sync Timing**: Automatic background sync, typically within 30-60 seconds

### Widget System
- **HabitTrackerWidget**: Main widget showing today's habits in 3x2 grid
- **App Intent Integration**: CompleteHabitIntent for interactive habit completion
- **Timeline Provider**: Updates at midnight and after habit changes
- **Data Sharing**: Uses shared Core Data container with main app
- **Widget Configuration**: System Medium size with up to 6 habit buttons
- **Visual Design**: Traffic light colors with habit-specific borders
- **Smart Filtering**: Only shows habits scheduled for today based on frequency

## 🎯 Current Major Areas Status

| Area | Status | Notes |
|------|--------|-------|
| Core Data Stack | ✅ Fully Working | Enhanced with journal attributes |
| Habit Tracking | ✅ Fully Implemented | Including negative habits |
| Multi-State Completions | ✅ Fully Implemented | |
| Multiple Workout Types | ✅ Fully Implemented | |
| Digital Bullet Journal | ✅ Fully Implemented | Future Log, Monthly Log, Daily Log |
| Journal Entries | ✅ Enhanced | With scheduling and special types |
| Collections | ✅ Enhanced | Automatic collections for journal flow |
| Navigation Structure | ✅ Restructured | 4-tab system with journal hierarchy |
| Statistics View | ✅ Fully Implemented | |
| Backup System | ✅ Fully Implemented | |
| iCloud Sync | ✅ Fully Implemented | |
| Migration System | ✅ Fully Implemented | Daily and monthly migrations |
| Code Optimization | ✅ Complete | Production-ready, zero DEBUG |
| Widget Support | ✅ Fully Implemented | Interactive home screen widgets |
| Dark Mode Support | 🔧 Needs Review | |
| iPad Optimization | 📋 Planned | |
| Analytics Dashboard | 📋 Next Priority | Workout detail visualization |

## 🎨 UI/UX Standards

### Color System
- **Habit Colors**: Stored as hex strings, converted via Color extension
- **State Colors** (Traffic Light System):
  • Success: Green fill
  • Partial: Yellow fill
  • Attempted: Red fill
  • None: Secondary/gray
  • Negative Habit Checked: Red with X
- **Habit Border**: Always shows habit's custom color
- **System Colors**: Use semantic colors for adaptability
- **Special Entry Colors**:
  • Reviews: Purple background
  • Outlooks: Green background

### Component Patterns
- **Checkbox States**: Visual cycling through tap gestures
- **Detail Indicators**: Compact summaries of workout details
- **Statistics Display**: Clean percentage/fraction toggle
- **Entry Formatting**: Type-specific visual treatments
- **Sync Status**: Green checkmark with "Syncing with iCloud" text
- **Date Range Picker**: Shows 4-day range ending on selected date
- **Migration Indicators**: Age dots for task age visualization
- **@Mention Parsing**: Real-time date parsing with green confirmation

### Modern Swift Patterns
- **Static DateFormatters**: 15+ instances for performance
- **Computed Properties**: Replaced 30+ @State variables where appropriate
- **async/await**: Modern concurrency for auto-save
- **@MainActor**: Proper main thread handling
- **@FocusState**: Keyboard and focus management
- **Single-Pass Algorithms**: Optimized collection operations

## 🔨 Important Developer Notes

### Core Data Best Practices
- **Dynamic Properties**: Use setValue/value(forKey:) for properties added via migrations
- **JSON Storage**: Store structured data in details field as JSON strings
- **Backward Compatibility**: Always maintain legacy data format support
- **Performance**: Use proper predicates for fetch requests
- **CloudKit Requirements**: All entities must have UUID identifiers
- **Deprecated Relationships**: Habit-Collection relationship no longer used
- **Automatic Collections**: Created and managed by CollectionManager

### State Management
- **Multi-State Logic**: Cycle through states in consistent order
- **Entry Creation**: Check for existing entries before creating new ones
- **Statistics Calculation**: Account for habit frequency and start date
- **Sync State**: Monitor UserDefaults for "iCloudSyncEnabled" preference
- **Date Updates**: Use scenePhase to detect new days without restart
- **Navigation State**: MonthlyLogContainerView manages month navigation

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

### Migration System Patterns
```swift
// Daily migration for incomplete tasks
// Tasks get "→" prefix and age indicators (•, ••, •••)
// 5+ day old tasks prompt for Future Log migration

// Monthly migration archives all entries
// Creates year/month collection structure
// Preserves all entry data for review
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

**Date Update Bug**:
- TabView doesn't trigger onAppear when switching tabs
- Solution: Monitor scenePhase for app becoming active
- Check if date changed and update accordingly

**Future Entry Parsing**:
- Case-insensitive month recognition
- Smart next occurrence logic
- Supports multiple date formats

## 📅 Development Roadmap

### Immediate Priorities
1. **Analytics Dashboard** (Next Implementation):
   - Visualize workout details from habit entries
   - Show trends and patterns
   - Aggregate statistics across time periods
   - Habit correlation analysis

### Short-Term Goals
- Dark mode color consistency fixes
- Performance optimization for large datasets
- iPad-optimized layouts with better space usage
- Deduplication logic for CloudKit sync conflicts
- Widget support for quick tracking

### Medium-Term Goals
- Apple Watch companion app
- Calendar integration for habit scheduling
- Print view for physical bullet journals
- Sharing and collaboration features
- Export formats beyond JSON
- Shortcuts integration

### Long-Term Vision
- Advanced analytics with ML insights
- Health app integration
- Habit recommendations based on patterns
- Team/family tracking features
- API for third-party integrations

## 🔧 Technical Debt & Known Issues
- Dark mode color consistency needs review
- Some views could benefit from view model extraction
- Performance optimization needed for habits with many entries
- Statistics calculation could be more efficient with caching
- iCloud sync setting change requires app restart (Core Data limitation)
- Collection assignment for habits deprecated but relationship still in Core Data
- Year/month archive collections could benefit from lazy loading

## 📝 Code Organization Patterns

### File Structure
```
BulletTracker/
├── App/
│   ├── Bullet_TrackerApp.swift
│   ├── ContentView.swift
│   └── SettingsView.swift
├── Journal/
│   ├── DailyLogView.swift
│   ├── FutureLogView.swift
│   ├── MonthLogView.swift
│   ├── MonthlyLogContainerView.swift
│   ├── YearLogView.swift
│   ├── MonthArchiveView.swift
│   ├── NewEntryView.swift
│   ├── EditEntryView.swift
│   ├── EntryRowView.swift
│   ├── EntryListItem.swift
│   ├── SpecialEntryEditorView.swift
│   └── SpecialEntryDetailView.swift
├── Habits/
│   ├── HabitFormView.swift
│   ├── AddHabitView.swift
│   ├── EditHabitView.swift
│   ├── HabitTrackerView.swift
│   ├── HabitTrackerViewModel.swift
│   ├── HabitCheckboxView.swift
│   ├── HabitCompletionDetailView.swift
│   ├── HabitDetailIndicatorView.swift
│   ├── HabitRowLabelView.swift
│   ├── HabitProgressView.swift
│   └── HabitStatsView.swift
├── Collections/
│   ├── SimpleCollectionsView.swift
│   ├── CollectionDetailView.swift
│   └── IndexView.swift
├── Data/
│   ├── CoreDataManager.swift
│   ├── CoreDataManager+HabitDetails.swift
│   ├── BackupManager.swift
│   ├── BackupRestoreViewModel.swift
│   └── DataExportManager.swift
├── Widgets/
│   └── BulletTrackerWidgetsBundle.swift
├── Utilities/
│   ├── IconSelectorView.swift
│   ├── FutureEntryParser.swift
│   ├── SpecialEntryTemplates.swift
│   ├── CollectionManager.swift
│   ├── MigrationManager.swift
│   ├── Constants.swift
│   ├── HabitConstants.swift
│   └── Color+Hex.swift
└── Resources/
    └── Assets.xcassets
```

### Naming Conventions
- **Views**: [Feature]View (e.g., HabitTrackerView)
- **View Models**: [Feature]ViewModel (e.g., HabitTrackerViewModel)
- **Managers**: [Function]Manager (e.g., CoreDataManager)
- **Extensions**: [Type]+[Feature] (e.g., Color+Hex)
- **Parsers**: [Feature]Parser (e.g., FutureEntryParser)
- **Shared Components**: [Feature]View for reusable UI

### Key Implementation Files
- **CoreDataManager.swift**: Container selection and CloudKit configuration
- **HabitTrackerView.swift**: Main habit tracking interface with date update logic
- **HabitTrackerViewModel.swift**: View model for habit tracking with data repository integration
- **ContentView.swift**: Tab navigation structure
- **SimpleCollectionsView.swift**: Collections with automatic journal collections
- **MigrationManager.swift**: Daily and monthly migration logic
- **CollectionManager.swift**: Automatic collection creation and management
- **FutureEntryParser.swift**: @mention date parsing with static regex
- **HabitFormView.swift**: Shared form component for habit create/edit
- **BulletTrackerWidgetsBundle.swift**: Complete widget implementation with App Intents

## 🐛 Recent Bug Fixes
1. **Delete Habit Context Menu**: Fixed issue where delete opened edit view
2. **Date Update Bug**: Habit tracker now updates when app becomes active
3. **Navigation Structure**: Habits elevated to primary tab
4. **Collection Assignment**: Removed from habit creation/editing
5. **Future Entry Parsing**: Fixed "may" month dictionary crash
6. **Month Navigation**: Fixed empty month display in archives
7. **Special Entry Storage**: Corrected to save in month archives

## 🎉 Major Achievements
- **Full Digital Bullet Journal**: Complete Future Log → Monthly Log → Daily Log flow
- **Production-Ready Code**: 82+ DEBUG statements removed, optimized throughout
- **Code Reuse**: 500+ lines eliminated through shared components
- **Modern Swift**: async/await, @MainActor, static formatters throughout
- **Seamless Sync**: iCloud integration working flawlessly
- **Smart Migration**: Automatic daily and monthly task/entry migration
- **Widget Integration**: Interactive home screen widgets with App Intent support

✅ This Master Context file should be referenced for all future development.
(Version 1.5 — November 3, 2025) 
