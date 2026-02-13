//
//  ADBManager.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-03.
//

import Foundation

class ADBManager: ObservableObject {
    @Published var deviceInfo: DeviceInfo = .disconnected
    
    private let adbPath: String
    
    init() {
        // Try to find ADB in common locations
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
        ]
        
        self.adbPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "adb"
    }
    
    func refreshDeviceInfo() {
        Task {
            let info = await fetchDeviceInfo()
            await MainActor.run {
                self.deviceInfo = info
            }
        }
    }
    
    private func fetchDeviceInfo() async -> DeviceInfo {
        // Check if device is connected
        guard await isDeviceConnected() else {
            return .disconnected
        }
        
        async let model = getDeviceProperty("ro.product.model")
        async let manufacturer = getDeviceProperty("ro.product.manufacturer")
        async let androidVersion = getDeviceProperty("ro.build.version.release")
        async let storage = getStorageInfo()
        
        let (modelValue, manufacturerValue, versionValue, storageValue) = await (model, manufacturer, androidVersion, storage)
        
        return DeviceInfo(
            isConnected: true,
            model: modelValue,
            manufacturer: manufacturerValue,
            androidVersion: versionValue,
            totalStorageGB: storageValue.total,
            availableStorageGB: storageValue.available
        )
    }
    
    private func isDeviceConnected() async -> Bool {
        let output = await executeCommand(["devices"])
        let lines = output.components(separatedBy: "\n")
        // Check if there's at least one device listed (more than just the header line)
        return lines.filter { $0.contains("\tdevice") }.count > 0
    }
    
    private func getDeviceProperty(_ property: String) async -> String {
        let output = await executeCommand(["shell", "getprop", property])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getStorageInfo() async -> (total: Double, available: Double) {
        let output = await executeCommand(["shell", "df", "/data"])
        
        // Parse df output
        // Format: Filesystem     1K-blocks    Used Available Use% Mounted on
        let lines = output.components(separatedBy: "\n")
        guard lines.count > 1 else { return (0, 0) }
        
        let dataLine = lines[1]
        let components = dataLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 4 else { return (0, 0) }
        
        // Components: [filesystem, total, used, available, use%, mountpoint]
        let totalKB = Double(components[1]) ?? 0
        let availableKB = Double(components[3]) ?? 0
        
        // Convert KB to GB
        let totalGB = totalKB / 1_048_576  // 1024 * 1024
        let availableGB = availableKB / 1_048_576
        
        return (totalGB, availableGB)
    }
    
    func executeCommand(_ arguments: [String]) async -> String {
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
                continuation.resume(returning: "")
            }
        }
    }
}
