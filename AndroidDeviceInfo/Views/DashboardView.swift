//
//  DashboardView.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-05.
//

import SwiftUI
import QuickLook

struct DashboardView: View {
    @ObservedObject var storageAnalyzer: StorageAnalyzer
    @State private var showingLargeFiles = false
    @State private var isStreaming = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if storageAnalyzer.isAnalyzing {
                        ProgressView("Analyzing storage...")
                            .padding()
                        .padding()
                } else {
                    // Storage Overview Card
                    storageOverviewCard
                    
                    // Category Breakdown
                    categoryBreakdownSection
                    
                    // Large Files Preview
                    largeFilesPreview
                    
                    // Quick Actions
                    quickActionsSection
                }
            }
            .padding()
        }
        .navigationTitle("Storage Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await storageAnalyzer.analyzeStorage()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Analysis")
            }
        }
        .onAppear {
            if storageAnalyzer.storageStats == nil {
                Task {
                    await storageAnalyzer.analyzeStorage()
                }
            }
        }
        .sheet(isPresented: $showingLargeFiles) {
            LargeFilesView(storageAnalyzer: storageAnalyzer)
        }
    }
    }
    
    // MARK: - Storage Overview Card
    
    private var storageOverviewCard: some View {
        VStack(spacing: 16) {
            if let stats = storageAnalyzer.storageStats {
                HStack(spacing: 40) {
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: stats.usagePercentage / 100)
                            .stroke(
                                stats.usagePercentage > 80 ? Color.red :
                                stats.usagePercentage > 60 ? Color.orange : Color.blue,
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: stats.usagePercentage)
                        
                        VStack(spacing: 4) {
                            Text("\(Int(stats.usagePercentage))%")
                                .font(.system(size: 36, weight: .bold))
                            Text("Used")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storage Overview")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Label("Total", systemImage: "internaldrive")
                            Spacer()
                            Text(stats.formattedTotal)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Label("Used", systemImage: "chart.pie.fill")
                            Spacer()
                            Text(stats.formattedUsed)
                                .fontWeight(.medium)
                                .foregroundColor(stats.usagePercentage > 80 ? .red : .primary)
                        }
                        
                        HStack {
                            Label("Free", systemImage: "checkmark.circle.fill")
                            Spacer()
                            Text(stats.formattedFree)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: 300)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Category Breakdown
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage by Category")
                .font(.title3)
                .fontWeight(.semibold)
            
            if storageAnalyzer.categoryBreakdown.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(storageAnalyzer.categoryBreakdown, id: \.category) { stat in
                    NavigationLink(destination: CategoryDetailView(category: stat.category, storageAnalyzer: storageAnalyzer)) {
                        CategoryRow(stat: stat, totalUsed: storageAnalyzer.storageStats?.usedStorage ?? 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Large Files Preview
    
    private var largeFilesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Largest Files")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if storageAnalyzer.isAnalyzingLargeFiles {
                    ProgressView()
                        .scaleEffect(0.7)
                        .help("Scanning for large files...")
                } else {
                    Button("View All (\(storageAnalyzer.largeFiles.count))") {
                        showingLargeFiles = true
                    }
                }
            }
            
            if storageAnalyzer.isAnalyzingLargeFiles {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Scanning for large files...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            } else if storageAnalyzer.largeFiles.isEmpty {
                Text("No large files found")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(storageAnalyzer.largeFiles.prefix(5)) { file in
                    LargeFileRow(file: file)
                        .contentShape(Rectangle())
                        .opacity(isStreaming ? 0.5 : 1.0) // Visual feedback
                        .allowsHitTesting(!isStreaming)   // Prevent double-clicks
                        .onTapGesture {
                            if file.name.hasSuffix(".mp4") || file.name.hasSuffix(".mkv") || file.name.hasSuffix(".avi") {
                                streamVideo(file)
                            } else {
                                // For non-video files, show not supported or open full view
                                showingLargeFiles = true
                            }
                        }
                        .onHover { isHovering in
                            if isHovering && !isStreaming {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func streamVideo(_ file: FileItem) {
        if isStreaming { return }
        isStreaming = true
        
        print("🎬 [Stream] Starting stream for: \(file.name)")
        
        Task {
            // Find adb path
            let possiblePaths = [
                "/usr/local/bin/adb",
                "/opt/homebrew/bin/adb",
                "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
            ]
            let adbPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "adb"
            
            await Task.detached(priority: .userInitiated) {
                // Create temp file for the video
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
                    
                    // Open in VLC or QuickTime
                    let vlcPath = "/Applications/VLC.app"
                    let hasVLC = FileManager.default.fileExists(atPath: vlcPath)
                    
                    if hasVLC {
                        let vlcCLI = "/Applications/VLC.app/Contents/MacOS/VLC"
                        let playProcess = Process()
                        playProcess.executableURL = URL(fileURLWithPath: vlcCLI)
                        playProcess.arguments = ["--file-caching=5000", tempFile.path]
                        
                        try playProcess.run()
                        print("🎬 [Stream] VLC launched!")
                        
                        // Wait for VLC to close (User finished watching)
                        playProcess.waitUntilExit()
                        print("🎬 [Stream] VLC closed by user.")
                        
                    } else {
                        // For QuickTime fallback
                        await MainActor.run {
                            _ = NSWorkspace.shared.open(tempFile)
                        }
                    }
                    
                    // Terminate download if it's still running
                    if downloadProcess.isRunning {
                        print("🎬 [Stream] Terminating background download...")
                        downloadProcess.terminate()
                    }
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempFile)
                    print("🎬 [Stream] Cleanup complete.")
                    
                } catch {
                    print("❌ [Stream] Error: \(error)")
                }
            }.value
            
            // Re-enable UI
            isStreaming = false
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                ActionButton(
                    title: "Clean Storage",
                    icon: "trash.fill",
                    color: .red
                ) {
                    // TODO: Implement cleanup
                }
                
                ActionButton(
                    title: "Full Backup",
                    icon: "arrow.down.doc.fill",
                    color: .blue
                ) {
                    // TODO: Implement backup
                }
                
                ActionButton(
                    title: "View Large Files",
                    icon: "doc.text.magnifyingglass",
                    color: .orange
                ) {
                    showingLargeFiles = true
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct CategoryRow: View {
    let stat: CategoryStats
    let totalUsed: Int64
    
    var percentage: Double {
        guard totalUsed > 0 else { return 0 }
        return Double(stat.size) / Double(totalUsed) * 100
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: stat.category.icon)
                    .foregroundColor(colorForCategory(stat.category))
                    .frame(width: 24)
                
                Text(stat.category.rawValue)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(stat.formattedSize)
                        .fontWeight(.semibold)
                    Text("\(stat.fileCount) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(colorForCategory(stat.category))
                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
    
    private func colorForCategory(_ category: StorageCategory) -> Color {
        switch category {
        case .photos: return .purple
        case .videos: return .pink
        case .audio: return .orange
        case .documents: return .blue
        case .apps: return .green
        case .other: return .gray
        }
    }
}

struct LargeFileRow: View {
    let file: FileItem
    
    var body: some View {
        HStack {
            Image(systemName: file.icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                Text(file.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    let category: StorageCategory
    @ObservedObject var storageAnalyzer: StorageAnalyzer
    @Environment(\.dismiss) var dismiss
    
    @State private var files: [FileItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    // Preview & Streaming State
    @State private var quickLookURL: URL?
    @State private var isPullingFile = false
    @State private var isStreaming = false
    @State private var pullProgress: String = ""
    
    var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return files
        } else {
            return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading \(category.rawValue)...")
                    .scaleEffect(1.2)
            } else if files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No \(category.rawValue) found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(filteredFiles) { file in
                        CategoryFileRow(file: file, category: category)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleTap(file)
                            }
                            .contextMenu {
                                if category == .videos {
                                    Button("Stream Video") { streamVideo(file) }
                                }
                                if category != .apps {
                                    Button("Preview") { previewFile(file) }
                                }
                                Button("Copy Path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(file.path, forType: .string)
                                }
                            }
                    }
                }
                .searchable(text: $searchText, prompt: "Search \(category.rawValue)")
            }
            
            if isPullingFile {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(pullProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle(category.rawValue)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadFiles()
        }
        .quickLookPreview($quickLookURL)
    }
    
    private func loadFiles() {
        isLoading = true
        Task {
            let items = await storageAnalyzer.getFilesForCategory(category)
            await MainActor.run {
                self.files = items
                self.isLoading = false
            }
        }
    }
    
    private func handleTap(_ file: FileItem) {
        if category == .apps { return } // Cannot preview apps yet
        if category == .videos {
            streamVideo(file)
        } else {
            previewFile(file)
        }
    }
    
    private func previewFile(_ file: FileItem) {
        guard !isPullingFile else { return }
        
        // Find adb path check
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
        ]
        let adbPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "adb"
        
        isPullingFile = true
        pullProgress = "Preparing preview..."
        
        Task {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AndroidPreview")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempFile = tempDir.appendingPathComponent(file.name)
            
            // Background download
            let success = await Task.detached(priority: .userInitiated) { () -> Bool in
                // If already exists and size matches? (Assume re-download for fresh)
                try? FileManager.default.removeItem(at: tempFile)
                
                let downloadProcess = Process()
                downloadProcess.executableURL = URL(fileURLWithPath: adbPath)
                downloadProcess.arguments = ["pull", file.path, tempFile.path]
                
                do {
                    try downloadProcess.run()
                    downloadProcess.waitUntilExit()
                    return downloadProcess.terminationStatus == 0
                } catch {
                    return false
                }
            }.value
            
            if success {
                self.quickLookURL = tempFile
            } else {
                print("❌ Preview failed")
            }
            
            self.isPullingFile = false
            self.pullProgress = ""
        }
    }
    
    private func streamVideo(_ file: FileItem) {
        if isStreaming { return }
        isStreaming = true
        
        Task {
            // Find adb path
            let possiblePaths = [
                "/usr/local/bin/adb",
                "/opt/homebrew/bin/adb",
                "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
            ]
            let adbPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "adb"
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AndroidStream")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempFile = tempDir.appendingPathComponent(file.name)
            
            // Run detached to avoid blocking MainActor
            await Task.detached(priority: .userInitiated) {
                try? FileManager.default.removeItem(at: tempFile)
                
                let downloadProcess = Process()
                downloadProcess.executableURL = URL(fileURLWithPath: adbPath)
                downloadProcess.arguments = ["pull", file.path, tempFile.path]
                
                do {
                    try downloadProcess.run()
                    
                    // Buffer
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    
                    let vlcPath = "/Applications/VLC.app"
                    let hasVLC = FileManager.default.fileExists(atPath: vlcPath)
                    
                    if hasVLC {
                        let vlcCLI = "/Applications/VLC.app/Contents/MacOS/VLC"
                        let playProcess = Process()
                        playProcess.executableURL = URL(fileURLWithPath: vlcCLI)
                        playProcess.arguments = ["--file-caching=5000", tempFile.path]
                        
                        try playProcess.run()
                        playProcess.waitUntilExit() // Blocks this detached task, which is fine
                    } else {
                        // For QuickTime/Preview, we just open it
                        // Since NSWorkspace needs Main Thread usually? 
                        // open() is async usually but let's be careful.
                        // We can't easily wait for QuickTime exit via openURL.
                        await MainActor.run {
                            _ = NSWorkspace.shared.open(tempFile)
                        }
                    }
                    
                    if downloadProcess.isRunning {
                        downloadProcess.terminate()
                    }
                    
                    try? FileManager.default.removeItem(at: tempFile)
                    
                } catch {
                    print("❌ [Stream] Error: \(error)")
                }
            }.value
            
            self.isStreaming = false
        }
    }
}

struct CategoryFileRow: View {
    let file: FileItem
    let category: StorageCategory
    
    var iconName: String {
        switch category {
        case .apps: return "app.badge.fill"
        case .photos: return "photo"
        case .videos: return "video"
        case .audio: return "music.note"
        case .documents: return "doc.text"
        default: return "doc"
        }
    }
    
    var color: Color {
        switch category {
        case .apps: return .green
        case .photos: return .purple
        case .videos: return .pink
        case .audio: return .orange
        case .documents: return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                
                if category == .apps {
                    Text(file.path) // APK Path
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Copy path button
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy Path")
        }
        .padding(.vertical, 4)
    }
}
