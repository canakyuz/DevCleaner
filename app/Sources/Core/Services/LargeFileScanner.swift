import Foundation

actor LargeFileScanner {
    private let fileManager = FileManager.default

    func scan(
        in directories: [String],
        minSizeBytes: Int64 = 104_857_600, // 100MB default
        maxResults: Int = 200
    ) -> [LargeFile] {
        var results: [LargeFile] = []
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .contentModificationDateKey,
            .isRegularFileKey
        ]

        for dir in directories {
            guard fileManager.fileExists(atPath: dir) else { continue }

            let url = URL(fileURLWithPath: dir)
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants],
                errorHandler: nil
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      let size = values.fileSize,
                      size >= minSizeBytes else { continue }

                let ext = fileURL.pathExtension
                let modified = values.contentModificationDate ?? .distantPast

                results.append(LargeFile(
                    path: fileURL.path,
                    name: fileURL.lastPathComponent,
                    sizeBytes: Int64(size),
                    modifiedDate: modified,
                    fileType: FileType.from(extension: ext)
                ))
            }
        }

        // Sort by size descending, limit results
        results.sort { $0.sizeBytes > $1.sizeBytes }
        return Array(results.prefix(maxResults))
    }

    func defaultScanDirs() -> [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Downloads",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Movies",
            "\(home)/Music",
            "\(home)/Pictures",
            "\(home)/Library",
        ]
    }

    func deleteFiles(_ paths: [String]) throws {
        for path in paths {
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(atPath: path)
            }
        }
    }
}
