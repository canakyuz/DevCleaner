import SwiftUI

struct StartupView: View {
    @StateObject private var vm = StartupViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(vm.agents.count) login ogeleri")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                if vm.isScanning {
                    ProgressView().controlSize(.small)
                }

                Button {
                    Task { await vm.scan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if vm.isScanning && vm.agents.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Startup ogeleri taraniyor...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.agents.isEmpty {
                EmptyState(
                    icon: "bolt.fill",
                    title: "Startup ogeleri bulunamadi",
                    subtitle: "Launch Agent ve Login Item bulunamadi"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // User agents
                        if !vm.userAgents.isEmpty {
                            SectionHeader(title: "Kullanici Launch Agents", icon: "person.fill", count: vm.userAgents.count)
                            ForEach(vm.userAgents) { agent in
                                StartupRow(agent: agent) {
                                    Task { await vm.toggleAgent(agent) }
                                } onReveal: {
                                    vm.revealInFinder(agent.path)
                                }
                            }
                        }

                        // System agents
                        if !vm.systemAgents.isEmpty {
                            SectionHeader(title: "Sistem Launch Agents", icon: "gearshape.fill", count: vm.systemAgents.count)
                            ForEach(vm.systemAgents) { agent in
                                StartupRow(agent: agent) {
                                    Task { await vm.toggleAgent(agent) }
                                } onReveal: {
                                    vm.revealInFinder(agent.path)
                                }
                            }
                        }

                        // Global daemons
                        if !vm.globalDaemons.isEmpty {
                            SectionHeader(title: "Launch Daemons", icon: "server.rack", count: vm.globalDaemons.count)
                            ForEach(vm.globalDaemons) { agent in
                                StartupRow(agent: agent) {
                                    Task { await vm.toggleAgent(agent) }
                                } onReveal: {
                                    vm.revealInFinder(agent.path)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task { await vm.scan() }
    }
}

// MARK: - Row

struct StartupRow: View {
    let agent: StartupAgent
    let onToggle: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(agent.isEnabled ? Color.green.opacity(0.12) : Color.gray.opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: agent.isEnabled ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(agent.isEnabled ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Text(agent.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if agent.isApple {
                Text("Apple")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }

            Toggle("", isOn: .constant(agent.isEnabled))
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(agent.isApple)
                .onTapGesture { if !agent.isApple { onToggle() } }

            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.03) : .clear)
        )
        .onHover { isHovered = $0 }
        .help(agent.path)
    }
}

// MARK: - Model

struct StartupAgent: Identifiable {
    let id = UUID()
    let label: String
    let path: String
    var isEnabled: Bool
    let type: AgentType

    var displayName: String {
        let parts = label.split(separator: ".")
        if parts.count > 2 {
            return String(parts.dropFirst(2).joined(separator: "."))
        }
        return label
    }

    var isApple: Bool {
        label.hasPrefix("com.apple.")
    }

    enum AgentType {
        case userAgent
        case systemAgent
        case globalDaemon
    }
}

// MARK: - ViewModel

@MainActor
final class StartupViewModel: ObservableObject {
    @Published var agents: [StartupAgent] = []
    @Published var isScanning = false

    var userAgents: [StartupAgent] {
        agents.filter { $0.type == .userAgent }
    }

    var systemAgents: [StartupAgent] {
        agents.filter { $0.type == .systemAgent }
    }

    var globalDaemons: [StartupAgent] {
        agents.filter { $0.type == .globalDaemon }
    }

    func scan() async {
        isScanning = true
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        var found: [StartupAgent] = []

        // User LaunchAgents
        let userAgentDir = "\(home)/Library/LaunchAgents"
        found += scanPlistDir(userAgentDir, type: .userAgent)

        // System LaunchAgents
        found += scanPlistDir("/Library/LaunchAgents", type: .systemAgent)

        // Global LaunchDaemons
        found += scanPlistDir("/Library/LaunchDaemons", type: .globalDaemon)

        agents = found.sorted { a, b in
            if a.isApple != b.isApple { return !a.isApple }
            return a.label < b.label
        }
        isScanning = false
    }

    private func scanPlistDir(_ path: String, type: StartupAgent.AgentType) -> [StartupAgent] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        return contents.compactMap { file -> StartupAgent? in
            guard file.hasSuffix(".plist") else { return nil }
            let fullPath = (path as NSString).appendingPathComponent(file)

            guard let data = fm.contents(atPath: fullPath),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                return nil
            }

            let label = (plist["Label"] as? String) ?? file.replacingOccurrences(of: ".plist", with: "")
            let disabled = (plist["Disabled"] as? Bool) ?? false

            return StartupAgent(label: label, path: fullPath, isEnabled: !disabled, type: type)
        }
    }

    func toggleAgent(_ agent: StartupAgent) async {
        guard let idx = agents.firstIndex(where: { $0.id == agent.id }) else { return }

        let newState = !agent.isEnabled
        let action = newState ? "bootout" : "bootstrap"
        let domain = agent.type == .userAgent ? "gui/\(getuid())" : "system"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = [action, domain, agent.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            agents[idx].isEnabled = newState
        } catch {}
    }

    func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
