//
//  FileItem.swift
//  AndroidDeviceInfo
//
//  Created on 2026-02-03.
//

import Foundation

enum FileType {
    case folder
    case image
    case video
    case audio
    case document
    case apk
    case archive
    case other
    
    var icon: String {
        switch self {
        case .folder: return "folder.fill"
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .audio: return "music.note"
        case .document: return "doc.fill"
        case .apk: return "app.badge"
        case .archive: return "doc.zipper"
        case .other: return "doc"
        }
    }
    
    var color: String {
        switch self {
        case .folder: return "blue"
        case .image: return "purple"
        case .video: return "pink"
        case .audio: return "orange"
        case .document: return "blue"
        case .apk: return "green"
        case .archive: return "yellow"
        case .other: return "gray"
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let permissions: String
    let modifiedDate: Date?
    let owner: String?
    
    var fileType: FileType {
        if isDirectory {
            return .folder
        }
        
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "heic":
            return .image
        case "mp4", "avi", "mkv", "mov", "wmv", "flv", "webm":
            return .video
        case "mp3", "wav", "flac", "aac", "ogg", "m4a":
            return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "odt":
            return .document
        case "apk":
            return .apk
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return .archive
        default:
            return .other
        }
    }
    
    var icon: String {
        fileType.icon
    }
    
    var formattedSize: String {
        if isDirectory {
            return "--"
        }
        
        let bytes = Double(size)
        if bytes < 1024 {
            return "\(size) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
        }
    }
    
    var formattedDate: String {
        guard let date = modifiedDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // For parent directory navigation
    static func parentDirectory(path: String) -> FileItem {
        FileItem(
            name: "..",
            path: (path as NSString).deletingLastPathComponent,
            size: 0,
            isDirectory: true,
            permissions: "drwxr-xr-x",
            modifiedDate: nil,
            owner: nil
        )
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}
