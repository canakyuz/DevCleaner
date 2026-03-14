import Foundation
import AppKit
import Darwin

// MARK: - Memory Info

struct MemoryInfo {
    let total: UInt64
    let used: UInt64
    let free: UInt64
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64
    let compressed: UInt64
    let appMemory: UInt64

    var usedPercent: Double {
        total > 0 ? Double(used) / Double(total) * 100 : 0
    }

    var pressure: MemoryPressure {
        let pct = usedPercent
        if pct > 90 { return .critical }
        if pct > 75 { return .warning }
        return .nominal
    }

    static let zero = MemoryInfo(
        total: 0, used: 0, free: 0,
        active: 0, inactive: 0, wired: 0,
        compressed: 0, appMemory: 0
    )
}

enum MemoryPressure: String {
    case nominal = "Normal"
    case warning = "Yuksek"
    case critical = "Kritik"
}

// MARK: - Disk Info (extended)

struct DiskSpaceInfo {
    let totalBytes: Int64
    let freeBytes: Int64
    let purgableBytes: Int64

    var usedBytes: Int64 { totalBytes - freeBytes }
    var usedPercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
    }

    static let zero = DiskSpaceInfo(totalBytes: 0, freeBytes: 0, purgableBytes: 0)
}

// MARK: - Large File

struct LargeFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let sizeBytes: Int64
    let modifiedDate: Date
    let fileType: FileType
    var isSelected: Bool = false

    var directoryPath: String {
        (path as NSString).deletingLastPathComponent
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: LargeFile, rhs: LargeFile) -> Bool {
        lhs.path == rhs.path
    }
}

enum FileType: String {
    case video = "Video"
    case image = "Gorsel"
    case archive = "Arsiv"
    case diskImage = "Disk Image"
    case binary = "Binary"
    case document = "Belge"
    case other = "Diger"

    var icon: String {
        switch self {
        case .video:      return "film"
        case .image:      return "photo"
        case .archive:    return "doc.zipper"
        case .diskImage:  return "externaldrive"
        case .binary:     return "terminal"
        case .document:   return "doc"
        case .other:      return "doc.questionmark"
        }
    }

    static func from(extension ext: String) -> FileType {
        switch ext.lowercased() {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return .video
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "svg", "psd", "raw":
            return .image
        case "zip", "tar", "gz", "rar", "7z", "bz2", "xz", "tgz":
            return .archive
        case "dmg", "iso", "img", "sparseimage", "sparsebundle":
            return .diskImage
        case "app", "pkg", "deb", "o", "dylib", "framework":
            return .binary
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key":
            return .document
        default:
            return .other
        }
    }
}

// MARK: - App Info

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let path: String
    let icon: NSImage?
    let version: String
    var bundleSize: Int64 = 0
    var cacheSize: Int64 = 0
    var dataSize: Int64 = 0
    var totalSize: Int64 { bundleSize + cacheSize + dataSize }
    var isSelected: Bool = false

    var cachePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths: [String] = []

        // Library/Caches
        let cacheDirs = [
            "\(home)/Library/Caches/\(bundleId)",
            "\(home)/Library/Caches/\(name)",
        ]
        paths.append(contentsOf: cacheDirs)

        return paths.filter { FileManager.default.fileExists(atPath: $0) }
    }

    var dataPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths: [String] = []

        let dataDirs = [
            "\(home)/Library/Application Support/\(bundleId)",
            "\(home)/Library/Application Support/\(name)",
            "\(home)/Library/Containers/\(bundleId)",
            "\(home)/Library/Group Containers/group.\(bundleId)",
        ]
        paths.append(contentsOf: dataDirs)

        return paths.filter { FileManager.default.fileExists(atPath: $0) }
    }

    var preferencePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Preferences/\(bundleId).plist",
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }
}

// MARK: - Module Enum

enum AppModule: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case smartClean = "Akilli Temizlik"
    case largeFiles = "Buyuk Dosyalar"
    case appManager = "Uygulamalar"
    case ram = "RAM"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:  return "gauge.with.dots.needle.50percent"
        case .smartClean: return "paintbrush.fill"
        case .largeFiles: return "chart.bar.doc.horizontal"
        case .appManager: return "square.grid.2x2"
        case .ram:        return "memorychip"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:  return "Sistem Ozeti"
        case .smartClean: return "Cache & Dev Temizligi"
        case .largeFiles: return "Buyuk Dosya Bulucu"
        case .appManager: return "Uygulama Yonetici"
        case .ram:        return "Bellek Optimizasyonu"
        }
    }
}
