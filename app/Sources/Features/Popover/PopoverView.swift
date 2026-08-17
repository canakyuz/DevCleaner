import SwiftUI

struct PopoverView: View {
    @StateObject private var vm = PopoverViewModel()
    var onOpenWindow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 22, height: 22)
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("DevCleaner")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Button {
                    onOpenWindow()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Open full window")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().opacity(0.5)

            // Stats
            VStack(spacing: 10) {
                // Disk
                MiniGaugeRow(
                    icon: "internaldrive",
                    label: "Disk",
                    value: vm.diskInfo.usedPercent / 100,
                    detail: "\(ByteFormatter.format(vm.diskInfo.freeBytes)) free",
                    color: diskColor
                )

                // RAM
                MiniGaugeRow(
                    icon: "memorychip",
                    label: "RAM",
                    value: vm.memoryInfo.usedPercent / 100,
                    detail: "\(ByteFormatter.format(vm.memoryInfo.free)) free",
                    color: ramColor
                )

                // Network
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "network")
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan)
                            .frame(width: 14)
                        Text("Network")
                            .font(.system(size: 11, weight: .semibold))
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        HStack(spacing: 3) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(vm.portCount > 0 ? .green : .secondary)
                            Text("\(vm.portCount) ports")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(vm.sshCount > 0 ? .orange : .secondary)
                            Text("\(vm.sshCount) SSH")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.5)

            // Quick actions
            VStack(spacing: 6) {
                switch vm.quickState {
                case .idle:
                    PopoverActionButton(
                        icon: "paintbrush.fill",
                        label: "Smart Clean",
                        subtitle: "Scan caches and dev files",
                        color: .blue
                    ) {
                        Task { await vm.scanSafe() }
                    }

                case .scanning:
                    PopoverActionButton(
                        icon: "paintbrush.fill",
                        label: "Scanning...",
                        subtitle: "Measuring 101 targets",
                        color: .blue,
                        isLoading: true
                    ) {}

                case let .ready(bytes, count):
                    PopoverActionButton(
                        icon: "trash.fill",
                        label: "Clean \(ByteFormatter.format(bytes))",
                        subtitle: "\(count) safe items, nothing risky",
                        color: .blue
                    ) {
                        Task { await vm.cleanSafe() }
                    }

                case .cleaning:
                    PopoverActionButton(
                        icon: "trash.fill",
                        label: "Cleaning...",
                        subtitle: "Removing safe caches",
                        color: .blue,
                        isLoading: true
                    ) {}

                case .empty:
                    PopoverActionButton(
                        icon: "checkmark.circle.fill",
                        label: "Nothing to clean",
                        subtitle: "No safe caches are taking space",
                        color: .green
                    ) {}

                case let .done(bytes):
                    PopoverActionButton(
                        icon: "checkmark.circle.fill",
                        label: "\(ByteFormatter.format(bytes)) reclaimed",
                        subtitle: "Open the window for deeper cleanup",
                        color: .green
                    ) {
                        onOpenWindow()
                    }
                }

                PopoverActionButton(
                    icon: "bolt.fill",
                    label: "Optimize RAM",
                    subtitle: vm.isOptimizing ? "Optimizing..." : "Free up memory",
                    color: .green,
                    isLoading: vm.isOptimizing
                ) {
                    Task { await vm.optimizeRAM() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            // Footer
            HStack {
                if let result = vm.lastResult {
                    Text(result)
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .task { await vm.refresh() }
    }

    private var diskColor: Color {
        let pct = vm.diskInfo.usedPercent
        if pct > 95 { return .red }
        if pct > 85 { return .orange }
        return .blue
    }

    private var ramColor: Color {
        switch vm.memoryInfo.pressure {
        case .critical: return .red
        case .warning:  return .orange
        case .nominal:  return .green
        }
    }
}

// MARK: - Mini Gauge Row

struct MiniGaugeRow: View {
    let icon: String
    let label: String
    let value: Double
    let detail: String
    let color: Color

    @State private var animated: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(color)
                        .frame(width: 14)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                }

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.06))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.gradient)
                        .frame(width: geo.size.width * animated)
                }
            }
            .frame(height: 5)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.15)) {
                animated = min(value, 1.0)
            }
        }
        .onChange(of: value) {
            withAnimation(.spring(duration: 0.5)) {
                animated = min(value, 1.0)
            }
        }
    }
}

// MARK: - Action Button

struct PopoverActionButton: View {
    let icon: String
    let label: String
    let subtitle: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.12))
                        .frame(width: 28, height: 28)

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundStyle(color)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.primary.opacity(0.05) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Quick Clean State

enum QuickCleanState: Equatable {
    case idle
    case scanning
    case ready(bytes: Int64, count: Int)
    case empty
    case cleaning
    case done(bytes: Int64)
}

// MARK: - ViewModel

@MainActor
final class PopoverViewModel: ObservableObject {
    @Published var diskInfo: DiskSpaceInfo = .zero
    @Published var memoryInfo: MemoryInfo = .zero
    @Published var portCount: Int = 0
    @Published var sshCount: Int = 0
    @Published var isOptimizing = false
    @Published var lastResult: String?

    // Quick clean runs entirely from the menubar. It only ever touches Safe
    // targets: anything the owning tool transparently regenerates. Caution and
    // Risky items stay behind the full window, where the path and the size are
    // visible before you commit to deleting them.
    @Published var quickState: QuickCleanState = .idle
    @Published var safeTargets: [CleanupTarget] = []

    var safeBytes: Int64 { safeTargets.reduce(0) { $0 + $1.sizeBytes } }

    private let monitor = SystemMonitor()
    private let scanner = DiskScanner()
    private let cleaner = CleanupService()

    func refresh() async {
        diskInfo = await monitor.getDiskInfo()
        memoryInfo = await monitor.getMemoryInfo()
        let (ports, ssh) = await Task.detached {
            (NetworkScanner.scanPorts().count, NetworkScanner.scanSSH().count)
        }.value
        portCount = ports
        sshCount = ssh
    }

    /// Scans every registered target, then keeps only the Safe ones that
    /// actually hold bytes. Sizing is the slow part, so it runs off the main
    /// actor through the same TaskGroup the full window uses.
    func scanSafe() async {
        quickState = .scanning

        let scanned = await scanner.scanAll(CategoryRegistry.allTargets())
        safeTargets = scanned.filter { $0.risk == .low && $0.sizeBytes > 0 }

        if safeTargets.isEmpty {
            quickState = .empty
            try? await Task.sleep(for: .seconds(3))
            if quickState == .empty { quickState = .idle }
        } else {
            quickState = .ready(bytes: safeBytes, count: safeTargets.count)
        }
    }

    /// Deletes the scanned Safe set. A target that fails is skipped rather than
    /// aborting the run, so one locked cache cannot strand the rest.
    func cleanSafe() async {
        guard !safeTargets.isEmpty else { return }
        quickState = .cleaning

        var freed: Int64 = 0
        for target in safeTargets {
            freed += (try? await cleaner.cleanTarget(target)) ?? 0
        }

        await cleaner.saveRecord(
            CleanupService.CleanupRecord(
                date: Date(),
                freedBytes: freed,
                items: safeTargets.map(\.label)
            )
        )

        safeTargets = []
        diskInfo = await monitor.getDiskInfo()
        quickState = .done(bytes: freed)

        try? await Task.sleep(for: .seconds(4))
        quickState = .idle
    }

    func optimizeRAM() async {
        isOptimizing = true
        lastResult = nil

        do {
            let freed = try await monitor.purgeRAM()
            memoryInfo = await monitor.getMemoryInfo()

            if freed > 0 {
                lastResult = "\(ByteFormatter.format(Int64(freed))) freed"
            } else {
                lastResult = "Memory is already optimized"
            }
        } catch {
            lastResult = "Optimization failed"
        }

        isOptimizing = false

        try? await Task.sleep(for: .seconds(3))
        lastResult = nil
    }
}
