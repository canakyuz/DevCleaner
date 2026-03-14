import SwiftUI

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Gauges row
                HStack(spacing: 20) {
                    CircularGauge(
                        value: vm.diskInfo.usedPercent / 100,
                        label: "Disk",
                        detail: "\(ByteFormatter.format(vm.diskInfo.freeBytes)) bos",
                        gradient: diskColors
                    )

                    CircularGauge(
                        value: vm.memoryInfo.usedPercent / 100,
                        label: "RAM",
                        detail: "\(ByteFormatter.format(vm.memoryInfo.free)) bos",
                        gradient: ramColors
                    )
                }
                .padding(.top, 8)

                // Disk bar
                DiskUsageBar(
                    total: vm.diskInfo.totalBytes,
                    free: vm.diskInfo.freeBytes,
                    purgable: vm.diskInfo.purgableBytes
                )
                .padding(.horizontal, 4)

                // Quick stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 8) {
                    StatCard(
                        icon: "memorychip",
                        label: "Aktif RAM",
                        value: ByteFormatter.format(vm.memoryInfo.active),
                        color: .blue
                    )
                    StatCard(
                        icon: "lock.fill",
                        label: "Wired",
                        value: ByteFormatter.format(vm.memoryInfo.wired),
                        color: .orange
                    )
                    StatCard(
                        icon: "archivebox",
                        label: "Compressed",
                        value: ByteFormatter.format(vm.memoryInfo.compressed),
                        color: .purple
                    )
                }

                // Memory pressure
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(pressureColor)
                            .frame(width: 8, height: 8)
                        Text("Bellek Basinci: \(vm.memoryInfo.pressure.rawValue)")
                            .font(.system(size: 11, weight: .medium))
                    }

                    Spacer()

                    if vm.cleanableBytes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                            Text("\(ByteFormatter.format(vm.cleanableBytes)) temizlenebilir")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // History
                if !vm.history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Son Temizlikler", icon: "clock")
                            .padding(.horizontal, -12)

                        ForEach(vm.history.prefix(3), id: \.date) { record in
                            HStack {
                                Text(record.date, style: .relative)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("+" + ByteFormatter.format(record.freedBytes))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(16)
        }
        .task { await vm.refresh() }
    }

    private var diskColors: [Color] {
        let pct = vm.diskInfo.usedPercent
        if pct > 95 { return [.red, .orange] }
        if pct > 85 { return [.orange, .yellow] }
        return [.blue, .cyan]
    }

    private var ramColors: [Color] {
        switch vm.memoryInfo.pressure {
        case .critical: return [.red, .orange]
        case .warning:  return [.orange, .yellow]
        case .nominal:  return [.green, .mint]
        }
    }

    private var pressureColor: Color {
        switch vm.memoryInfo.pressure {
        case .critical: return .red
        case .warning:  return .orange
        case .nominal:  return .green
        }
    }
}

// MARK: - ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var diskInfo: DiskSpaceInfo = .zero
    @Published var memoryInfo: MemoryInfo = .zero
    @Published var cleanableBytes: Int64 = 0
    @Published var history: [CleanupService.CleanupRecord] = []

    private let monitor = SystemMonitor()
    private let cleaner = CleanupService()

    func refresh() async {
        diskInfo = await monitor.getDiskInfo()
        memoryInfo = await monitor.getMemoryInfo()
        history = await cleaner.loadHistory()
    }
}
