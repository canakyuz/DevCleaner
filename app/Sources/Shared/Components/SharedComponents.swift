import SwiftUI

// MARK: - Byte Formatter

enum ByteFormatter {
    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter.string(fromByteCount: bytes)
    }

    static func format(_ bytes: UInt64) -> String {
        format(Int64(min(bytes, UInt64(Int64.max))))
    }
}

// MARK: - Circular Gauge

struct CircularGauge: View {
    let value: Double // 0...1
    let label: String
    let detail: String
    let gradient: [Color]
    var size: CGFloat = 80

    @State private var animated: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: animated)
                    .stroke(
                        AngularGradient(colors: gradient, center: .center),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(Int(value * 100))")
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.system(size: size * 0.1))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)

            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.15)) {
                animated = value
            }
        }
        .onChange(of: value) {
            withAnimation(.spring(duration: 0.6)) {
                animated = value
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Proportional Bar

struct ProportionalBar: View {
    let bytes: Int64
    let maxBytes: Int64
    let color: Color

    private var ratio: Double {
        maxBytes > 0 ? min(Double(bytes) / Double(maxBytes), 1.0) : 0
    }

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.25))
                .frame(width: max(geo.size.width * ratio, 2))
        }
        .frame(height: 3)
    }
}

// MARK: - Disk Usage Bar

struct DiskUsageBar: View {
    let total: Int64
    let free: Int64
    var purgable: Int64 = 0

    @State private var animatedPercent: Double = 0

    private var used: Int64 { total - free }
    private var usedPercent: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }

    private var barGradient: LinearGradient {
        if usedPercent > 0.95 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        }
        if usedPercent > 0.85 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )

                    RoundedRectangle(cornerRadius: 5)
                        .fill(barGradient)
                        .frame(width: geo.size.width * animatedPercent)
                        .shadow(
                            color: usedPercent > 0.9 ? .red.opacity(0.3) : .clear,
                            radius: 4
                        )

                    // Purgable indicator
                    if purgable > 0 {
                        let purgableRatio = Double(purgable) / Double(total)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.green.opacity(0.3))
                            .frame(width: geo.size.width * purgableRatio)
                            .offset(x: geo.size.width * animatedPercent)
                    }
                }
            }
            .frame(height: 10)

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(usedPercent > 0.95 ? .red : usedPercent > 0.85 ? .orange : .blue)
                        .frame(width: 6, height: 6)
                    Text("\(Int(usedPercent * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(ByteFormatter.format(free)) free / \(ByteFormatter.format(total))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.2)) {
                animatedPercent = usedPercent
            }
        }
        .onChange(of: free) {
            withAnimation(.spring(duration: 0.6)) {
                animatedPercent = usedPercent
            }
        }
    }
}

// MARK: - Risk Badge

struct RiskBadge: View {
    let risk: Risk

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(risk.color)
                .frame(width: 5, height: 5)
            Text(risk.label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(risk.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(risk.color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Size Text

struct SizeText: View {
    let bytes: Int64
    var mono: Bool = true

    var body: some View {
        Text(ByteFormatter.format(bytes))
            .font(.system(
                size: 11,
                weight: .semibold,
                design: mono ? .monospaced : .default
            ))
            .foregroundStyle(
                bytes > 1_073_741_824 ? .red :
                bytes > 104_857_600 ? .orange : .primary
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    var count: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.4), in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State

struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.quaternary)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
