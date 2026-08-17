import SwiftUI

struct NetworkView: View {
    @StateObject private var vm = NetworkViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Picker("", selection: $vm.selectedTab) {
                        Text("Ports").tag(NetworkTab.ports)
                        Text("SSH").tag(NetworkTab.ssh)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

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

            // Content
            switch vm.selectedTab {
            case .ports:
                portsList
            case .ssh:
                sshList
            }
        }
        .task { await vm.scan() }
    }

    // MARK: - Ports

    private var portsList: some View {
        Group {
            if vm.ports.isEmpty && !vm.isScanning {
                EmptyState(
                    icon: "network",
                    title: "No active ports found",
                    subtitle: "No listening ports"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        // Header row
                        HStack(spacing: 0) {
                            Text("PORT")
                                .frame(width: 70, alignment: .leading)
                            Text("PID")
                                .frame(width: 60, alignment: .leading)
                            Text("PROCESS")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("PROTOCOL")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)

                        ForEach(vm.ports) { port in
                            PortRow(port: port) {
                                Task { await vm.killProcess(pid: port.pid) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - SSH

    private var sshList: some View {
        Group {
            if vm.sshConnections.isEmpty && !vm.isScanning {
                EmptyState(
                    icon: "lock.shield",
                    title: "No active SSH connections",
                    subtitle: "No SSH connections found"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(vm.sshConnections) { conn in
                            SSHRow(connection: conn) {
                                Task { await vm.killProcess(pid: conn.pid) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Port Row

struct PortRow: View {
    let port: PortInfo
    let onKill: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Port number
            Text(":\(port.port)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(portColor)
                .frame(width: 70, alignment: .leading)

            // PID
            Text("\(port.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            // Process name
            VStack(alignment: .leading, spacing: 1) {
                Text(port.processName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                if !port.command.isEmpty && port.command != port.processName {
                    Text(port.command)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Protocol
            Text(port.proto)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1), in: Capsule())
                .frame(width: 50)

            // Kill button
            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("Kill process (PID: \(port.pid))")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.03) : .clear)
        )
        .onHover { isHovered = $0 }
    }

    private var portColor: Color {
        let p = port.port
        if p < 1024 { return .orange }
        if [3000, 3001, 4000, 5173, 8080, 8000].contains(p) { return .green }
        return .blue
    }
}

// MARK: - SSH Row

struct SSHRow: View {
    let connection: SSHConnection
    let onKill: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(connection.isOutgoing ? Color.green.opacity(0.12) : Color.blue.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: connection.isOutgoing ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: 11))
                    .foregroundStyle(connection.isOutgoing ? .green : .blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(connection.host)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))

                    if connection.port != 22 {
                        Text(":\(connection.port)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(connection.isOutgoing ? "Giden" : "Gelen")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(connection.isOutgoing ? .green : .blue)

                    Text("PID: \(connection.pid)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    if !connection.user.isEmpty {
                        Text(connection.user)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(connection.state)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(connection.state == "ESTABLISHED" ? .green : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08), in: Capsule())

            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.03) : .clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Models

enum NetworkTab {
    case ports, ssh
}

struct PortInfo: Identifiable {
    let id = UUID()
    let port: Int
    let pid: Int
    let processName: String
    let command: String
    let proto: String
}

struct SSHConnection: Identifiable {
    let id = UUID()
    let host: String
    let port: Int
    let pid: Int
    let user: String
    let state: String
    let isOutgoing: Bool
}

// MARK: - Network Scanner (nonisolated, background thread)

enum NetworkScanner {
    static func runCommand(_ path: String, args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func scanPorts() -> [PortInfo] {
        let output = runCommand("/usr/sbin/lsof", args: ["-iTCP", "-sTCP:LISTEN", "-nP", "-Fn", "-Fp", "-Fc"])
        guard !output.isEmpty else { return [] }

        var results: [PortInfo] = []
        var currentPid = 0
        var currentName = ""
        var currentCommand = ""

        for line in output.split(separator: "\n") {
            let str = String(line)
            if str.hasPrefix("p") {
                currentPid = Int(str.dropFirst()) ?? 0
            } else if str.hasPrefix("c") {
                currentCommand = String(str.dropFirst())
                currentName = currentCommand
            } else if str.hasPrefix("n") {
                let addr = String(str.dropFirst())
                if let colonIdx = addr.lastIndex(of: ":") {
                    let portStr = String(addr[addr.index(after: colonIdx)...])
                    if let port = Int(portStr) {
                        results.append(PortInfo(
                            port: port,
                            pid: currentPid,
                            processName: currentName,
                            command: currentCommand,
                            proto: "TCP"
                        ))
                    }
                }
            }
        }

        var seen = Set<Int>()
        return results.filter { seen.insert($0.port).inserted }
            .sorted { $0.port < $1.port }
    }

    static func scanSSH() -> [SSHConnection] {
        let output = runCommand("/usr/sbin/lsof", args: ["-i", ":22", "-nP", "-Fn", "-Fp", "-Fc"])
        guard !output.isEmpty else { return [] }

        var results: [SSHConnection] = []
        var currentPid = 0
        var currentName = ""

        for line in output.split(separator: "\n") {
            let str = String(line)
            if str.hasPrefix("p") {
                currentPid = Int(str.dropFirst()) ?? 0
            } else if str.hasPrefix("c") {
                currentName = String(str.dropFirst())
            } else if str.hasPrefix("n") {
                let addr = String(str.dropFirst())
                if addr.contains("->") {
                    let parts = addr.split(separator: "->")
                    let remote = String(parts.last ?? "")
                    let host: String
                    let port: Int
                    if let colonIdx = remote.lastIndex(of: ":") {
                        host = String(remote[..<colonIdx])
                        port = Int(String(remote[remote.index(after: colonIdx)...])) ?? 22
                    } else {
                        host = remote
                        port = 22
                    }

                    results.append(SSHConnection(
                        host: host,
                        port: port,
                        pid: currentPid,
                        user: "",
                        state: "ESTABLISHED",
                        isOutgoing: currentName == "ssh"
                    ))
                }
            }
        }

        let sshOutput = runCommand("/bin/ps", args: ["-eo", "pid,command"])
        for line in sshOutput.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("ssh ") && !trimmed.contains("grep") && !trimmed.contains("ps -eo") else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            if results.contains(where: { $0.pid == pid }) { continue }

            let cmdParts = String(parts[1]).split(separator: " ")
            if let hostPart = cmdParts.last {
                results.append(SSHConnection(
                    host: String(hostPart),
                    port: 22,
                    pid: pid,
                    user: "",
                    state: "ACTIVE",
                    isOutgoing: true
                ))
            }
        }

        return results
    }
}

// MARK: - ViewModel

@MainActor
final class NetworkViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var sshConnections: [SSHConnection] = []
    @Published var isScanning = false
    @Published var selectedTab: NetworkTab = .ports

    func scan() async {
        isScanning = true
        let (p, s) = await Task.detached {
            (NetworkScanner.scanPorts(), NetworkScanner.scanSSH())
        }.value
        ports = p
        sshConnections = s
        isScanning = false
    }

    func killProcess(pid: Int) async {
        await Task.detached {
            _ = NetworkScanner.runCommand("/bin/kill", args: ["-15", "\(pid)"])
        }.value
        try? await Task.sleep(for: .seconds(0.5))
        await scan()
    }
}
