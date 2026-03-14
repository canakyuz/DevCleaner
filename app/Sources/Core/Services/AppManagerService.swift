import Foundation
import AppKit

actor AppManagerService {
    private let fileManager = FileManager.default
    private let scanner = DiskScanner()

    func scanInstalledApps() async -> [AppInfo] {
        let appsDir = "/Applications"
        guard let contents = try? fileManager.contentsOfDirectory(atPath: appsDir) else { return [] }

        var apps: [AppInfo] = []

        for item in contents where item.hasSuffix(".app") {
            let appPath = (appsDir as NSString).appendingPathComponent(item)
            let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")

            guard let plist = NSDictionary(contentsOfFile: infoPlistPath) else { continue }

            let name = (plist["CFBundleName"] as? String)
                ?? (plist["CFBundleDisplayName"] as? String)
                ?? item.replacingOccurrences(of: ".app", with: "")
            let bundleId = (plist["CFBundleIdentifier"] as? String) ?? ""
            let version = (plist["CFBundleShortVersionString"] as? String) ?? ""

            // App icon
            let icon = NSWorkspace.shared.icon(forFile: appPath)
            icon.size = NSSize(width: 32, height: 32)

            var info = AppInfo(
                name: name,
                bundleId: bundleId,
                path: appPath,
                icon: icon,
                version: version
            )

            // Calculate sizes
            info.bundleSize = await scanner.directorySize(at: appPath)
            info.cacheSize = await calculatePathsSize(info.cachePaths)
            info.dataSize = await calculatePathsSize(info.dataPaths)

            if info.totalSize > 0 {
                apps.append(info)
            }
        }

        return apps.sorted { $0.totalSize > $1.totalSize }
    }

    func cleanAppCache(_ app: AppInfo) throws {
        for path in app.cachePaths {
            if fileManager.fileExists(atPath: path) {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                for item in contents {
                    let fullPath = (path as NSString).appendingPathComponent(item)
                    try fileManager.removeItem(atPath: fullPath)
                }
            }
        }
    }

    func uninstallApp(_ app: AppInfo) throws {
        // Move app to Trash (safer than rm)
        let appURL = URL(fileURLWithPath: app.path)
        try fileManager.trashItem(at: appURL, resultingItemURL: nil)

        // Clean related data
        let allPaths = app.cachePaths + app.dataPaths + app.preferencePaths
        for path in allPaths {
            if fileManager.fileExists(atPath: path) {
                try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            }
        }
    }

    func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    private func calculatePathsSize(_ paths: [String]) async -> Int64 {
        var total: Int64 = 0
        for path in paths {
            total += await scanner.directorySize(at: path)
        }
        return total
    }
}

