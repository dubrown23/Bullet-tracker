//
//  BackupRestoreView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/15/25.
//

import SwiftUI
import UniformTypeIdentifiers

// Document picker delegate to handle file imports
class BackupPickerDelegate: NSObject, ObservableObject, UIDocumentPickerDelegate {
    var onDocumentsPicked: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Start accessing the security-scoped resource
        let hasSecureAccess = url.startAccessingSecurityScopedResource()
        print("Started accessing security scoped resource: \(hasSecureAccess)")
        
        // Create a local copy of the file in the app's documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localCopy = documentsDirectory.appendingPathComponent("backup_temp.json")
        
        do {
            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: localCopy.path) {
                try FileManager.default.removeItem(at: localCopy)
            }
            
            // Copy the file to the documents directory
            try FileManager.default.copyItem(at: url, to: localCopy)
            print("Successfully copied file to documents directory")
            
            // Use the local copy instead of the original URL
            onDocumentsPicked?(localCopy)
        } catch {
            print("Error copying file: \(error.localizedDescription)")
            // Fall back to the original URL
            onDocumentsPicked?(url)
        }
        
        // Stop accessing the security-scoped resource
        if hasSecureAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

class BackupRestoreViewModel: ObservableObject {
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
    
    // For file picking
    @Published var documentPickerDelegate = BackupPickerDelegate()
    
    // Create a backup
    func createBackup(from viewController: UIViewController, sourceView: UIView) {
        self.isCreatingBackup = true
        self.backupProgress = 0
        self.errorMessage = nil
        
        // Use a background thread for backup creation
        DispatchQueue.global(qos: .userInitiated).async {
            // Subscribe to progress updates
            let progressObserver = NotificationCenter.default.addObserver(
                forName: .backupProgressUpdated,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let progress = notification.userInfo?["progress"] as? Float {
                    self?.backupProgress = progress
                }
            }
            
            // Create the backup
            if let backupURL = BackupManager.shared.createBackup() {
                // Return to main thread
                DispatchQueue.main.async {
                    // Share the backup file
                    let activityVC = UIActivityViewController(activityItems: [backupURL], applicationActivities: nil)
                    
                    // For iPad support
                    if let popoverController = activityVC.popoverPresentationController {
                        popoverController.sourceView = sourceView
                        popoverController.sourceRect = sourceView.bounds
                    }
                    
                    self.isCreatingBackup = false
                    self.backupProgress = 1.0
                    NotificationCenter.default.removeObserver(progressObserver)
                    
                    viewController.present(activityVC, animated: true)
                }
            } else {
                // Handle error
                DispatchQueue.main.async {
                    self.isCreatingBackup = false
                    self.errorMessage = BackupManager.shared.errorMessage ?? "Failed to create backup"
                    self.showAlert = true
                    NotificationCenter.default.removeObserver(progressObserver)
                }
            }
        }
    }
    
    // Show file picker to select a backup file
    func selectBackupFile() {
        self.showImportPicker = true
    }
    
    // Process the selected backup file
    func processSelectedBackup(url: URL) {
        self.selectedBackupURL = url
        self.showConfirmRestore = true
    }
    
    // Restore from the selected backup file
    func restoreFromBackup() {
        guard let backupURL = selectedBackupURL else { return }
        
        self.isRestoringBackup = true
        self.restoreProgress = 0
        self.errorMessage = nil
        
        // Use a background thread for restore operation
        DispatchQueue.global(qos: .userInitiated).async {
            // Subscribe to progress updates
            let progressObserver = NotificationCenter.default.addObserver(
                forName: .restoreProgressUpdated,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let progress = notification.userInfo?["progress"] as? Float {
                    self?.restoreProgress = progress
                }
            }
            
            // Perform the restore
            let success = BackupManager.shared.restoreFromURL(backupURL)
            
            // Return to main thread
            DispatchQueue.main.async {
                self.isRestoringBackup = false
                self.restoreProgress = 1.0
                NotificationCenter.default.removeObserver(progressObserver)
                
                if success {
                    self.successMessage = "Backup restored successfully! Restart the app to see your data."
                } else {
                    self.errorMessage = BackupManager.shared.errorMessage ?? "Failed to restore from backup"
                }
                
                self.showAlert = true
            }
        }
    }
}

struct BackupRestoreView: View {
    @StateObject private var viewModel = BackupRestoreViewModel()
    
    // To get access to UIViewController for sharing
    @State private var actionSourceRect: CGRect = .zero
    @State private var actionSourceView: UIView? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Backup Section
                GroupBox(label: Label("Create Backup", systemImage: "arrow.up.doc.fill")
                    .font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Create a complete backup of your journal data that you can save to Files, send via email, or store in cloud storage.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isCreatingBackup {
                            ProgressView(value: viewModel.backupProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.vertical, 5)
                        }
                        
                        Button(action: {
                            if let rootVC = UIApplication.shared.windows.first?.rootViewController,
                               let sourceView = actionSourceView {
                                viewModel.createBackup(from: rootVC, sourceView: sourceView)
                            }
                        }) {
                            Label("Create Backup File", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(viewModel.isCreatingBackup)
                        .background(GeometryReader { geometry -> Color in
                            DispatchQueue.main.async {
                                actionSourceRect = geometry.frame(in: .global)
                                if actionSourceView == nil {
                                    actionSourceView = UIView(frame: actionSourceRect)
                                }
                            }
                            return Color.clear
                        })
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                
                // Restore Section
                GroupBox(label: Label("Restore From Backup", systemImage: "arrow.down.doc.fill")
                    .font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Restore your journal data from a previously created backup file. This will replace your current data.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("⚠️ Warning:")
                                .fontWeight(.bold)
                            Text("Restoring from a backup will replace all current data in the app. Make sure to back up any current data you want to keep.")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 5)
                        
                        if viewModel.isRestoringBackup {
                            ProgressView(value: viewModel.restoreProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.vertical, 5)
                        }
                        
                        Button(action: {
                            viewModel.selectBackupFile()
                        }) {
                            Label("Select Backup File", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(viewModel.isRestoringBackup)
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                
                // Help Section
                GroupBox(label: Label("Help", systemImage: "questionmark.circle.fill")
                    .font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("• Create a backup before changing phones or updating the app")
                            .font(.subheadline)
                        
                        Text("• Store your backup files in a safe place like cloud storage")
                            .font(.subheadline)
                        
                        Text("• Backup files include all your habits, journal entries, and settings")
                            .font(.subheadline)
                        
                        Text("• After restoring, restart the app to ensure all data is loaded properly")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Backup & Restore")
        .alert(isPresented: $viewModel.showAlert) {
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
        .sheet(isPresented: $viewModel.showImportPicker) {
            BackupDocumentPickerView(delegate: viewModel.documentPickerDelegate) { url in
                viewModel.processSelectedBackup(url: url)
            }
        }
        .alert("Confirm Restore", isPresented: $viewModel.showConfirmRestore) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                viewModel.restoreFromBackup()
            }
        } message: {
            Text("Are you sure you want to restore from backup? This will replace all current data in the app.")
        }
    }
}

// View to wrap UIDocumentPickerViewController for the backup view
struct BackupDocumentPickerView: UIViewControllerRepresentable {
    var delegate: BackupPickerDelegate
    var onPick: (URL) -> Void
    
    init(delegate: BackupPickerDelegate, onPick: @escaping (URL) -> Void) {
        self.delegate = delegate
        self.onPick = onPick
        
        // Set the callback
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
