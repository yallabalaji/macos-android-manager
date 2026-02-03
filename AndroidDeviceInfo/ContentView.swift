//
//  ContentView.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-03.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var adbManager = ADBManager()
    
    var body: some View {
        ContentViewMain(adbManager: adbManager)
            .onAppear {
                adbManager.refreshDeviceInfo()
            }
    }
}

struct ContentViewMain: View {
    @ObservedObject var adbManager: ADBManager
    @StateObject private var fileManager: FileSystemManager
    
    init(adbManager: ADBManager) {
        self.adbManager = adbManager
        _fileManager = StateObject(wrappedValue: FileSystemManager(adbManager: adbManager))
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with device info
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "iphone.gen3")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    Text("Device")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        adbManager.refreshDeviceInfo()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // Connection Status
                HStack(spacing: 8) {
                    Circle()
                        .fill(adbManager.deviceInfo.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(adbManager.deviceInfo.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if adbManager.deviceInfo.isConnected {
                    // Device Details
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Model", value: adbManager.deviceInfo.model, compact: true)
                        InfoRow(label: "Manufacturer", value: adbManager.deviceInfo.manufacturer, compact: true)
                        InfoRow(label: "Android", value: adbManager.deviceInfo.androidVersion, compact: true)
                    }
                    
                    Divider()
                    
                    // Storage Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Storage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geometry.size.width * (adbManager.deviceInfo.storageUsedPercentage / 100),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text("\(String(format: "%.0f", adbManager.deviceInfo.storageUsedPercentage))% used")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", adbManager.deviceInfo.availableStorageGB)) GB free")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Settings
                    Toggle("System Access", isOn: $fileManager.allowSystemAccess)
                        .font(.caption)
                        .help("Allow browsing system directories like /system/")
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 220, idealWidth: 250)
        } detail: {
            // Main content area - File Browser
            if adbManager.deviceInfo.isConnected {
                FileBrowserView(fileManager: fileManager)
                    .onAppear {
                        Task {
                            await fileManager.listDirectory()
                        }
                    }
            } else {
                NoDeviceView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var compact: Bool = false
    
    var body: some View {
        if compact {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        } else {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
        }
    }
}

struct NoDeviceView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Device Detected")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Make sure:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Android device is connected via USB")
                    Text("• USB debugging is enabled")
                    Text("• Device is authorized on this computer")
                    Text("• ADB is installed on your Mac")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
            )
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
