import Foundation

actor CleanupService {
    private let fileManager = FileManager.default

    struct CleanupRecord: Codable {
        let date: Date
        let freedBytes: Int64
        let items: [String]
    }

    // MARK: - Cleanup

    func cleanTarget(_ target: CleanupTarget) throws -> Int64 {
        let freed = target.sizeBytes

        switch target.type {
        case .directory:
            try removeDirectoryContents(at: target.path)
        case .glob:
            try removeGlobMatches(pattern: target.path)
        case .custom:
            break
        }

        return freed
    }

    func cleanNodeModules(paths: [String]) throws {
        for path in paths {
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(atPath: path)
            }
        }
    }

    func cleanOldDownloads(files: [String]) throws {
        for file in files {
            if fileManager.fileExists(atPath: file) {
                try fileManager.removeItem(atPath: file)
            }
        }
    }

    func dockerPrune() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker", "system", "prune", "-af", "--volumes"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    func deleteUnavailableSimulators() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "delete", "unavailable"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    // MARK: - History

    func saveRecord(_ record: CleanupRecord) {
        let logPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".devcleaner_history.json")

        var records = loadHistory()
        records.append(record)

        // Keep last 100 records
        if records.count > 100 {
            records = Array(records.suffix(100))
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(records) {
            try? data.write(to: logPath)
        }
    }

    func loadHistory() -> [CleanupRecord] {
        let logPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".devcleaner_history.json")

        guard let data = try? Data(contentsOf: logPath) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CleanupRecord].self, from: data)) ?? []
    }

    // MARK: - Private

    private func removeDirectoryContents(at path: String) throws {
        guard fileManager.fileExists(atPath: path) else { return }
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        for item in contents {
            let fullPath = (path as NSString).appendingPathComponent(item)
            try fileManager.removeItem(atPath: fullPath)
        }
    }

    private func removeGlobMatches(pattern: String) throws {
        let parentDir = (pattern as NSString).deletingLastPathComponent
        let prefix = (pattern as NSString).lastPathComponent

        guard let contents = try? fileManager.contentsOfDirectory(atPath: parentDir) else { return }

        for item in contents where item.hasPrefix(prefix) {
            let fullPath = (parentDir as NSString).appendingPathComponent(item)
            try fileManager.removeItem(atPath: fullPath)
        }
    }
}
