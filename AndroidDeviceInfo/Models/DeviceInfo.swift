//
//  DeviceInfo.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-03.
//

import Foundation

struct DeviceInfo {
    var isConnected: Bool
    var model: String
    var manufacturer: String
    var androidVersion: String
    var totalStorageGB: Double
    var availableStorageGB: Double
    
    var usedStorageGB: Double {
        totalStorageGB - availableStorageGB
    }
    
    var storageUsedPercentage: Double {
        guard totalStorageGB > 0 else { return 0 }
        return (usedStorageGB / totalStorageGB) * 100
    }
    
    static var disconnected: DeviceInfo {
        DeviceInfo(
            isConnected: false,
            model: "N/A",
            manufacturer: "N/A",
            androidVersion: "N/A",
            totalStorageGB: 0,
            availableStorageGB: 0
        )
    }
}
