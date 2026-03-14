import Foundation
import Darwin

actor SystemMonitor {
    // MARK: - Memory

    func getMemoryInfo() -> MemoryInfo {
        let total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return .zero }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let appMemory = active + inactive

        let used = active + wired + compressed

        return MemoryInfo(
            total: total,
            used: used,
            free: free,
            active: active,
            inactive: inactive,
            wired: wired,
            compressed: compressed,
            appMemory: appMemory
        )
    }

    // MARK: - RAM Purge

    func purgeRAM() async throws -> UInt64 {
        let before = getMemoryInfo()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // purge needs root, try memory_pressure as fallback
            let fallback = Process()
            fallback.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
            fallback.arguments = ["-l", "warn"]
            fallback.standardOutput = FileHandle.nullDevice
            fallback.standardError = FileHandle.nullDevice
            try fallback.run()
            fallback.waitUntilExit()
        }

        // Wait a moment for stats to settle
        try await Task.sleep(nanoseconds: 500_000_000)

        let after = getMemoryInfo()
        let freed = after.free > before.free ? after.free - before.free : 0

        return freed
    }

    // MARK: - Disk Info

    func getDiskInfo() -> DiskSpaceInfo {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfFileSystem(forPath: "/") else {
            return .zero
        }

        let total = (attrs[.systemSize] as? Int64) ?? 0
        let free = (attrs[.systemFreeSize] as? Int64) ?? 0

        // Try to get purgable space
        let volumeURL = URL(fileURLWithPath: "/")
        let purgable: Int64
        if let values = try? volumeURL.resourceValues(forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey]),
           let opportunistic = values.volumeAvailableCapacityForOpportunisticUsage {
            purgable = opportunistic - free
        } else {
            purgable = 0
        }

        return DiskSpaceInfo(totalBytes: total, freeBytes: free, purgableBytes: purgable)
    }
}
