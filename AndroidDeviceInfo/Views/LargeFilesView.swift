//
//  LargeFilesView.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-05.
//

import SwiftUI
import QuickLook

struct LargeFilesView: View {
    @ObservedObject var storageAnalyzer: StorageAnalyzer
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFiles = Set<UUID>()
    @State private var currentPage = 0
    @State private var showingDeleteConfirmation = false
    @State private var quickLookURL: URL?
    @State private var isPullingFile = false
    @State private var pullProgress: String = ""
    @State private var showingLargeFileWarning = false
    @State private var pendingPreviewFile: FileItem?
    @State private var showVLCRecommendation = false
    @State private var hasCheckedVLC = false
    @State private var isStreaming = false
    
    let filesPerPage = 100
    
    var totalPages: Int {
        (storageAnalyzer.largeFiles.count + filesPerPage - 1) / filesPerPage
    }
    
    var currentFiles: [FileItem] {
        storageAnalyzer.getLargeFiles(offset: currentPage * filesPerPage, limit: filesPerPage)
    }
    
    var selectedSize: Int64 {
        storageAnalyzer.largeFiles
            .filter { selectedFiles.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Large Files Explorer")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isPullingFile {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(pullProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Stats Bar
            HStack {
                Text("\(storageAnalyzer.largeFiles.count) files found")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !selectedFiles.isEmpty {
                    Text("\(selectedFiles.count) selected • \(formatBytes(selectedSize))")
                        .fontWeight(.medium)
                    
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // VLC Recommendation Banner (subtle, dismissible)
            if showVLCRecommendation {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("💡 Tip: Install VLC for better video streaming support (handles more formats)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Install VLC") {
                        NSWorkspace.shared.open(URL(string: "https://www.videolan.org/vlc/")!)
                        showVLCRecommendation = false
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    
                    Button(action: {
                        showVLCRecommendation = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
            }
            
            Divider()
            
            // File List
            List(currentFiles, selection: $selectedFiles) { file in
                LargeFileDetailRow(file: file)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        // Double-click to preview
                        previewFile(file)
                    }
                    .contextMenu {
                        let isVideo = file.name.hasSuffix(".mp4") || file.name.hasSuffix(".mkv") || file.name.hasSuffix(".avi")
                        
                        if isVideo {
                            Button(action: {
                                streamVideo(file)
                            }) {
                                Label("Stream Video", systemImage: "play.circle")
                            }
                        }
                        
                        Button(action: {
                            previewFile(file)
                        }) {
                            Label("Quick Look Preview", systemImage: "eye")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            // TODO: Copy path
                        }) {
                            Label("Copy Path", systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive, action: {
                            // TODO: Delete file
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            
            // Pagination
            if totalPages > 1 {
                Divider()
                
                HStack {
                    Button(action: {
                        currentPage = max(0, currentPage - 1)
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage == 0)
                    
                    Spacer()
                    
                    Text("Page \(currentPage + 1) of \(totalPages)")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        currentPage = min(totalPages - 1, currentPage + 1)
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= totalPages - 1)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .quickLookPreview($quickLookURL)
        .alert("Delete Selected Files?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedFiles()
            }
        } message: {
            Text("This will delete \(selectedFiles.count) files (\(formatBytes(selectedSize))). This action cannot be undone.")
        }
        .alert("Large File Warning", isPresented: $showingLargeFileWarning) {
            Button("Cancel", role: .cancel) {
                pendingPreviewFile = nil
            }
            
            if let file = pendingPreviewFile, file.name.hasSuffix(".mp4") || file.name.hasSuffix(".mkv") || file.name.hasSuffix(".avi") {
                Button("Stream Video") {
                    if let file = pendingPreviewFile {
                        streamVideo(file)
                    }
                }
            }
            
            Button("Download & Preview") {
                if let file = pendingPreviewFile {
                    pullAndPreviewFile(file)
                }
            }
        } message: {
            if let file = pendingPreviewFile {
                let sizeMB = Double(file.size) / (1024 * 1024)
                let estimatedTime = Int(sizeMB / 50) // ~50 MB/s over USB
                
                let isVideo = file.name.hasSuffix(".mp4") || file.name.hasSuffix(".mkv") || file.name.hasSuffix(".avi")
                
                if isVideo {
                    Text("This file is \(file.formattedSize). Downloading will take approximately \(estimatedTime) seconds.\n\n💡 Tip: Use 'Stream Video' for instant playback without downloading!")
                } else {
                    Text("This file is \(file.formattedSize). Downloading will take approximately \(estimatedTime) seconds.")
                }
            }
        }
        .onAppear {
            // Check VLC installation once and show recommendation if not installed
            if !hasCheckedVLC {
                hasCheckedVLC = true
                let vlcPath = "/Applications/VLC.app"
                if !FileManager.default.fileExists(atPath: vlcPath) {
                    showVLCRecommendation = true
                }
            }
        }
    }
    
    private func previewFile(_ file: FileItem) {
        print("👁️ [Preview] Starting preview for: \(file.name)")
        print("👁️ [Preview] File path: \(file.path)")
        print("👁️ [Preview] File size: \(file.formattedSize)")
        
        // Warn for large files (>100MB)
        let sizeMB = Double(file.size) / (1024 * 1024)
        if sizeMB > 100 {
            pendingPreviewFile = file
            showingLargeFileWarning = true
            return
        }
        
        pullAndPreviewFile(file)
    }
    
    private func pullAndPreviewFile(_ file: FileItem) {
        Task {
            await MainActor.run {
                isPullingFile = true
                pullProgress = "Pulling \(file.name)..."
            }
            
            print("👁️ [Preview] Creating temp directory...")
            // Create temp directory
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AndroidPreview")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            print("👁️ [Preview] Temp dir: \(tempDir.path)")
            
            // Pull file from device
            let localURL = tempDir.appendingPathComponent(file.name)
            print("👁️ [Preview] Local URL: \(localURL.path)")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("👁️ [Preview] Removing existing file...")
                try? FileManager.default.removeItem(at: localURL)
            }
            
            // Use adb pull
            print("👁️ [Preview] Starting adb pull...")
            
            // Find adb path (same logic as ADBManager)
            let possiblePaths = [
                "/usr/local/bin/adb",
                "/opt/homebrew/bin/adb",
                "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
            ]
            let adbPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "adb"
            print("👁️ [Preview] Using adb at: \(adbPath)")
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: adbPath)
            process.arguments = ["pull", file.path, localURL.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                print("👁️ [Preview] Process started, waiting...")
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                print("👁️ [Preview] Process exit code: \(process.terminationStatus)")
                print("👁️ [Preview] Output: \(output)")
                
                if process.terminationStatus == 0 {
                    print("👁️ [Preview] File pulled successfully!")
                    print("👁️ [Preview] File exists: \(FileManager.default.fileExists(atPath: localURL.path))")
                    
                    if FileManager.default.fileExists(atPath: localURL.path) {
                        let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path)
                        print("👁️ [Preview] Local file size: \(attrs?[.size] ?? 0)")
                    }
                    
                    await MainActor.run {
                        print("👁️ [Preview] Setting quickLookURL to: \(localURL)")
                        quickLookURL = localURL
                        isPullingFile = false
                        pullProgress = ""
                    }
                } else {
                    print("❌ [Preview] Pull failed with exit code: \(process.terminationStatus)")
                    await MainActor.run {
                        isPullingFile = false
                        pullProgress = ""
                    }
                }
            } catch {
                print("❌ [Preview] Error: \(error)")
                await MainActor.run {
                    isPullingFile = false
                    pullProgress = ""
                }
            }
        }
    }
    
    private func streamVideo(_ file: FileItem) {
        if isStreaming { return }
        isStreaming = true
        
        print("🎬 [Stream] Starting stream for: \(file.name)")
        print("🎬 [Stream] File path: \(file.path)")
        
        Task {
            // Find adb path
            let possiblePaths = [
                "/usr/local/bin/adb",
                "/opt/homebrew/bin/adb",
                "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
            ]
            let adbPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "adb"
            
            print("🎬 [Stream] Using adb at: \(adbPath)")
            
            // Create temp file for the video
            // We use a real file so VLC can seek/scrub!
            // This acts like a cache - streaming the download while you watch.
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AndroidStream")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let tempFile = tempDir.appendingPathComponent(file.name)
            
            // Remove existing file if present
            try? FileManager.default.removeItem(at: tempFile)
            
            print("🎬 [Stream] Buffering to: \(tempFile.path)")
            
            // Start downloading in background
            let downloadProcess = Process()
            downloadProcess.executableURL = URL(fileURLWithPath: adbPath)
            downloadProcess.arguments = ["pull", file.path, tempFile.path]
            
            do {
                try downloadProcess.run()
                
                // Wait 5 seconds for initial buffer (increased for stability)
                print("🎬 [Stream] Buffering (5s)...")
                try await Task.sleep(nanoseconds: 5_000_000_000)
                
                print("🎬 [Stream] Opening in VLC...")
                
                // Open in VLC while download continues in background
                let vlcPath = "/Applications/VLC.app"
                let hasVLC = FileManager.default.fileExists(atPath: vlcPath)
                
                if hasVLC {
                    let vlcCLI = "/Applications/VLC.app/Contents/MacOS/VLC"
                    let playProcess = Process()
                    playProcess.executableURL = URL(fileURLWithPath: vlcCLI)
                    playProcess.arguments = ["--file-caching=5000", tempFile.path]
                    
                    try playProcess.run()
                    print("🎬 [Stream] VLC launched!")
                    
                    // Wait for VLC to close
                    playProcess.waitUntilExit()
                    print("🎬 [Stream] VLC closed by user.")
                    
                } else {
                    NSWorkspace.shared.open(tempFile)
                }
                
                // Terminate download if it's still running
                if downloadProcess.isRunning {
                    print("🎬 [Stream] Terminating background download...")
                    downloadProcess.terminate()
                }
                
                // Cleanup
                try? FileManager.default.removeItem(at: tempFile)
                print("🎬 [Stream] Cleanup complete.")
                
                await MainActor.run {
                    isStreaming = false
                }
                
            } catch {
                print("❌ [Stream] Error: \(error)")
                await MainActor.run {
                    isStreaming = false
                }
            }
        }
    }
    
    private func deleteSelectedFiles() {
        // TODO: Implement batch delete
        selectedFiles.removeAll()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / (1024 * 1024)
            return String(format: "%.0f MB", mb)
        }
    }
}

struct LargeFileDetailRow: View {
    let file: FileItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.icon)
                .foregroundColor(file.isDirectory ? .blue : .orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .fontWeight(.medium)
                
                Text(file.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(file.formattedSize)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                if let date = file.modifiedDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
