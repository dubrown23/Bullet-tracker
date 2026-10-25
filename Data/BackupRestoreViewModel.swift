//
//  BackupRestoreView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/15/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Document Picker Delegate

// `UIDocumentPickerDelegate` callbacks fire on the main thread per UIKit's
// contract; pinning the class to `@MainActor` lets it touch the `@MainActor`-
// isolated `BackupRestoreViewModel.processSelectedBackup(url:)` callback
// without crossing an actor boundary. Added in bt-0003 Wave 0 (pre-flight
// enable) after the bt-0002 SwiftData migration left this off-main.
@MainActor
class BackupPickerDelegate: NSObject, UIDocumentPickerDelegate {
    var onDocumentsPicked: ((URL) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        // Always create a local copy to avoid security-scoped access timing issues
        // The security access may expire before restore actually runs (user confirms dialog first)
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let localCopy = documentsDirectory.appendingPathComponent("backup_temp.json")

        // Start security-scoped access for the copy operation
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Remove any existing temp file
            try? FileManager.default.removeItem(at: localCopy)

            // Copy to local documents directory where we have permanent access
            try FileManager.default.copyItem(at: url, to: localCopy)
            onDocumentsPicked?(localCopy)
        } catch {
            // If copy fails, try with original URL as last resort
            debugLog("Failed to create local backup copy: \(error.localizedDescription)")
            onDocumentsPicked?(url)
        }
    }
}

// MARK: - View Model

// `@MainActor` is the fix for the bt-0002 deferred device-test failure:
// `createBackup` / `restoreFromBackup` spawn unstructured `Task { }`s, which
// do NOT inherit actor isolation from a non-isolated class. The success
// handlers (`handleBackupSuccess`, `handleRestoreCompletion`) then ran off
// the main thread, and the `viewController.present(activityVC, ...)` call in
// `handleBackupSuccess` tripped `_dispatch_assert_queue_fail` →
// `EXC_BREAKPOINT`. Pinning the class to `@MainActor` makes the enclosing
// `Task { }` inherit main-actor isolation; the existing
// `await Task.detached { ... }.value` still hops off main for the heavy
// backup/restore work and resumes back on main. Added in bt-0003 Wave 0.
@Observable
@MainActor
class BackupRestoreViewModel {
    // MARK: - Alert Type
    
    enum AlertType: Identifiable {
        case error(String)
        case success(String)
        
        var id: String {
            switch self {
            case .error(let message): return "error-\(message)"
            case .success(let message): return "success-\(message)"
            }
        }
        
        var title: String {
            switch self {
            case .error: return "Error"
            case .success: return "Success"
            }
        }
        
        var message: String {
            switch self {
            case .error(let msg), .success(let msg): return msg
            }
        }
    }
    
    // MARK: - Published Properties
    
    var isCreatingBackup = false
    var isRestoringBackup = false
    var backupProgress: Float = 0
    var restoreProgress: Float = 0
    var currentAlert: AlertType?
    var showImportPicker = false
    var showConfirmRestore = false
    var selectedBackupURL: URL?
    /// The most recent backup file, ready to hand to a `ShareLink`.
    var backupFileURL: URL?
    var documentPickerDelegate = BackupPickerDelegate()
    
    // MARK: - Private Properties for Memory Management

    // `nonisolated(unsafe)` is the only valid form here, despite a compiler
    // warning that suggests bare `nonisolated`. Bare `nonisolated` is rejected
    // by the compiler for mutable stored properties ("'nonisolated' cannot be
    // applied to mutable stored properties — convert to `let` or use
    // `nonisolated(unsafe)`"). `let` is wrong (we mutate them); `unsafe` is
    // accurate (it's safe in practice because writes go through `@MainActor`
    // setup paths and `NotificationCenter.removeObserver(_:)` is thread-safe,
    // but the compiler can't prove it). `@ObservationIgnored` keeps these out
    // of SwiftUI's tracking — they're cleanup state, not UI state. Added in
    // bt-0003 Wave 0 alongside the class-level `@MainActor` annotation.
    @ObservationIgnored
    private nonisolated(unsafe) var backupProgressObserver: NSObjectProtocol?
    @ObservationIgnored
    private nonisolated(unsafe) var restoreProgressObserver: NSObjectProtocol?
    
    // MARK: - Lifecycle
    
    deinit {
        // Clean up any remaining observers
        if let observer = backupProgressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = restoreProgressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// Creates a backup file. On success `backupFileURL` is set and the view
    /// shows a `ShareLink` for it — no UIKit presentation from a root view
    /// controller, so this works in any window (iPhone Duo, iPad, multi-window).
    func createBackup() {
        isCreatingBackup = true
        backupProgress = 0
        backupFileURL = nil
        setupBackupProgressObserver()

        Task {
            let backupURL = await Task.detached(priority: .userInitiated) {
                let context = ModelContext(DataStore.shared)
                return BackupManager.shared.createBackup(in: context)
            }.value

            if let backupURL {
                handleBackupSuccess(with: backupURL)
            } else {
                handleBackupError()
            }
        }
    }
    
    /// Shows file picker to select a backup file
    func selectBackupFile() {
        showImportPicker = true
    }
    
    /// Processes the selected backup file
    func processSelectedBackup(url: URL) {
        selectedBackupURL = url
        showConfirmRestore = true
    }
    
    /// Restores from the selected backup file
    func restoreFromBackup() {
        guard let backupURL = selectedBackupURL else { return }

        isRestoringBackup = true
        restoreProgress = 0
        setupRestoreProgressObserver()

        Task {
            let success = await Task.detached(priority: .userInitiated) {
                let context = ModelContext(DataStore.shared)
                return BackupManager.shared.restoreFromURL(backupURL, in: context)
            }.value

            handleRestoreCompletion(success: success)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBackupProgressObserver() {
        // Remove any existing observer first
        if let observer = backupProgressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        backupProgressObserver = NotificationCenter.default.addObserver(
            forName: .backupProgressUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // `queue: .main` puts us on the main thread but NOT in the
            // MainActor execution context (Swift 6 distinction). Hop
            // explicitly so the `@MainActor`-isolated property write
            // satisfies the concurrency checker.
            guard let progress = notification.userInfo?["progress"] as? Float else { return }
            Task { @MainActor in
                self?.backupProgress = progress
            }
        }
    }
    
    private func setupRestoreProgressObserver() {
        // Remove any existing observer first
        if let observer = restoreProgressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        restoreProgressObserver = NotificationCenter.default.addObserver(
            forName: .restoreProgressUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Same MainActor hop as the backup-progress observer above.
            guard let progress = notification.userInfo?["progress"] as? Float else { return }
            Task { @MainActor in
                self?.restoreProgress = progress
            }
        }
    }
    
    private func removeBackupProgressObserver() {
        if let observer = backupProgressObserver {
            NotificationCenter.default.removeObserver(observer)
            backupProgressObserver = nil
        }
    }
    
    private func removeRestoreProgressObserver() {
        if let observer = restoreProgressObserver {
            NotificationCenter.default.removeObserver(observer)
            restoreProgressObserver = nil
        }
    }
    
    private func handleBackupSuccess(with url: URL) {
        isCreatingBackup = false
        backupProgress = 1.0
        removeBackupProgressObserver()
        backupFileURL = url
    }

    private func handleBackupError() {
        isCreatingBackup = false
        removeBackupProgressObserver()

        let errorMessage = BackupManager.shared.errorMessage ?? "Failed to create backup"
        currentAlert = .error(errorMessage)
    }

    private func handleRestoreCompletion(success: Bool) {
        isRestoringBackup = false
        restoreProgress = 1.0
        removeRestoreProgressObserver()

        if success {
            currentAlert = .success("Backup restored successfully! Restart the app to see your data.")
        } else {
            let errorMessage = BackupManager.shared.errorMessage ?? "Failed to restore from backup"
            currentAlert = .error(errorMessage)
        }
    }
}

// MARK: - Main View

struct BackupRestoreView: View {
    // MARK: - State Properties
    
    @State private var viewModel = BackupRestoreViewModel()

    // MARK: - Body
    
    var body: some View {
        // A standard Form, like the Settings screen it's reached from (HIG →
        // Settings / Lists). Replaces hand-padded GroupBoxes in a ScrollView.
        Form {
            backupSection
            restoreSection
            helpSection
        }
        .navigationTitle("Backup & Restore")
        .alert(
            Text(viewModel.currentAlert?.title ?? ""),
            isPresented: isShowingAlert,
            presenting: viewModel.currentAlert
        ) { _ in
            Button("OK") { }
        } message: { alertType in
            Text(alertType.message)
        }
        .sheet(isPresented: $viewModel.showImportPicker) {
            importPickerSheet
        }
        .alert("Confirm Restore", isPresented: $viewModel.showConfirmRestore) {
            confirmRestoreAlert
        } message: {
            Text("Are you sure you want to restore from backup? This will replace all current data in the app.")
        }
    }
    
    private var isShowingAlert: Binding<Bool> {
        Binding(
            get: { viewModel.currentAlert != nil },
            set: { if !$0 { viewModel.currentAlert = nil } }
        )
    }

    // MARK: - View Components

    private var backupSection: some View {
        Section {
            if viewModel.isCreatingBackup {
                ProgressView(value: viewModel.backupProgress, total: 1.0)
            }

            Button("Create Backup File", systemImage: "doc.badge.plus") {
                viewModel.createBackup()
            }
            .disabled(viewModel.isCreatingBackup)

            // Shown once a backup file exists. `ShareLink` presents the share
            // sheet from this view's own window and anchors itself.
            if let url = viewModel.backupFileURL, !viewModel.isCreatingBackup {
                ShareLink(item: url) {
                    Label("Share Backup File", systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text("Create Backup")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Create a complete backup of your journal data that you can save to Files, send via email, or store in cloud storage.")
                if let url = viewModel.backupFileURL, !viewModel.isCreatingBackup {
                    Text("Ready: \(url.lastPathComponent)")
                }
            }
        }
    }

    private var restoreSection: some View {
        Section {
            if viewModel.isRestoringBackup {
                ProgressView(value: viewModel.restoreProgress, total: 1.0)
            }

            Button("Select Backup File", systemImage: "square.and.arrow.down") {
                viewModel.selectBackupFile()
            }
            .disabled(viewModel.isRestoringBackup)
        } header: {
            Text("Restore From Backup")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Restore your journal data from a previously created backup file.")
                Label {
                    Text("Restoring replaces all current data in the app. Back up anything you want to keep first.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(AppTheme.partial)
            }
        }
    }

    private var helpSection: some View {
        Section("Help") {
            helpItem("Create a backup before changing phones or updating the app")
            helpItem("Store your backup files in a safe place like cloud storage")
            helpItem("Backup files include all your habits, journal entries, and settings")
            helpItem("After restoring, restart the app to ensure all data is loaded properly")
        }
    }

    private func helpItem(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
    }
    
    // MARK: - Sheets
    
    private var importPickerSheet: some View {
        BackupDocumentPickerView(delegate: viewModel.documentPickerDelegate) { url in
            viewModel.processSelectedBackup(url: url)
        }
    }
    
    private var confirmRestoreAlert: some View {
        Group {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                viewModel.restoreFromBackup()
            }
        }
    }
}

// MARK: - UIKit Bridge

struct BackupDocumentPickerView: UIViewControllerRepresentable {
    let delegate: BackupPickerDelegate
    let onPick: (URL) -> Void
    
    init(delegate: BackupPickerDelegate, onPick: @escaping (URL) -> Void) {
        self.delegate = delegate
        self.onPick = onPick
        delegate.onDocumentsPicked = onPick
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.allowsMultipleSelection = false
        picker.delegate = delegate
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
