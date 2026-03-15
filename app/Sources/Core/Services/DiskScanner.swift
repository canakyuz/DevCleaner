import Foundation

actor DiskScanner {
    private let fileManager = FileManager.default
    private let minBytes: Int64 = 1_048_576

    struct DiskInfo {
        let totalBytes: Int64
        let freeBytes: Int64
        var usedBytes: Int64 { totalBytes - freeBytes }
        var usedPercent: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0 }
    }

    func getDiskInfo() -> DiskInfo {
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: "/") else {
            return DiskInfo(totalBytes: 0, freeBytes: 0)
        }
        let total = (attrs[.systemSize] as? Int64) ?? 0
        let free = (attrs[.systemFreeSize] as? Int64) ?? 0
        return DiskInfo(totalBytes: total, freeBytes: free)
    }

    // MARK: - Fast Directory Size (du -sk)

    func directorySize(at path: String) -> Int64 {
        guard fileManager.fileExists(atPath: path) else { return 0 }
        return duSize(path)
    }

    private func duSize(_ path: String) -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return 0
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return 0 }

        // du -sk outputs "SIZE\tPATH\n"
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard let kb = Int64(parts.first ?? "0") else { return 0 }
        return kb * 1024
    }

    // MARK: - Parallel Scan

    func scanAll(_ targets: [CleanupTarget]) async -> [CleanupTarget] {
        await withTaskGroup(of: (UUID, Int64).self) { group in
            for target in targets {
                group.addTask { [self] in
                    let size = await self.scanTarget(target)
                    return (target.id, size)
                }
            }

            var sizeMap: [UUID: Int64] = [:]
            for await (id, size) in group {
                sizeMap[id] = size
            }

            return targets.map { target in
                var t = target
                t.sizeBytes = sizeMap[target.id] ?? 0
                return t
            }
        }
    }

    private func scanTarget(_ target: CleanupTarget) -> Int64 {
        switch target.type {
        case .directory:
            return directorySize(at: target.path)
        case .glob:
            return globSize(pattern: target.path)
        case .custom:
            return 0
        }
    }

    // MARK: - Glob Size

    private func globSize(pattern: String) -> Int64 {
        let parentDir = (pattern as NSString).deletingLastPathComponent
        let prefix = (pattern as NSString).lastPathComponent

        guard let contents = try? fileManager.contentsOfDirectory(atPath: parentDir) else { return 0 }

        var total: Int64 = 0
        for item in contents where item.hasPrefix(prefix) {
            let fullPath = (parentDir as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                total += directorySize(at: fullPath)
            }
        }
        return total
    }

    // MARK: - node_modules Scan

    struct NodeModulesResult {
        var staleTargets: [(path: String, sizeBytes: Int64)]
        var activeCount: Int
        var totalStaleBytes: Int64
    }

    func scanNodeModules(staleDays: Int = 7) -> NodeModulesResult {
        var result = NodeModulesResult(staleTargets: [], activeCount: 0, totalStaleBytes: 0)
        let home = fileManager.homeDirectoryForCurrentUser.path

        let searchDirs = [
            "\(home)/Desktop/Projects",
            "\(home)/Desktop",
            "\(home)/Documents",
            "\(home)/Developer",
            "\(home)/dev",
            "\(home)/code",
            "\(home)/projects",
            "\(home)/workspace",
            "\(home)/src",
        ]

        let now = Date()
        let staleThreshold = now.addingTimeInterval(-Double(staleDays * 86400))

        for dir in searchDirs {
            guard fileManager.fileExists(atPath: dir) else { continue }
            let nmDirs = findNodeModules(in: URL(fileURLWithPath: dir), maxDepth: 4)

            for nmPath in nmDirs {
                let projectDir = (nmPath as NSString).deletingLastPathComponent
                let lastActivity = projectLastActivity(at: projectDir)

                if lastActivity < staleThreshold {
                    let size = directorySize(at: nmPath)
                    if size > minBytes {
                        result.staleTargets.append((path: nmPath, sizeBytes: size))
                        result.totalStaleBytes += size
                    }
                } else {
                    result.activeCount += 1
                }
            }
        }

        return result
    }

    private func findNodeModules(in dir: URL, maxDepth: Int, currentDepth: Int = 0) -> [String] {
        guard currentDepth < maxDepth else { return [] }
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return [] }

        var results: [String] = []
        for item in contents {
            let fullPath = dir.appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath.path, isDirectory: &isDir), isDir.boolValue else { continue }

            if item == "node_modules" {
                results.append(fullPath.path)
            } else if ![".", ".git", ".Trash", "Library", ".cache"].contains(where: { item.hasPrefix($0) }) {
                results += findNodeModules(in: fullPath, maxDepth: maxDepth, currentDepth: currentDepth + 1)
            }
        }
        return results
    }

    private func projectLastActivity(at path: String) -> Date {
        let checkFiles = ["package.json", "bun.lockb", "package-lock.json", "yarn.lock", "pnpm-lock.yaml"]
        var latest = Date.distantPast

        for file in checkFiles {
            let filePath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let modified = attrs[.modificationDate] as? Date,
               modified > latest {
                latest = modified
            }
        }

        let srcPath = (path as NSString).appendingPathComponent("src")
        if let attrs = try? fileManager.attributesOfItem(atPath: srcPath),
           let modified = attrs[.modificationDate] as? Date,
           modified > latest {
            latest = modified
        }

        return latest
    }

    // MARK: - Old Downloads

    struct DownloadsResult {
        var files: [String]
        var totalBytes: Int64
    }

    func scanOldDownloads(olderThanDays: Int = 30) -> DownloadsResult {
        let downloadsPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        guard fileManager.fileExists(atPath: downloadsPath) else {
            return DownloadsResult(files: [], totalBytes: 0)
        }

        let threshold = Date().addingTimeInterval(-Double(olderThanDays * 86400))
        var result = DownloadsResult(files: [], totalBytes: 0)

        guard let contents = try? fileManager.contentsOfDirectory(atPath: downloadsPath) else { return result }

        for item in contents {
            guard item != ".localized" && item != ".DS_Store" else { continue }
            let fullPath = (downloadsPath as NSString).appendingPathComponent(item)
            guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                  let modified = attrs[.modificationDate] as? Date,
                  modified < threshold else { continue }

            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)

            let size: Int64
            if isDir.boolValue {
                size = directorySize(at: fullPath)
            } else {
                size = (attrs[.size] as? Int64) ?? 0
            }

            result.files.append(fullPath)
            result.totalBytes += size
        }

        return result
    }

    // MARK: - Disk Map

    struct DiskMapEntry: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let sizeBytes: Int64
        let color: String
        var children: [DiskMapEntry]
    }

    func scanDiskMap() async -> [DiskMapEntry] {
        let home = fileManager.homeDirectoryForCurrentUser.path

        let dirs: [(String, String, String)] = [
            ("Library", "\(home)/Library", "blue"),
            ("Applications", "/Applications", "purple"),
            ("Documents", "\(home)/Documents", "green"),
            ("Desktop", "\(home)/Desktop", "orange"),
            ("Downloads", "\(home)/Downloads", "cyan"),
            ("Movies", "\(home)/Movies", "red"),
            ("Music", "\(home)/Music", "pink"),
            ("Pictures", "\(home)/Pictures", "yellow"),
            ("Developer", "\(home)/Developer", "indigo"),
        ]

        var entries: [DiskMapEntry] = []
        for (name, path, color) in dirs {
            guard fileManager.fileExists(atPath: path) else { continue }
            let size = directorySize(at: path)
            guard size > 10_485_760 else { continue }
            let children = scanDiskMapChildren(at: path, color: color, maxChildren: 8)
            entries.append(DiskMapEntry(name: name, path: path, sizeBytes: size, color: color, children: children))
        }

        return entries.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func scanDiskMapChildren(at path: String, color: String, maxChildren: Int) -> [DiskMapEntry] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }

        var children: [DiskMapEntry] = []
        for item in contents {
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }
            let size = directorySize(at: fullPath)
            if size > 10_485_760 {
                children.append(DiskMapEntry(name: item, path: fullPath, sizeBytes: size, color: color, children: []))
            }
        }

        return Array(children.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(maxChildren))
    }
}
