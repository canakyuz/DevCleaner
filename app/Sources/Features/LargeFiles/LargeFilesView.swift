import SwiftUI

struct LargeFilesView: View {
    @StateObject private var vm = LargeFilesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack(spacing: 10) {
                // Min size picker
                HStack(spacing: 4) {
                    Text("Min:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $vm.minSizeMB) {
                        Text("50 MB").tag(50)
                        Text("100 MB").tag(100)
                        Text("250 MB").tag(250)
                        Text("500 MB").tag(500)
                        Text("1 GB").tag(1024)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    .controlSize(.small)
                }

                Spacer()

                if !vm.files.isEmpty {
                    Text("\(vm.files.count) dosya, \(ByteFormatter.format(vm.totalBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await vm.scan() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                        Text("Tara")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(vm.isScanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Content
            if vm.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Buyuk dosyalar araniyor...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.files.isEmpty {
                EmptyState(
                    icon: "doc.questionmark",
                    title: "Tarama baslatilmadi",
                    subtitle: "Buyuk dosyalari bulmak icin 'Tara' butonuna tiklayin"
                )
            } else {
                // File list
                List(vm.files) { file in
                    LargeFileRow(
                        file: file,
                        isSelected: file.isSelected,
                        onToggle: { vm.toggleFile(id: file.id) },
                        onReveal: { vm.revealInFinder(file.path) }
                    )
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer
            if vm.selectedCount > 0 {
                Divider()
                HStack {
                    Text("\(vm.selectedCount) secili - \(ByteFormatter.format(vm.selectedBytes))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        Task { await vm.deleteSelected() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 10))
                            Text("Sil")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.red, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .task { await vm.scan() }
    }
}

// MARK: - File Row

struct LargeFileRow: View {
    let file: LargeFile
    let isSelected: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: "tr_TR")
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .red : Color.gray.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 30, height: 30)
                Image(systemName: file.fileType.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.fileType.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    Text(Self.dateFormatter.localizedString(for: file.modifiedDate, relativeTo: Date()))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(ByteFormatter.format(file.sizeBytes))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(file.sizeBytes > 1_073_741_824 ? .red : .orange)

            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 2)
        .onHover { isHovered = $0 }
        .help(file.path)
    }
}

// MARK: - ViewModel

@MainActor
final class LargeFilesViewModel: ObservableObject {
    @Published var files: [LargeFile] = []
    @Published var isScanning = false
    @Published var minSizeMB: Int = 100

    private let scanner = LargeFileScanner()

    var totalBytes: Int64 { files.reduce(0) { $0 + $1.sizeBytes } }
    var selectedCount: Int { files.filter(\.isSelected).count }
    var selectedBytes: Int64 { files.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }

    func scan() async {
        isScanning = true
        let dirs = await scanner.defaultScanDirs()
        files = await scanner.scan(
            in: dirs,
            minSizeBytes: Int64(minSizeMB) * 1_048_576
        )
        isScanning = false
    }

    func toggleFile(id: UUID) {
        if let idx = files.firstIndex(where: { $0.id == id }) {
            files[idx].isSelected.toggle()
        }
    }

    func deleteSelected() async {
        let paths = files.filter(\.isSelected).map(\.path)
        do {
            try await scanner.deleteFiles(paths)
            files.removeAll { $0.isSelected }
        } catch {}
    }

    func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
