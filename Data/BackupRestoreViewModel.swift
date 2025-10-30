//
//  BackupRestoreView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/15/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker Delegate

class BackupPickerDelegate: NSObject, ObservableObject, UIDocumentPickerDelegate {
    var onDocumentsPicked: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Simplified: Only copy if we have secure access
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Try to access directly first
            if FileManager.default.isReadableFile(atPath: url.path) {
                onDocumentsPicked?(url)
                return
            }
        }
        
        // Fallback: Create local copy only if direct access fails
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localCopy = documentsDirectory.appendingPathComponent("backup_temp.json")
        
        do {
            try? FileManager.default.removeItem(at: localCopy)
            try FileManager.default.copyItem(at: url, to: localCopy)
            onDocumentsPicked?(localCopy)
        } catch {
            // If copy fails, try with original URL anyway
            onDocumentsPicked?(url)
        }
    }
}

// MARK: - View Model

class BackupRestoreViewModel: ObservableObject {
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
    
    @Published var isCreatingBackup = false
    @Published var isRestoringBackup = false
    @Published var backupProgress: Float = 0
    @Published var restoreProgress: Float = 0
    @Published var currentAlert: AlertType?
    @Published var showImportPicker = false
    @Published var showConfirmRestore = false
    @Published var selectedBackupURL: URL?
    @Published var documentPickerDelegate = BackupPickerDelegate()
    
    // MARK: - Private Properties for Memory Management
    
    private var backupProgressObserver: NSObjectProtocol?
    private var restoreProgressObserver: NSObjectProtocol?
    
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
    
    /// Creates a backup and presents share sheet
    func createBackup(from viewController: UIViewController, sourceView: UIView) {
        isCreatingBackup = true
        backupProgress = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupBackupProgressObserver()
            
            if let backupURL = BackupManager.shared.createBackup() {
                self?.handleBackupSuccess(
                    with: backupURL,
                    from: viewController,
                    sourceView: sourceView
                )
            } else {
                self?.handleBackupError()
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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupRestoreProgressObserver()
            
            let success = BackupManager.shared.restoreFromURL(backupURL)
            
            self?.handleRestoreCompletion(success: success)
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
            if let progress = notification.userInfo?["progress"] as? Float {
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
            if let progress = notification.userInfo?["progress"] as? Float {
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
    
    private func handleBackupSuccess(
        with url: URL,
        from viewController: UIViewController,
        sourceView: UIView
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = sourceView
                popoverController.sourceRect = sourceView.bounds
            }
            
            self.isCreatingBackup = false
            self.backupProgress = 1.0
            self.removeBackupProgressObserver()
            
            viewController.present(activityVC, animated: true)
        }
    }
    
    private func handleBackupError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isCreatingBackup = false
            self.removeBackupProgressObserver()
            
            let errorMessage = BackupManager.shared.errorMessage ?? "Failed to create backup"
            self.currentAlert = .error(errorMessage)
        }
    }
    
    private func handleRestoreCompletion(success: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isRestoringBackup = false
            self.restoreProgress = 1.0
            self.removeRestoreProgressObserver()
            
            if success {
                self.currentAlert = .success("Backup restored successfully! Restart the app to see your data.")
            } else {
                let errorMessage = BackupManager.shared.errorMessage ?? "Failed to restore from backup"
                self.currentAlert = .error(errorMessage)
            }
        }
    }
}

// MARK: - Main View

struct BackupRestoreView: View {
    // MARK: - State Properties
    
    @StateObject private var viewModel = BackupRestoreViewModel()
    @State private var actionSourceRect: CGRect = .zero
    @State private var actionSourceView: UIView? = nil
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                backupSection
                restoreSection
                helpSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Backup & Restore")
        .alert(item: $viewModel.currentAlert) { alertType in
            Alert(
                title: Text(alertType.title),
                message: Text(alertType.message),
                dismissButton: .default(Text("OK"))
            )
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
    
    // MARK: - View Components
    
    private var backupSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                backupDescription
                
                if viewModel.isCreatingBackup {
                    backupProgressView
                }
                
                createBackupButton
            }
            .padding(.vertical, 5)
        } label: {
            Label("Create Backup", systemImage: "arrow.up.doc.fill")
                .font(.headline)
        }
        .padding(.horizontal)
    }
    
    private var backupDescription: some View {
        Text("Create a complete backup of your journal data that you can save to Files, send via email, or store in cloud storage.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    
    private var backupProgressView: some View {
        ProgressView(value: viewModel.backupProgress, total: 1.0)
            .progressViewStyle(.linear)
            .padding(.vertical, 5)
    }
    
    private var createBackupButton: some View {
        Button {
            performBackup()
        } label: {
            Label("Create Backup File", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
        .disabled(viewModel.isCreatingBackup)
        .background(captureSourceView)
    }
    
    private var restoreSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                restoreDescription
                restoreWarning
                
                if viewModel.isRestoringBackup {
                    restoreProgressView
                }
                
                selectBackupButton
            }
            .padding(.vertical, 5)
        } label: {
            Label("Restore From Backup", systemImage: "arrow.down.doc.fill")
                .font(.headline)
        }
        .padding(.horizontal)
    }
    
    private var restoreDescription: some View {
        Text("Restore your journal data from a previously created backup file. This will replace your current data.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    
    private var restoreWarning: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("⚠️ Warning:")
                .fontWeight(.bold)
            Text("Restoring from a backup will replace all current data in the app. Make sure to back up any current data you want to keep.")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 5)
    }
    
    private var restoreProgressView: some View {
        ProgressView(value: viewModel.restoreProgress, total: 1.0)
            .progressViewStyle(.linear)
            .padding(.vertical, 5)
    }
    
    private var selectBackupButton: some View {
        Button {
            viewModel.selectBackupFile()
        } label: {
            Label("Select Backup File", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
        .disabled(viewModel.isRestoringBackup)
    }
    
    private var helpSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                helpItem("Create a backup before changing phones or updating the app")
                helpItem("Store your backup files in a safe place like cloud storage")
                helpItem("Backup files include all your habits, journal entries, and settings")
                helpItem("After restoring, restart the app to ensure all data is loaded properly")
            }
            .padding(.vertical, 5)
        } label: {
            Label("Help", systemImage: "questionmark.circle.fill")
                .font(.headline)
        }
        .padding(.horizontal)
    }
    
    private func helpItem(_ text: String) -> some View {
        Text("• \(text)")
            .font(.subheadline)
    }
    
    private var captureSourceView: some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                actionSourceRect = geometry.frame(in: .global)
                if actionSourceView == nil {
                    actionSourceView = UIView(frame: actionSourceRect)
                }
            }
            return Color.clear
        }
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
    
    // MARK: - Helper Methods
    
    private func performBackup() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController,
           let sourceView = actionSourceView {
            viewModel.createBackup(from: rootVC, sourceView: sourceView)
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
