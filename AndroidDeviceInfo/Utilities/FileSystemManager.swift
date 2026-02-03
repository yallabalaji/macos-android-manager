//
//  FileSystemManager.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-03.
//

import Foundation

class FileSystemManager: ObservableObject {
    @Published var currentPath: String = "/sdcard/"
    @Published var files: [FileItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var allowSystemAccess: Bool = false // User preference for system-level access
    
    private let adbPath: String
    private let adbManager: ADBManager
    
    init(adbManager: ADBManager) {
        self.adbManager = adbManager
        
        // Try to find ADB in common locations
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
        ]
        
        self.adbPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "adb"
    }
    
    // MARK: - Directory Listing
    
    func listDirectory(_ path: String? = nil) async {
        let targetPath = path ?? currentPath
        
        print("DEBUG FileSystemManager: listDirectory called with path: \(targetPath)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Check if path is restricted and user hasn't enabled system access
        if !allowSystemAccess && isSystemPath(targetPath) {
            print("DEBUG FileSystemManager: System path blocked: \(targetPath)")
            await MainActor.run {
                errorMessage = "System directories are restricted. Enable system access in settings to browse this folder."
                isLoading = false
            }
            return
        }
        
        let output = await executeCommand(["shell", "ls", "-la", targetPath])
        print("DEBUG FileSystemManager: ADB output length: \(output.count) characters")
        let parsedFiles = parseDirectoryListing(output, basePath: targetPath)
        print("DEBUG FileSystemManager: Parsed \(parsedFiles.count) files")
        
        await MainActor.run {
            self.currentPath = targetPath
            self.files = parsedFiles
            self.isLoading = false
            print("DEBUG FileSystemManager: Updated currentPath to: \(self.currentPath)")
        }
    }
    
    // MARK: - File Operations
    
    func pullFile(remotePath: String, localPath: String) async -> Bool {
        let output = await executeCommand(["pull", remotePath, localPath])
        return output.contains("1 file pulled") || output.contains("pulled")
    }
    
    func pushFile(localPath: String, remotePath: String) async -> Bool {
        let output = await executeCommand(["push", localPath, remotePath])
        return output.contains("1 file pushed") || output.contains("pushed")
    }
    
    func createDirectory(path: String) async -> Bool {
        let output = await executeCommand(["shell", "mkdir", "-p", path])
        return !output.contains("error") && !output.contains("failed")
    }
    
    func deleteItem(path: String, isDirectory: Bool) async -> Bool {
        let args = isDirectory ? ["shell", "rm", "-rf", path] : ["shell", "rm", path]
        let output = await executeCommand(args)
        return !output.contains("error") && !output.contains("failed")
    }
    
    func renameItem(oldPath: String, newPath: String) async -> Bool {
        let output = await executeCommand(["shell", "mv", oldPath, newPath])
        return !output.contains("error") && !output.contains("failed")
    }
    
    func copyItem(sourcePath: String, destinationPath: String, isDirectory: Bool) async -> Bool {
        let args = isDirectory 
            ? ["shell", "cp", "-r", sourcePath, destinationPath]
            : ["shell", "cp", sourcePath, destinationPath]
        let output = await executeCommand(args)
        return !output.contains("error") && !output.contains("failed")
    }
    
    // MARK: - Helper Methods
    
    private func isSystemPath(_ path: String) -> Bool {
        let systemPaths = ["/system", "/data/data", "/data/system", "/proc", "/dev", "/sys"]
        return systemPaths.contains { path.hasPrefix($0) }
    }
    
    private func parseDirectoryListing(_ output: String, basePath: String) -> [FileItem] {
        var items: [FileItem] = []
        
        // Add parent directory if not at root
        if basePath != "/" && basePath != "/sdcard" {
            items.append(FileItem.parentDirectory(path: basePath))
        }
        
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            // Skip empty lines and total line
            if line.isEmpty || line.hasPrefix("total") {
                continue
            }
            
            // Parse ls -la output format:
            // -rw-rw---- 1 root sdcard_rw 1234567 2024-01-15 10:30 photo.jpg
            // drwxrwx--- 2 root sdcard_rw    4096 2024-01-15 09:00 DCIM
            
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            guard components.count >= 8 else { continue }
            
            let permissions = components[0]
            let owner = components[2]
            let sizeStr = components[4]
            let dateStr = components[5]
            let timeStr = components[6]
            let name = components[7...].joined(separator: " ")
            
            // Skip . and .. entries
            if name == "." || name == ".." {
                continue
            }
            
            let isDirectory = permissions.hasPrefix("d")
            let size = Int64(sizeStr) ?? 0
            
            // Parse date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let modifiedDate = dateFormatter.date(from: "\(dateStr) \(timeStr)")
            
            let fullPath = basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"
            
            let item = FileItem(
                name: name,
                path: fullPath,
                size: size,
                isDirectory: isDirectory,
                permissions: permissions,
                modifiedDate: modifiedDate,
                owner: owner
            )
            
            items.append(item)
        }
        
        // Sort: directories first, then by name
        return items.sorted { item1, item2 in
            if item1.name == ".." {
                return true
            }
            if item2.name == ".." {
                return false
            }
            if item1.isDirectory != item2.isDirectory {
                return item1.isDirectory
            }
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
    }
    
    private func executeCommand(_ arguments: [String]) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: adbPath)
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: "Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Navigation Helpers
    
    func navigateToParent() async {
        let parentPath = (currentPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty {
            await listDirectory(parentPath)
        }
    }
    
    func navigateToPath(_ path: String) async {
        print("DEBUG FileSystemManager: navigateToPath called with: \(path)")
        await listDirectory(path)
    }
    
    func refreshCurrentDirectory() async {
        await listDirectory(currentPath)
    }
}
