import SwiftUI

struct DiskMapView: View {
    @StateObject private var vm = DiskMapViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if vm.totalSize > 0 {
                        Text("Total: \(ByteFormatter.format(vm.totalSize))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }

                Spacer()

                if vm.isScanning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Scanning...")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await vm.scan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(vm.isScanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if vm.entries.isEmpty && !vm.isScanning {
                EmptyState(
                    icon: "chart.bar.doc.horizontal",
                    title: "Disk Map",
                    subtitle: "Start a scan to see disk usage"
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Treemap
                        if !vm.entries.isEmpty {
                            TreemapView(entries: vm.entries, totalSize: vm.totalSize)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                        }

                        // Detail list
                        VStack(spacing: 2) {
                            ForEach(vm.entries) { entry in
                                DiskMapEntryRow(entry: entry, totalSize: vm.totalSize)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .task { await vm.scan() }
    }
}

// MARK: - Treemap

struct TreemapView: View {
    let entries: [DiskScanner.DiskMapEntry]
    let totalSize: Int64

    var body: some View {
        GeometryReader { geo in
            let rects = computeRects(in: CGSize(width: geo.size.width, height: geo.size.height))

            ZStack(alignment: .topLeading) {
                ForEach(Array(rects.enumerated()), id: \.offset) { idx, rect in
                    let entry = entries[idx]
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorFor(entry.color).gradient)
                        .frame(width: max(rect.width - 2, 0), height: max(rect.height - 2, 0))
                        .overlay(
                            VStack(spacing: 2) {
                                if rect.width > 50 && rect.height > 30 {
                                    Text(entry.name)
                                        .font(.system(size: min(rect.width / 8, 12), weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(ByteFormatter.format(entry.sizeBytes))
                                        .font(.system(size: min(rect.width / 10, 10), weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        )
                        .offset(x: rect.minX + 1, y: rect.minY + 1)
                        .help("\(entry.name): \(ByteFormatter.format(entry.sizeBytes))")
                }
            }
        }
    }

    private func computeRects(in size: CGSize) -> [CGRect] {
        guard !entries.isEmpty else { return [] }

        let total = Double(entries.reduce(0) { $0 + $1.sizeBytes })
        guard total > 0 else { return [] }

        var rects: [CGRect] = []
        var remaining = CGRect(origin: .zero, size: size)

        for (i, entry) in entries.enumerated() {
            let ratio = Double(entry.sizeBytes) / total
            let isLast = i == entries.count - 1

            if isLast {
                rects.append(remaining)
            } else if remaining.width > remaining.height {
                let width = remaining.width * ratio / remainingRatio(from: i, total: total)
                rects.append(CGRect(x: remaining.minX, y: remaining.minY, width: width, height: remaining.height))
                remaining = CGRect(x: remaining.minX + width, y: remaining.minY, width: remaining.width - width, height: remaining.height)
            } else {
                let height = remaining.height * ratio / remainingRatio(from: i, total: total)
                rects.append(CGRect(x: remaining.minX, y: remaining.minY, width: remaining.width, height: height))
                remaining = CGRect(x: remaining.minX, y: remaining.minY + height, width: remaining.width, height: remaining.height - height)
            }
        }

        return rects
    }

    private func remainingRatio(from index: Int, total: Double) -> Double {
        let remaining = entries[index...].reduce(0.0) { $0 + Double($1.sizeBytes) }
        return remaining / total
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue":   return .blue
        case "purple": return .purple
        case "green":  return .green
        case "orange": return .orange
        case "cyan":   return .cyan
        case "red":    return .red
        case "pink":   return .pink
        case "yellow": return .yellow
        case "indigo": return .indigo
        default:       return .gray
        }
    }
}

// MARK: - Entry Row

struct DiskMapEntryRow: View {
    let entry: DiskScanner.DiskMapEntry
    let totalSize: Int64

    @State private var isExpanded = false

    private var percent: Double {
        totalSize > 0 ? Double(entry.sizeBytes) / Double(totalSize) * 100 : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if !entry.children.isEmpty {
                    withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
                }
            } label: {
                HStack(spacing: 10) {
                    if !entry.children.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(colorFor(entry.color))
                        .frame(width: 16)

                    Text(entry.name)
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    Text(String(format: "%.1f%%", percent))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(ByteFormatter.format(entry.sizeBytes))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(entry.children) { child in
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(width: 14)

                            Text(child.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Text(ByteFormatter.format(child.sizeBytes))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.leading, 36)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "cyan": return .cyan
        case "red": return .red
        case "pink": return .pink
        case "yellow": return .yellow
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - ViewModel

@MainActor
final class DiskMapViewModel: ObservableObject {
    @Published var entries: [DiskScanner.DiskMapEntry] = []
    @Published var isScanning = false

    private let scanner = DiskScanner()

    var totalSize: Int64 {
        entries.reduce(0) { $0 + $1.sizeBytes }
    }

    func scan() async {
        isScanning = true
        entries = await scanner.scanDiskMap()
        isScanning = false
    }
}
