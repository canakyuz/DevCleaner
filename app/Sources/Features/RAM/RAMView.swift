import SwiftUI

struct RAMView: View {
    @StateObject private var vm = RAMViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main gauge
                CircularGauge(
                    value: vm.memory.usedPercent / 100,
                    label: "RAM Kullanimi",
                    detail: "\(ByteFormatter.format(vm.memory.free)) bos",
                    gradient: gaugeColors,
                    size: 100
                )
                .padding(.top, 8)

                // Memory breakdown
                VStack(spacing: 2) {
                    memoryRow("Uygulama Bellegi", bytes: vm.memory.appMemory, color: .blue)
                    memoryRow("Wired (Sistem)", bytes: vm.memory.wired, color: .orange)
                    memoryRow("Compressed", bytes: vm.memory.compressed, color: .purple)
                    memoryRow("Bos", bytes: vm.memory.free, color: .green)
                }
                .padding(12)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))

                // Stacked bar
                GeometryReader { geo in
                    let total = Double(vm.memory.total)
                    HStack(spacing: 1) {
                        barSegment(
                            width: geo.size.width * Double(vm.memory.active) / total,
                            color: .blue, label: "Aktif"
                        )
                        barSegment(
                            width: geo.size.width * Double(vm.memory.wired) / total,
                            color: .orange, label: "Wired"
                        )
                        barSegment(
                            width: geo.size.width * Double(vm.memory.compressed) / total,
                            color: .purple, label: "Compressed"
                        )
                        barSegment(
                            width: geo.size.width * Double(vm.memory.inactive) / total,
                            color: .yellow, label: "Inactive"
                        )
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    legendItem("Aktif", color: .blue)
                    legendItem("Wired", color: .orange)
                    legendItem("Compressed", color: .purple)
                    legendItem("Inactive", color: .yellow)
                    legendItem("Bos", color: .green)
                }

                Divider()

                // Optimize button
                VStack(spacing: 8) {
                    Button {
                        Task { await vm.optimizeRAM() }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isOptimizing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12))
                            }
                            Text(vm.isOptimizing ? "Optimize ediliyor..." : "RAM Optimize Et")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .foregroundStyle(.white)
                        .shadow(color: .blue.opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isOptimizing)

                    if let msg = vm.resultMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(msg)
                                .foregroundStyle(.green)
                        }
                        .font(.system(size: 11))
                        .transition(.scale.combined(with: .opacity))
                    }

                    Text("Inaktif bellek ve dosya cache'lerini temizler.\nSistem gerektiginde otomatik olarak yeniden olusturur.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
        }
        .task { await vm.refresh() }
    }

    private func memoryRow(_ label: String, bytes: UInt64, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(ByteFormatter.format(bytes))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(.vertical, 3)
    }

    private func barSegment(width: CGFloat, color: Color, label: String) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(width, 0))
            .help(label)
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private var gaugeColors: [Color] {
        switch vm.memory.pressure {
        case .critical: return [.red, .orange]
        case .warning:  return [.orange, .yellow]
        case .nominal:  return [.green, .mint]
        }
    }
}

// MARK: - ViewModel

@MainActor
final class RAMViewModel: ObservableObject {
    @Published var memory: MemoryInfo = .zero
    @Published var isOptimizing = false
    @Published var resultMessage: String?

    private let monitor = SystemMonitor()

    func refresh() async {
        memory = await monitor.getMemoryInfo()
    }

    func optimizeRAM() async {
        isOptimizing = true
        resultMessage = nil

        do {
            let freed = try await monitor.purgeRAM()
            await refresh()
            withAnimation(.spring(duration: 0.5)) {
                resultMessage = "\(ByteFormatter.format(freed)) bellek serbest birakildi"
            }
        } catch {
            withAnimation {
                resultMessage = "Optimizasyon basarisiz (admin yetkisi gerekebilir)"
            }
        }

        isOptimizing = false
    }
}
