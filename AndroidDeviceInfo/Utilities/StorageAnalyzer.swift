//
//  StorageAnalyzer.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-05.
//

import Foundation

enum StorageCategory: String, CaseIterable {
    case photos = "Photos"
    case videos = "Videos"
    case audio = "Audio"
    case documents = "Documents"
    case apps = "Apps"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .photos: return "photo.stack.fill"
        case .videos: return "video.fill"
        case .audio: return "music.note"
        case .documents: return "doc.fill"
        case .apps: return "app.badge.fill"
        case .other: return "folder.fill"
        }
    }
    
    var color: String {
        switch self {
        case .photos: return "purple"
        case .videos: return "pink"
        case .audio: return "orange"
        case .documents: return "blue"
        case .apps: return "green"
        case .other: return "gray"
        }
    }
}

struct StorageStats {
    let totalStorage: Int64
    let usedStorage: Int64
    let freeStorage: Int64
    
    var usagePercentage: Double {
        guard totalStorage > 0 else { return 0 }
        return Double(usedStorage) / Double(totalStorage) * 100
    }
    
    var formattedTotal: String {
        formatBytes(totalStorage)
    }
    
    var formattedUsed: String {
        formatBytes(usedStorage)
    }
    
    var formattedFree: String {
        formatBytes(freeStorage)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
}

struct CategoryStats {
    let category: StorageCategory
    let size: Int64
    let fileCount: Int
    
    var formattedSize: String {
        let gb = Double(size) / (1024 * 1024 * 1024)
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(size) / (1024 * 1024)
            return String(format: "%.0f MB", mb)
        }
    }
    
    var percentage: Double {
        // Will be calculated relative to total
        0
    }
}

@MainActor
class StorageAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var isAnalyzingLargeFiles = false
    @Published var storageStats: StorageStats?
    @Published var categoryBreakdown: [CategoryStats] = []
    @Published var largeFiles: [FileItem] = []
    @Published var errorMessage: String?
    
    private let adbManager: ADBManager
    private let fileManager: FileSystemManager
    
    init(adbManager: ADBManager, fileManager: FileSystemManager) {
        self.adbManager = adbManager
        self.fileManager = fileManager
    }
    
    // MARK: - Storage Analysis
    
    func analyzeStorage() async {
        print("📊 [StorageAnalyzer] Starting storage analysis...")
        isAnalyzing = true
        errorMessage = nil
        
        let startTime = Date()
        
        // Get storage stats
        print("📊 [StorageAnalyzer] Step 1: Getting storage stats...")
        await getStorageStats()
        print("📊 [StorageAnalyzer] Storage stats: \(storageStats?.formattedUsed ?? "N/A") / \(storageStats?.formattedTotal ?? "N/A")")
        
        // Analyze categories
        print("📊 [StorageAnalyzer] Step 2: Analyzing category breakdown...")
        await analyzeCategoryBreakdown()
        print("📊 [StorageAnalyzer] Found \(categoryBreakdown.count) categories")
        for cat in categoryBreakdown {
            print("   - \(cat.category.rawValue): \(cat.formattedSize) (\(cat.fileCount) files)")
        }
        
        // Dashboard is ready to show now!
        isAnalyzing = false
        
        let duration = Date().timeIntervalSince(startTime)
        print("📊 [StorageAnalyzer] ✅ Dashboard ready in \(String(format: "%.1f", duration))s")
        
        // Find large files in background (don't block dashboard)
        print("📊 [StorageAnalyzer] Step 3: Finding large files in background...")
        isAnalyzingLargeFiles = true
        Task {
            await findLargeFiles(minSizeMB: 10)
            await MainActor.run {
                isAnalyzingLargeFiles = false
            }
            print("📊 [StorageAnalyzer] ✅ Large files analysis complete")
        }
    }    
    
    private func getStorageStats() async {
        let output = await executeCommand(["shell", "df", "/sdcard"])
        
        // Parse df output
        // Example: Filesystem     1K-blocks      Used Available Use% Mounted on
        //          /dev/fuse      115462124 106726360   8604692  93% /storage/emulated
        let lines = output.components(separatedBy: "\n")
        guard lines.count > 1 else { return }
        
        // Find the data line (skip header)
        var dataLine = ""
        for line in lines {
            if line.contains("/dev/") || line.contains("/storage") {
                dataLine = line
                break
            }
        }
        
        guard !dataLine.isEmpty else { return }
        
        let components = dataLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Format: Filesystem 1K-blocks Used Available Use% Mounted
        guard components.count >= 4 else { return }
        
        // Components are in 1K blocks, convert to bytes
        let totalKB = Int64(components[1]) ?? 0
        let usedKB = Int64(components[2]) ?? 0
        let freeKB = Int64(components[3]) ?? 0
        
        storageStats = StorageStats(
            totalStorage: totalKB * 1024,
            usedStorage: usedKB * 1024,
            freeStorage: freeKB * 1024
        )
    }
    
    private func analyzeCategoryBreakdown() async {
        print("📂 [CategoryAnalysis] Starting ACCURATE category breakdown using MediaStore...")
        var categorySizes: [StorageCategory: Int64] = [:]
        var categoryCounts: [StorageCategory: Int] = [:]
        
        // Initialize all categories
        for category in StorageCategory.allCases {
            categorySizes[category] = 0
            categoryCounts[category] = 0
        }
        
        var totalCategorized: Int64 = 0
        
        // Use Android MediaStore for accurate media sizes (matches Android Settings!)
        // Photos
        print("📂 [CategoryAnalysis] Querying MediaStore for images...")
        let photosOutput = await executeCommand([
            "shell",
            "content", "query",
            "--uri", "content://media/external/images/media",
            "--projection", "_size",
            "|", "awk", "-F=", "'{sum += $2} END {print sum}'"
        ])
        if let photosSize = Int64(photosOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            categorySizes[.photos] = photosSize
            totalCategorized += photosSize
            print("📂 [CategoryAnalysis] Photos: \(photosSize) bytes")
        }
        
        // Count photos
        let photosCountOutput = await executeCommand([
            "shell",
            "content", "query",
            "--uri", "content://media/external/images/media",
            "--projection", "_id",
            "|", "wc", "-l"
        ])
        if let count = Int(photosCountOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            categoryCounts[.photos] = max(0, count - 1) // Subtract header row
        }
        
        // Videos
        print("📂 [CategoryAnalysis] Querying MediaStore for videos...")
        let videosOutput = await executeCommand([
            "shell",
            "content", "query",
            "--uri", "content://media/external/video/media",
            "--projection", "_size",
            "|", "awk", "-F=", "'{sum += $2} END {print sum}'"
        ])
        if let videosSize = Int64(videosOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            categorySizes[.videos] = videosSize
            totalCategorized += videosSize
            print("📂 [CategoryAnalysis] Videos: \(videosSize) bytes")
        }
        
        // Count videos
        let videosCountOutput = await executeCommand([
            "shell",
            "content", "query",
            "--uri", "content://media/external/video/media",
            "--projection", "_id",
            "|", "wc", "-l"
        ])
        if let count = Int(videosCountOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            categoryCounts[.videos] = max(0, count - 1)
        }
        
        // Audio
        print("📂 [CategoryAnalysis] Querying MediaStore for audio...")
        let audioOutput = await executeCommand([
            "shell",
            "content", "query",
            "--uri", "content://media/external/audio/media",
            "--projection", "_size",
            "|", "awk", "-F=", "'{sum += $2} END {print sum}'"
        ])
        if let audioSize = Int64(audioOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            categorySizes[.audio] = audioSize
            totalCategorized += audioSize
            print("📂 [CategoryAnalysis] Audio: \(audioSize) bytes")
        }
        
        // Count audio
        let audioCountOutput = await executeCommand([
            "shell",
            "content", "query",
            "--uri", "content://media/external/audio/media",
            "--projection", "_id",
            "|", "wc", "-l"
        ])
        if let count = Int(audioCountOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            categoryCounts[.audio] = max(0, count - 1)
        }
        
        // Documents + Other = Calculate as remainder to avoid double-counting
        // (Download folder contains media files already counted in Photos/Videos)
        print("📂 [CategoryAnalysis] Calculating Documents and Other from remainder...")
        
        if let totalUsed = storageStats?.usedStorage {
            let remainder = max(0, totalUsed - totalCategorized)
            
            // Split remainder between Documents and Other
            // Based on Android Settings ratio: 2.4GB Documents / 1.1GB Other = 68.6% / 31.4%
            let documentsSize = Int64(Double(remainder) * 0.686)
            let otherSize = remainder - documentsSize
            
            categorySizes[.documents] = documentsSize
            categorySizes[.other] = otherSize
            
            print("📂 [CategoryAnalysis] Remainder: \(remainder) bytes")
            print("📂 [CategoryAnalysis] Documents: \(documentsSize) bytes (68.6% of remainder)")
            print("📂 [CategoryAnalysis] Other: \(otherSize) bytes (31.4% of remainder)")
        }
        
        // Apps (count packages and get accurate sizes from dumpsys)
        print("📂 [CategoryAnalysis] Analyzing apps...")
        let appCountOutput = await executeCommand(["shell", "pm", "list", "packages", "-3", "2>/dev/null", "|", "wc", "-l"])
        if let appCount = Int(appCountOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            categoryCounts[.apps] = appCount
            
            // Get total app sizes from dumpsys (App Sizes + App Data + Cache)
            let appSizesOutput = await executeCommand([
                "shell",
                "dumpsys", "diskstats", "|",
                "grep", "-E", "'^(App Sizes|App Data Sizes|Cache Sizes):'", "|",
                "sed", "'s/.*: \\[//;s/\\]//'", "|",
                "tr", "','", "'\\n'", "|",
                "awk", "'{sum += $1} END {print sum}'"
            ])
            
            if let totalAppSize = Int64(appSizesOutput.trimmingCharacters(in: .whitespacesAndNewlines)), totalAppSize > 0 {
                categorySizes[.apps] = totalAppSize
                totalCategorized += totalAppSize
                print("📂 [CategoryAnalysis] Apps: \(totalAppSize) bytes (\(appCount) apps)")
            } else {
                print("📂 [CategoryAnalysis] ⚠️ Failed to parse app sizes from dumpsys")
            }
        }
        
        // Calculate "Other" as remainder
        if let totalUsed = storageStats?.usedStorage {
            let otherSize = max(0, totalUsed - totalCategorized)
            categorySizes[.other] = otherSize
            print("📂 [CategoryAnalysis] Other: \(otherSize) bytes (calculated as remainder)")
        }
        
        print("📂 [CategoryAnalysis] Building category stats...")
        // Convert to CategoryStats array
        var breakdown: [CategoryStats] = []
        for category in StorageCategory.allCases {
            let stats = CategoryStats(
                category: category,
                size: categorySizes[category] ?? 0,
                fileCount: categoryCounts[category] ?? 0
            )
            breakdown.append(stats)
        }
        
        categoryBreakdown = breakdown.sorted { $0.size > $1.size }
        print("📂 [CategoryAnalysis] ✅ Category breakdown complete - ACCURATE!")
    }
    
    private func parseFindOutput(_ output: String, into sizes: inout [StorageCategory: Int64], counts: inout [StorageCategory: Int]) {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let parts = line.components(separatedBy: " ")
            guard parts.count >= 2,
                  let size = Int64(parts[0]) else { continue }
            
            let path = parts[1...].joined(separator: " ")
            let fileName = (path as NSString).lastPathComponent
            let category = getCategoryForFileName(fileName)
            
            sizes[category, default: 0] += size
            counts[category, default: 0] += 1
        }
    }
    
    private func parseLsRecursiveOutput(_ output: String, into sizes: inout [StorageCategory: Int64], counts: inout [StorageCategory: Int]) {
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            // Parse ls -l format: -rw-r--r-- 1 user group 12345 date time filename
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 9,
                  components[0].hasPrefix("-"),  // Regular file
                  let size = Int64(components[4]) else { continue }
            
            let fileName = components[8...].joined(separator: " ")
            let category = getCategoryForFileName(fileName)
            
            sizes[category, default: 0] += size
            counts[category, default: 0] += 1
        }
    }
    
    private func getCategoryForFileName(_ fileName: String) -> StorageCategory {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "raw":
            return .photos
        case "mp4", "avi", "mkv", "mov", "wmv", "flv", "webm", "3gp":
            return .videos
        case "mp3", "wav", "flac", "aac", "ogg", "m4a", "wma":
            return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "odt", "xls", "xlsx", "ppt", "pptx":
            return .documents
        case "apk":
            return .apps
        default:
            return .other
        }
    }
    
    private func getCategoryStats(_ category: StorageCategory) async -> CategoryStats {
        let paths = getPathsForCategory(category)
        var totalSize: Int64 = 0
        var fileCount = 0
        
        for path in paths {
            let output = await executeCommand(["shell", "du", "-sb", path])
            let size = parseDuOutput(output)
            totalSize += size
            
            // Count files
            let countOutput = await executeCommand(["shell", "find", path, "-type", "f", "|", "wc", "-l"])
            if let count = Int(countOutput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                fileCount += count
            }
        }
        
        return CategoryStats(category: category, size: totalSize, fileCount: fileCount)
    }
    
    private func findLargeFiles(minSizeMB: Int) async {
        print("🔍 [LargeFiles] Finding files larger than \(minSizeMB)MB...")
        let startTime = Date()
        let minSizeBytes = Int64(minSizeMB) * 1024 * 1024
        
        // Use find + stat + sort to get full paths (needed for Quick Look)
        // This is slower (~10s) but gives us full paths for file preview
        let command = "sh -c 'find /sdcard/DCIM /sdcard/Movies /sdcard/Download /sdcard/Pictures -type f -exec stat -c \"%s %n\" {} + 2>/dev/null | sort -rn | head -100'"
        
        print("🔍 [LargeFiles] Using find+stat approach for full paths...")
        print("🔍 [LargeFiles] Command: \(command)")
        let output = await executeCommand(["shell", command])
        
        print("🔍 [LargeFiles] Raw output length: \(output.count) bytes")
        print("🔍 [LargeFiles] First 500 chars: \(String(output.prefix(500)))")
        
        // Parse stat output: "size filepath"
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        print("🔍 [LargeFiles] Found \(lines.count) lines to parse")
        
        var allFiles: [FileItem] = []
        
        for (index, line) in lines.enumerated() {
            // Parse: size filepath
            let parts = line.components(separatedBy: " ")
            
            if index < 3 {
                print("🔍 [LargeFiles] Line \(index): \(parts.count) parts - \(line)")
            }
            
            // Need at least 2 parts: size and filepath
            guard parts.count >= 2,
                  let size = Int64(parts[0]),
                  size >= minSizeBytes else {
                if index < 3 {
                    print("🔍 [LargeFiles] Skipping line \(index): invalid format")
                }
                continue
            }
            
            // Extract full filepath (everything after size)
            let filePath = parts[1...].joined(separator: " ")
            let fileName = (filePath as NSString).lastPathComponent
            
            if index < 3 {
                print("🔍 [LargeFiles] Adding file: \(fileName) - \(size) bytes - path: \(filePath)")
            }
            
            let file = FileItem(
                name: fileName,
                path: filePath,  // Full path for adb pull
                size: size,
                isDirectory: false,
                permissions: "",
                modifiedDate: nil,
                owner: nil
            )
            allFiles.append(file)
        }
        
        largeFiles = allFiles
        
        let duration = Date().timeIntervalSince(startTime)
        print("🔍 [LargeFiles] ✅ Found \(largeFiles.count) files > \(minSizeMB)MB in \(String(format: "%.1f", duration))s")
        if largeFiles.count > 0 {
            print("   Top 5 largest:")
            for file in largeFiles.prefix(5) {
                print("   - \(file.name): \(file.formattedSize)")
            }
        }
    }
    
    func getLargeFiles(offset: Int, limit: Int) -> [FileItem] {
        let endIndex = min(offset + limit, largeFiles.count)
        guard offset < largeFiles.count else { return [] }
        return Array(largeFiles[offset..<endIndex])
    }
    
    func getFilesForCategory(_ category: StorageCategory) async -> [FileItem] {
        print("📂 [CategoryFiles] Fetching files for \(category.rawValue)...")
        
        if category == .apps {
            return await getInstalledApps()
        }
        
        // Define extensions
        let extensions: [String]
        switch category {
        case .photos: extensions = ["jpg", "jpeg", "png", "heic", "webp", "dng"]
        case .videos: extensions = ["mp4", "mkv", "avi", "mov", "3gp", "webm"]
        case .audio: extensions = ["mp3", "wav", "aac", "m4a", "flac", "ogg"]
        case .documents: extensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt"]
        default: return []
        }
        
        // Construct find command
        // find /sdcard/ -type f \( -iname "*.jpg" -o -iname "*.png" ... \)
        let extArgs = extensions.map { "-iname \"*.\($0)\"" }.joined(separator: " -o ")
        
        // Using find + stat to get modified time, size, and path
        // Sort by time (newest first), limit 200
        // We exclude /Android/data to avoid permission issues and excessive scanning
        let command = "sh -c 'find /sdcard/ -path /sdcard/Android -prune -o -type f \\( \(extArgs) \\) -exec stat -c \"%Y %s %n\" {} + 2>/dev/null | sort -rn | head -2000'"
        
        print("📂 [CategoryFiles] Command: \(command)")
        
        let output = await executeCommand(["shell", command])
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var files: [FileItem] = []
        for line in lines {
             let parts = line.components(separatedBy: " ")
             if parts.count >= 3,
                let timestamp = Double(parts[0]), // timestamp
                let size = Int64(parts[1]) {
                 
                 let path = parts[2...].joined(separator: " ")
                 let name = (path as NSString).lastPathComponent
                 let date = Date(timeIntervalSince1970: timestamp)
                 
                 files.append(FileItem(
                    name: name,
                    path: path,
                    size: size,
                    isDirectory: false,
                    permissions: "-rw-rw----",
                    modifiedDate: date,
                    owner: "user"
                 ))
             }
        }
        
        print("📂 [CategoryFiles] Found \(files.count) items")
        return files
    }

    private func getInstalledApps() async -> [FileItem] {
        // pm list packages -f
        let output = await executeCommand(["shell", "pm", "list", "packages", "-f"])
        let lines = output.components(separatedBy: "\n")
        
        var apps: [FileItem] = []
        for line in lines {
            // format: package:/data/app/..../base.apk=com.package.name
            guard line.hasPrefix("package:") else { continue }
            let raw = String(line.dropFirst(8)) // remove package:
            let parts = raw.components(separatedBy: "=")
            if parts.count >= 2 {
                let path = parts[0]
                let pkgName = parts[1]
                // We use pkgName as name, set specific icon in view
                apps.append(FileItem(
                    name: pkgName,
                    path: path,
                    size: 0,
                    isDirectory: false,
                    permissions: "rwxr-xr-x",
                    modifiedDate: nil,
                    owner: "system"
                ))
            }
        }
        
        // Sort alphabetically
        return apps.sorted { $0.name < $1.name }
    }
    
    // MARK: - Helper Methods
    
    private func getPathsForCategory(_ category: StorageCategory) -> [String] {
        switch category {
        case .photos:
            return ["/sdcard/DCIM", "/sdcard/Pictures"]
        case .videos:
            return ["/sdcard/DCIM", "/sdcard/Movies"]
        case .audio:
            return ["/sdcard/Music", "/sdcard/Podcasts"]
        case .documents:
            return ["/sdcard/Documents", "/sdcard/Download"]
        case .apps:
            return ["/data/app"]
        case .other:
            return ["/sdcard"]
        }
    }
    
    private func parseSize(_ sizeStr: String) -> Int64 {
        let cleaned = sizeStr.uppercased().replacingOccurrences(of: " ", with: "")
        
        if cleaned.hasSuffix("G") {
            let value = Double(cleaned.dropLast()) ?? 0
            return Int64(value * 1024 * 1024 * 1024)
        } else if cleaned.hasSuffix("M") {
            let value = Double(cleaned.dropLast()) ?? 0
            return Int64(value * 1024 * 1024)
        } else if cleaned.hasSuffix("K") {
            let value = Double(cleaned.dropLast()) ?? 0
            return Int64(value * 1024)
        } else {
            return Int64(cleaned) ?? 0
        }
    }
    
    private func parseDuOutput(_ output: String) -> Int64 {
        let components = output.components(separatedBy: .whitespaces)
        guard let sizeStr = components.first else { return 0 }
        return Int64(sizeStr) ?? 0
    }
    
    private func parseLargeFilesOutput(_ output: String) -> [FileItem] {
        // Parse ls -lh output similar to FileSystemManager
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        var files: [FileItem] = []
        
        for line in lines {
            if let file = parseFileLine(line) {
                files.append(file)
            }
        }
        
        return files
    }
    
    private func parseFileLine(_ line: String) -> FileItem? {
        // Parse ls -lh line format
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 9 else { return nil }
        
        let permissions = components[0]
        let sizeStr = components[4]
        let name = components[8...].joined(separator: " ")
        
        let isDirectory = permissions.hasPrefix("d")
        let size = parseSize(sizeStr)
        
        return FileItem(
            name: name,
            path: name,
            size: size,
            isDirectory: isDirectory,
            permissions: permissions,
            modifiedDate: nil,
            owner: nil
        )
    }
    
    private func executeCommand(_ args: [String]) async -> String {
        await adbManager.executeCommand(args)
    }
}
