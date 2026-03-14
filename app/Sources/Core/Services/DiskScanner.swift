import Foundation

actor DiskScanner {
    private let fileManager = FileManager.default
    private let minBytes: Int64 = 1_048_576 // 1MB

    struct DiskInfo {
        let totalBytes: Int64
        let freeBytes: Int64
        var usedBytes: Int64 { totalBytes - freeBytes }
        var usedPercent: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0 }
    }

    // MARK: - Disk Info

    func getDiskInfo() -> DiskInfo {
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: "/") else {
            return DiskInfo(totalBytes: 0, freeBytes: 0)
        }
        let total = (attrs[.systemSize] as? Int64) ?? 0
        let free = (attrs[.systemFreeSize] as? Int64) ?? 0
        return DiskInfo(totalBytes: total, freeBytes: free)
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

    // MARK: - Single Target Scan

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

    // MARK: - Directory Size (FileManager, fast)

    func directorySize(at path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: path) else { return 0 }

        // Try fast method first: allocated size from volume
        if let size = fastDirectorySize(url) {
            return size
        }

        // Fallback: enumerate
        return enumeratedSize(url)
    }

    private func fastDirectorySize(_ url: URL) -> Int64? {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return nil }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize else { continue }
            total += Int64(size)
        }
        return total
    }

    private func enumeratedSize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(atPath: url.path) else { return 0 }
        var total: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = url.appendingPathComponent(file).path
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
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

    func scanNodeModules(projectsDir: String, staleDays: Int = 7) -> NodeModulesResult {
        var result = NodeModulesResult(staleTargets: [], activeCount: 0, totalStaleBytes: 0)
        let projectsURL = URL(fileURLWithPath: projectsDir)

        guard fileManager.fileExists(atPath: projectsDir) else { return result }

        let nmDirs = findNodeModules(in: projectsURL, maxDepth: 5)
        let now = Date()
        let staleThreshold = now.addingTimeInterval(-Double(staleDays * 86400))

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
            } else if item != ".git" && item != ".Trash" {
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

            let size = (attrs[.size] as? Int64) ?? 0
            result.files.append(fullPath)
            result.totalBytes += size
        }

        return result
    }
}
