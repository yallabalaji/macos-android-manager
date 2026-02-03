//
//  FileBrowserView.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-03.
//

import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var fileManager: FileSystemManager
    @State private var selectedFiles = Set<FileItem.ID>()
    @State private var showingNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var clipboardItem: FileItem? // For copy/paste
    @State private var clipboardOperation: ClipboardOperation = .none
    @State private var sortOption: SortOption = .name
    @State private var sortAscending: Bool = true
    
    enum ClipboardOperation {
        case none
        case copy
        case cut
    }
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case date = "Date"
        case type = "Type"
    }
    
    var sortedFiles: [FileItem] {
        let files = fileManager.files
        return files.sorted(by: { (file1: FileItem, file2: FileItem) -> Bool in
            // Always keep parent directory (..) at top
            if file1.name == ".." { return true }
            if file2.name == ".." { return false }
            
            // Directories first, then files
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory
            }
            
            // Sort by selected option
            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = file1.name.localizedCaseInsensitiveCompare(file2.name) == .orderedAscending
            case .size:
                comparison = file1.size < file2.size
            case .date:
                comparison = (file1.modifiedDate ?? Date.distantPast) < (file2.modifiedDate ?? Date.distantPast)
            case .type:
                comparison = file1.fileType.icon < file2.fileType.icon
            }
            
            return sortAscending ? comparison : !comparison
        })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with breadcrumb and actions
            HStack {
                // Breadcrumb navigation
                BreadcrumbView(currentPath: fileManager.currentPath) { path in
                    Task {
                        await fileManager.navigateToPath(path)
                    }
                }
                
                Spacer()
                
                // Action buttons
                Button(action: {
                    Task {
                        await fileManager.navigateToPath("/sdcard/")
                    }
                }) {
                    Image(systemName: "house")
                }
                .buttonStyle(.plain)
                .help("Go to Home (/sdcard/)")
                
                if clipboardItem != nil {
                    Button(action: {
                        pasteFile()
                    }) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.plain)
                    .help("Paste \(clipboardOperation == .cut ? "(Move)" : "(Copy)")")
                }
                
                Button(action: {
                    Task {
                        await fileManager.refreshCurrentDirectory()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
                
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            if sortOption == option {
                                sortAscending.toggle()
                            } else {
                                sortOption = option
                                sortAscending = true
                            }
                        }) {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .buttonStyle(.plain)
                .help("Sort by \(sortOption.rawValue)")
                
                Button(action: {
                    showingNewFolderDialog = true
                }) {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .help("New Folder")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // File list
            if fileManager.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading files...")
                    Spacer()
                }
            } else if let error = fileManager.errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List(sortedFiles, selection: $selectedFiles) { file in
                    HStack {
                        Image(systemName: file.icon)
                            .foregroundColor(file.isDirectory ? .blue : .primary)
                            .frame(width: 20)
                        
                        Text(file.name)
                            .frame(minWidth: 200, alignment: .leading)
                        
                        Spacer()
                        
                        Text(file.formattedSize)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text(file.formattedDate)
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .trailing)
                        
                        if file.isDirectory {
                            Button("→") {
                                print("DEBUG: Arrow button clicked for: \(file.name) at path: \(file.path)")
                                Task {
                                    await fileManager.navigateToPath(file.path)
                                }
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 30)
                        } else {
                            Spacer()
                                .frame(width: 30)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if file.isDirectory {
                            print("DEBUG: Double-click on folder: \(file.name) at path: \(file.path)")
                            Task {
                                await fileManager.navigateToPath(file.path)
                            }
                        } else {
                            print("DEBUG: Double-click on file: \(file.name)")
                            quickLookFile(file)
                        }
                    }
                    .contextMenu {
                        if file.isDirectory {
                            Button("Open") {
                                Task {
                                    await fileManager.navigateToPath(file.path)
                                }
                            }
                            
                            Divider()
                        } else {
                            Button("Download") {
                                downloadFile(file)
                            }
                            
                            Button("Quick Look") {
                                quickLookFile(file)
                            }
                            
                            Divider()
                        }
                        
                        Button("Copy") {
                            clipboardItem = file
                            clipboardOperation = .copy
                        }
                        
                        Button("Cut") {
                            clipboardItem = file
                            clipboardOperation = .cut
                        }
                        
                        if clipboardItem != nil {
                            Button("Paste Here") {
                                pasteFile()
                            }
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            deleteFile(file)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewFolderDialog) {
            NewFolderDialog(folderName: $newFolderName) {
                createNewFolder()
            }
        }
    }
    
    private func downloadFile(_ file: FileItem) {
        Task {
            let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let localPath = downloadsPath.appendingPathComponent(file.name).path
            
            let success = await fileManager.pullFile(remotePath: file.path, localPath: localPath)
            
            if success {
                // Show success notification
                print("Downloaded: \(file.name) to \(localPath)")
            }
        }
    }
    
    private func quickLookFile(_ file: FileItem) {
        Task {
            // Download to temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let localURL = tempDir.appendingPathComponent(file.name)
            
            let success = await fileManager.pullFile(remotePath: file.path, localPath: localURL.path)
            
            if success {
                // Open with Quick Look
                _ = await MainActor.run {
                    NSWorkspace.shared.open(localURL)
                }
            }
        }
    }
    
    private func deleteFile(_ file: FileItem) {
        Task {
            let success = await fileManager.deleteItem(path: file.path, isDirectory: file.isDirectory)
            
            if success {
                await fileManager.refreshCurrentDirectory()
            }
        }
    }
    
    private func createNewFolder() {
        guard !newFolderName.isEmpty else { return }
        
        Task {
            let newPath = fileManager.currentPath.hasSuffix("/") 
                ? "\(fileManager.currentPath)\(newFolderName)"
                : "\(fileManager.currentPath)/\(newFolderName)"
            
            let success = await fileManager.createDirectory(path: newPath)
            
            
            if success {
                await fileManager.refreshCurrentDirectory()
            }
            
            newFolderName = ""
            showingNewFolderDialog = false
        }
    }
    
    private func pasteFile() {
        guard let item = clipboardItem else { return }
        
        Task {
            let fileName = (item.path as NSString).lastPathComponent
            let destinationPath = fileManager.currentPath.hasSuffix("/")
                ? "\(fileManager.currentPath)\(fileName)"
                : "\(fileManager.currentPath)/\(fileName)"
            
            var success = false
            
            if clipboardOperation == .copy {
                // Use cp command to copy
                success = await fileManager.copyItem(sourcePath: item.path, destinationPath: destinationPath, isDirectory: item.isDirectory)
            } else if clipboardOperation == .cut {
                // Use mv command to move
                success = await fileManager.renameItem(oldPath: item.path, newPath: destinationPath)
            }
            
            if success {
                await fileManager.refreshCurrentDirectory()
                
                // Clear clipboard after cut operation
                if clipboardOperation == .cut {
                    clipboardItem = nil
                    clipboardOperation = .none
                }
            }
        }
    }
}

struct BreadcrumbView: View {
    let currentPath: String
    let onNavigate: (String) -> Void
    
    var pathComponents: [(name: String, path: String)] {
        var components: [(String, String)] = []
        var buildPath = ""
        
        let parts = currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
        
        components.append(("Root", "/"))
        
        for part in parts {
            buildPath += "/\(part)"
            components.append((part, buildPath))
        }
        
        return components
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                Button(action: {
                    onNavigate(component.path)
                }) {
                    Text(component.name)
                        .foregroundColor(index == pathComponents.count - 1 ? .primary : .blue)
                }
                .buttonStyle(.plain)
                
                if index < pathComponents.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct NewFolderDialog: View {
    @Binding var folderName: String
    let onCreate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("New Folder")
                .font(.headline)
            
            TextField("Folder name", text: $folderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Create") {
                    onCreate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(folderName.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}
