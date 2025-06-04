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
        
        let hasSecureAccess = url.startAccessingSecurityScopedResource()
        
        #if DEBUG
        print("Started accessing security scoped resource: \(hasSecureAccess)")
        #endif
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localCopy = documentsDirectory.appendingPathComponent("backup_temp.json")
        
        do {
            if FileManager.default.fileExists(atPath: localCopy.path) {
                try FileManager.default.removeItem(at: localCopy)
            }
            
            try FileManager.default.copyItem(at: url, to: localCopy)
            
            #if DEBUG
            print("Successfully copied file to documents directory")
            #endif
            
            onDocumentsPicked?(localCopy)
        } catch {
            #if DEBUG
            print("Error copying file: \(error.localizedDescription)")
            #endif
            onDocumentsPicked?(url)
        }
        
        if hasSecureAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

// MARK: - View Model

class BackupRestoreViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isCreatingBackup = false
    @Published var isRestoringBackup = false
    @Published var backupProgress: Float = 0
    @Published var restoreProgress: Float = 0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showAlert = false
    @Published var showImportPicker = false
    @Published var showConfirmRestore = false
    @Published var selectedBackupURL: URL?
    @Published var documentPickerDelegate = BackupPickerDelegate()
    
    // MARK: - Public Methods
    
    /// Creates a backup and presents share sheet
    func createBackup(from viewController: UIViewController, sourceView: UIView) {
        isCreatingBackup = true
        backupProgress = 0
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let progressObserver = self?.setupBackupProgressObserver()
            
            if let backupURL = BackupManager.shared.createBackup() {
                self?.handleBackupSuccess(
                    with: backupURL,
                    from: viewController,
                    sourceView: sourceView,
                    progressObserver: progressObserver
                )
            } else {
                self?.handleBackupError(progressObserver: progressObserver)
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
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let progressObserver = self?.setupRestoreProgressObserver()
            
            let success = BackupManager.shared.restoreFromURL(backupURL)
            
            self?.handleRestoreCompletion(
                success: success,
                progressObserver: progressObserver
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBackupProgressObserver() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .backupProgressUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let progress = notification.userInfo?["progress"] as? Float {
                self?.backupProgress = progress
            }
        }
    }
    
    private func setupRestoreProgressObserver() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .restoreProgressUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let progress = notification.userInfo?["progress"] as? Float {
                self?.restoreProgress = progress
            }
        }
    }
    
    private func handleBackupSuccess(
        with url: URL,
        from viewController: UIViewController,
        sourceView: UIView,
        progressObserver: NSObjectProtocol?
    ) {
        DispatchQueue.main.async { [weak self] in
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = sourceView
                popoverController.sourceRect = sourceView.bounds
            }
            
            self?.isCreatingBackup = false
            self?.backupProgress = 1.0
            
            if let observer = progressObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            
            viewController.present(activityVC, animated: true)
        }
    }
    
    private func handleBackupError(progressObserver: NSObjectProtocol?) {
        DispatchQueue.main.async { [weak self] in
            self?.isCreatingBackup = false
            self?.errorMessage = BackupManager.shared.errorMessage ?? "Failed to create backup"
            self?.showAlert = true
            
            if let observer = progressObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    private func handleRestoreCompletion(
        success: Bool,
        progressObserver: NSObjectProtocol?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isRestoringBackup = false
            self?.restoreProgress = 1.0
            
            if let observer = progressObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            
            if success {
                self?.successMessage = "Backup restored successfully! Restart the app to see your data."
            } else {
                self?.errorMessage = BackupManager.shared.errorMessage ?? "Failed to restore from backup"
            }
            
            self?.showAlert = true
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
        .alert(isPresented: $viewModel.showAlert) {
            alertContent
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
    
    // MARK: - Alerts and Sheets
    
    private var alertContent: Alert {
        if viewModel.errorMessage != nil {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        } else {
            Alert(
                title: Text("Success"),
                message: Text(viewModel.successMessage ?? "Operation completed successfully"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
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
