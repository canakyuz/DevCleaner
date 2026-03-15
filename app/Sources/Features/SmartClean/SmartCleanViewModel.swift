import SwiftUI

@MainActor
final class SmartCleanViewModel: ObservableObject {
    @Published var targets: [CleanupTarget] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanProgress: Double = 0
    @Published var lastCleanedMessage: String?
    @Published var searchText: String = ""
    @Published var showConfirmation = false

    @Published var nmPaths: [String] = []
    @Published var nmTotalBytes: Int64 = 0
    @Published var nmActiveCount: Int = 0
    @Published var nmSelected = false

    @Published var oldDownloadFiles: [String] = []
    @Published var oldDownloadsBytes: Int64 = 0
    @Published var oldDownloadsSelected = false

    private let scanner = DiskScanner()
    private let cleaner = CleanupService()

    var availableTargets: [CleanupTarget] {
        targets.filter { $0.isAvailable }
    }

    var filteredGroupedTargets: [(group: TargetGroup, items: [CleanupTarget])] {
        let available = availableTargets.filter { target in
            searchText.isEmpty ||
            target.label.localizedCaseInsensitiveContains(searchText) ||
            target.group.rawValue.localizedCaseInsensitiveContains(searchText)
        }
        let grouped = Dictionary(grouping: available) { $0.group }
        return TargetGroup.allCases.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group: group, items: items.sorted { $0.sizeBytes > $1.sizeBytes })
        }
    }

    var maxItemBytes: Int64 {
        let targetMax = availableTargets.map(\.sizeBytes).max() ?? 1
        return max(targetMax, max(nmTotalBytes, oldDownloadsBytes))
    }

    var selectedBytes: Int64 {
        var total: Int64 = 0
        for t in targets where t.isSelected { total += t.sizeBytes }
        if nmSelected { total += nmTotalBytes }
        if oldDownloadsSelected { total += oldDownloadsBytes }
        return total
    }

    var selectedCount: Int {
        var count = targets.filter(\.isSelected).count
        if nmSelected { count += 1 }
        if oldDownloadsSelected { count += 1 }
        return count
    }

    var totalFoundBytes: Int64 {
        var total: Int64 = 0
        for t in availableTargets { total += t.sizeBytes }
        total += nmTotalBytes + oldDownloadsBytes
        return total
    }

    var categoryCount: Int {
        filteredGroupedTargets.count
    }

    func scan() async {
        isScanning = true
        scanProgress = 0
        lastCleanedMessage = nil

        targets = await scanner.scanAll(CategoryRegistry.allTargets())
        scanProgress = 0.7

        let nmResult = await scanner.scanNodeModules(staleDays: 7)
        nmPaths = nmResult.staleTargets.map(\.path)
        nmTotalBytes = nmResult.totalStaleBytes
        nmActiveCount = nmResult.activeCount
        scanProgress = 0.85

        let dlResult = await scanner.scanOldDownloads(olderThanDays: 30)
        oldDownloadFiles = dlResult.files
        oldDownloadsBytes = dlResult.totalBytes
        scanProgress = 1.0

        try? await Task.sleep(nanoseconds: 200_000_000)
        isScanning = false
    }

    func selectAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            for i in targets.indices where targets[i].isAvailable { targets[i].isSelected = true }
            if nmTotalBytes > 0 { nmSelected = true }
            if oldDownloadsBytes > 0 { oldDownloadsSelected = true }
        }
    }

    func selectLowRisk() {
        withAnimation(.easeInOut(duration: 0.2)) {
            deselectAllSilent()
            for i in targets.indices where targets[i].isAvailable && targets[i].risk == .low {
                targets[i].isSelected = true
            }
            if nmTotalBytes > 0 { nmSelected = true }
        }
    }

    func deselectAll() {
        withAnimation(.easeInOut(duration: 0.2)) { deselectAllSilent() }
    }

    private func deselectAllSilent() {
        for i in targets.indices { targets[i].isSelected = false }
        nmSelected = false
        oldDownloadsSelected = false
    }

    func toggleTarget(id: UUID) {
        if let idx = targets.firstIndex(where: { $0.id == id }) {
            withAnimation(.easeInOut(duration: 0.15)) { targets[idx].isSelected.toggle() }
        }
    }

    func selectGroup(_ group: TargetGroup) {
        withAnimation(.easeInOut(duration: 0.2)) {
            for i in targets.indices where targets[i].group == group && targets[i].isAvailable {
                targets[i].isSelected = true
            }
        }
    }

    func deselectGroup(_ group: TargetGroup) {
        withAnimation(.easeInOut(duration: 0.2)) {
            for i in targets.indices where targets[i].group == group { targets[i].isSelected = false }
        }
    }

    func isGroupFullySelected(_ group: TargetGroup) -> Bool {
        let items = targets.filter { $0.group == group && $0.isAvailable }
        return !items.isEmpty && items.allSatisfy(\.isSelected)
    }

    func clean() async {
        isCleaning = true
        showConfirmation = false
        var totalFreed: Int64 = 0
        var cleanedItems: [String] = []

        for target in targets where target.isSelected {
            do {
                let freed = try await cleaner.cleanTarget(target)
                totalFreed += freed
                cleanedItems.append("\(target.group.rawValue)/\(target.label)")
            } catch {}
        }

        if nmSelected && !nmPaths.isEmpty {
            do {
                try await cleaner.cleanNodeModules(paths: nmPaths)
                totalFreed += nmTotalBytes
                cleanedItems.append("node_modules (\(nmPaths.count))")
            } catch {}
        }

        if oldDownloadsSelected && !oldDownloadFiles.isEmpty {
            do {
                try await cleaner.cleanOldDownloads(files: oldDownloadFiles)
                totalFreed += oldDownloadsBytes
                cleanedItems.append("Downloads (\(oldDownloadFiles.count))")
            } catch {}
        }

        try? await cleaner.deleteUnavailableSimulators()

        let record = CleanupService.CleanupRecord(
            date: Date(), freedBytes: totalFreed, items: cleanedItems
        )
        await cleaner.saveRecord(record)

        withAnimation(.spring(duration: 0.5)) {
            lastCleanedMessage = "\(ByteFormatter.format(totalFreed)) temizlendi!"
        }

        isCleaning = false
        await scan()
    }
}
