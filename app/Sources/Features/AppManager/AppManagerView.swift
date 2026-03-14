import SwiftUI

struct AppManagerView: View {
    @StateObject private var vm = AppManagerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Search + controls
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    TextField("Uygulama ara...", text: $vm.searchText)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))

                Spacer()

                if !vm.apps.isEmpty {
                    Text("\(vm.filteredApps.count) uygulama")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                if vm.isScanning {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // App list
            if vm.isScanning && vm.apps.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Uygulamalar taraniyor...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.filteredApps.isEmpty {
                EmptyState(
                    icon: "square.grid.2x2",
                    title: "Uygulama bulunamadi",
                    subtitle: vm.searchText.isEmpty ? "Tarama devam ediyor..." : "Arama ile eslesme yok"
                )
            } else {
                List(vm.filteredApps) { app in
                    AppRow(
                        app: app,
                        onCleanCache: { Task { await vm.cleanCache(app) } },
                        onUninstall: { Task { await vm.uninstall(app) } },
                        onReveal: { vm.reveal(app) }
                    )
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task { await vm.scan() }
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: AppInfo
    let onCleanCache: () -> Void
    let onUninstall: () -> Void
    let onReveal: () -> Void

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 10) {
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .frame(width: 32, height: 32)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "app")
                                .foregroundStyle(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("v\(app.version)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)

                        if app.cacheSize > 0 {
                            HStack(spacing: 2) {
                                Circle().fill(.orange).frame(width: 4, height: 4)
                                Text("Cache: \(ByteFormatter.format(app.cacheSize))")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Spacer()

                Text(ByteFormatter.format(app.totalSize))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        app.totalSize > 1_073_741_824 ? .red :
                        app.totalSize > 104_857_600 ? .orange : .primary
                    )

                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            // Expanded detail
            if isExpanded {
                VStack(spacing: 6) {
                    detailRow("App Bundle", bytes: app.bundleSize, icon: "app.fill", color: .blue)
                    if app.cacheSize > 0 {
                        detailRow("Cache", bytes: app.cacheSize, icon: "archivebox", color: .orange)
                    }
                    if app.dataSize > 0 {
                        detailRow("Data", bytes: app.dataSize, icon: "doc.fill", color: .purple)
                    }

                    Divider()

                    HStack(spacing: 8) {
                        Spacer()

                        Button(action: onReveal) {
                            Label("Finder", systemImage: "folder")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        if app.cacheSize > 0 {
                            Button(action: onCleanCache) {
                                Label("Cache Temizle", systemImage: "paintbrush")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.orange)
                        }

                        Button(action: onUninstall) {
                            Label("Kaldir", systemImage: "trash")
                                .font(.system(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                .padding(.leading, 42)
                .padding(.vertical, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onHover { isHovered = $0 }
    }

    private func detailRow(_ label: String, bytes: Int64, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(ByteFormatter.format(bytes))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AppManagerViewModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var isScanning = false
    @Published var searchText = ""

    private let service = AppManagerService()

    var filteredApps: [AppInfo] {
        if searchText.isEmpty { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    func scan() async {
        isScanning = true
        apps = await service.scanInstalledApps()
        isScanning = false
    }

    func cleanCache(_ app: AppInfo) async {
        do {
            try await service.cleanAppCache(app)
            await scan()
        } catch {}
    }

    func uninstall(_ app: AppInfo) async {
        do {
            try await service.uninstallApp(app)
            apps.removeAll { $0.id == app.id }
        } catch {}
    }

    func reveal(_ app: AppInfo) {
        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
    }
}
