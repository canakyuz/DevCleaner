import SwiftUI

struct SmartCleanView: View {
    @StateObject private var vm = SmartCleanViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Controls bar
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        TextField("Search...", text: $vm.searchText)
                            .font(.system(size: 11))
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))

                    Spacer()

                    if vm.totalFoundBytes > 0 {
                        Text(ByteFormatter.format(vm.totalFoundBytes))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Menu {
                        Button("Select All") { vm.selectAll() }
                        Button("Select Safe (low risk)") { vm.selectLowRisk() }
                        Divider()
                        Button("Uninstall Selected") { vm.deselectAll() }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)

                    Button {
                        Task { await vm.scan() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .rotationEffect(.degrees(vm.isScanning ? 360 : 0))
                            .animation(
                                vm.isScanning
                                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: vm.isScanning
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(vm.isScanning)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Content
                if vm.isScanning {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.06), lineWidth: 4)
                                .frame(width: 50, height: 50)
                            Circle()
                                .trim(from: 0, to: vm.scanProgress)
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(vm.scanProgress * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Text("Scanning...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.availableTargets.isEmpty && vm.nmTotalBytes == 0 {
                    EmptyState(
                        icon: "checkmark.circle.fill",
                        title: "System is clean",
                        subtitle: "No caches to clean"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // node_modules
                            if vm.nmTotalBytes > 0 {
                                SpecialTargetRow(
                                    icon: "folder.fill",
                                    label: "node_modules",
                                    detail: "\(vm.nmPaths.count) eski, \(vm.nmActiveCount) aktif korundu",
                                    bytes: vm.nmTotalBytes,
                                    maxBytes: vm.maxItemBytes,
                                    risk: .low,
                                    color: .yellow,
                                    isSelected: vm.nmSelected
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        vm.nmSelected.toggle()
                                    }
                                }
                            }

                            // Old downloads
                            if vm.oldDownloadsBytes > 0 {
                                SpecialTargetRow(
                                    icon: "arrow.down.circle",
                                    label: "Old Downloads",
                                    detail: "\(vm.oldDownloadFiles.count) dosya, 30+ gun",
                                    bytes: vm.oldDownloadsBytes,
                                    maxBytes: vm.maxItemBytes,
                                    risk: .medium,
                                    color: .mint,
                                    isSelected: vm.oldDownloadsSelected
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        vm.oldDownloadsSelected.toggle()
                                    }
                                }
                            }

                            // Grouped categories
                            ForEach(vm.filteredGroupedTargets, id: \.group) { section in
                                SmartCleanSection(
                                    group: section.group,
                                    items: section.items,
                                    maxBytes: vm.maxItemBytes,
                                    onToggle: { vm.toggleTarget(id: $0) },
                                    onSelectGroup: { vm.selectGroup(section.group) },
                                    onDeselectGroup: { vm.deselectGroup(section.group) },
                                    isGroupSelected: vm.isGroupFullySelected(section.group)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Footer
                if vm.selectedCount > 0 {
                    Divider()
                    HStack(spacing: 10) {
                        if let msg = vm.lastCleanedMessage {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(msg)
                                    .foregroundStyle(.green)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            Text("\(vm.selectedCount) selected")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(ByteFormatter.format(vm.selectedBytes))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))

                        Button {
                            vm.showConfirmation = true
                        } label: {
                            HStack(spacing: 5) {
                                if vm.isCleaning {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "trash.fill").font(.system(size: 10))
                                }
                                Text(vm.isCleaning ? "Cleaning..." : "Clean")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .top, endPoint: .bottom),
                                in: Capsule()
                            )
                            .foregroundStyle(.white)
                            .shadow(color: .red.opacity(0.2), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isCleaning)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            // Confirmation
            if vm.showConfirmation {
                ConfirmationOverlay(
                    selectedCount: vm.selectedCount,
                    selectedBytes: vm.selectedBytes,
                    mediumRiskCount: vm.targets.filter { $0.isSelected && $0.risk == .medium }.count,
                    onCancel: { withAnimation { vm.showConfirmation = false } },
                    onConfirm: { Task { await vm.clean() } }
                )
            }
        }
        .task { await vm.scan() }
    }
}

// MARK: - Section

struct SmartCleanSection: View {
    let group: TargetGroup
    let items: [CleanupTarget]
    let maxBytes: Int64
    let onToggle: (UUID) -> Void
    let onSelectGroup: () -> Void
    let onDeselectGroup: () -> Void
    let isGroupSelected: Bool

    @State private var isExpanded = true

    private var groupTotal: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)

                        ZStack {
                            Circle().fill(group.color.opacity(0.15)).frame(width: 22, height: 22)
                            Image(systemName: group.icon).font(.system(size: 10)).foregroundStyle(group.color)
                        }

                        Text(group.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                SizeText(bytes: groupTotal)

                Button {
                    isGroupSelected ? onDeselectGroup() : onSelectGroup()
                } label: {
                    Image(systemName: isGroupSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isGroupSelected ? group.color : Color.gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        SmartCleanRow(target: item, maxBytes: maxBytes, groupColor: group.color) {
                            onToggle(item.id)
                        }
                    }
                }
                .padding(.leading, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Row

struct SmartCleanRow: View {
    let target: CleanupTarget
    let maxBytes: Int64
    let groupColor: Color
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: target.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(target.isSelected ? groupColor : Color.gray.opacity(0.3))
                        .contentTransition(.symbolEffect(.replace))

                    Text(target.label)
                        .font(.system(size: 11))
                        .lineLimit(1)

                    Spacer()

                    RiskBadge(risk: target.risk)
                    SizeText(bytes: target.sizeBytes)
                }
                ProportionalBar(bytes: target.sizeBytes, maxBytes: maxBytes, color: groupColor)
                    .padding(.leading, 21)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(target.path)
    }
}

// MARK: - Special Target Row

struct SpecialTargetRow: View {
    let icon: String
    let label: String
    let detail: String
    let bytes: Int64
    let maxBytes: Int64
    let risk: Risk
    let color: Color
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? color : Color.gray.opacity(0.3))
                        .contentTransition(.symbolEffect(.replace))

                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 22, height: 22)
                        Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(label).font(.system(size: 11, weight: .medium))
                        Text(detail).font(.system(size: 9)).foregroundStyle(.secondary)
                    }

                    Spacer()

                    RiskBadge(risk: risk)
                    SizeText(bytes: bytes)
                }
                ProportionalBar(bytes: bytes, maxBytes: maxBytes, color: color)
                    .padding(.leading, 21)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Confirmation Overlay

struct ConfirmationOverlay: View {
    let selectedCount: Int
    let selectedBytes: Int64
    let mediumRiskCount: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(.red.opacity(0.1)).frame(width: 44, height: 44)
                    Image(systemName: "trash.fill").font(.system(size: 20)).foregroundStyle(.red)
                }

                VStack(spacing: 4) {
                    Text("Confirm Cleanup")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(selectedCount) oge, toplam \(ByteFormatter.format(selectedBytes)) silinecek.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if mediumRiskCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10)).foregroundStyle(.orange)
                        Text("\(mediumRiskCount) items are medium risk")
                            .font(.system(size: 10)).foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                }

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text("Clean")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.red, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(width: 300)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        }
        .transition(.opacity)
    }
}
