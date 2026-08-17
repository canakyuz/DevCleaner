import SwiftUI

// MARK: - Enums

enum TargetGroup: String, CaseIterable, Identifiable {
    case xcode = "Xcode"
    case jsNode = "JS / Node"
    case aiCli = "AI / CLI"
    case ide = "IDE"
    case terminal = "Terminal"
    case python = "Python"
    case javaAndroid = "Java / Android"
    case ruby = "Ruby"
    case rust = "Rust"
    case go = "Go"
    case devtools = "DevTools"
    case browser = "Browser"
    case app = "Apps"
    case downloads = "Downloads"
    case system = "System"
    case docker = "Docker"
    case nodeModules = "node_modules"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .xcode:        return "hammer.fill"
        case .jsNode:       return "cube.box.fill"
        case .aiCli:        return "brain"
        case .ide:          return "laptopcomputer"
        case .terminal:     return "terminal.fill"
        case .python:       return "chevron.left.forwardslash.chevron.right"
        case .javaAndroid:  return "cup.and.saucer.fill"
        case .ruby:         return "diamond.fill"
        case .rust:         return "gearshape.2.fill"
        case .go:           return "hare.fill"
        case .devtools:     return "wrench.and.screwdriver.fill"
        case .browser:      return "globe"
        case .app:          return "app.badge.fill"
        case .downloads:    return "arrow.down.circle.fill"
        case .system:       return "desktopcomputer"
        case .docker:       return "shippingbox.fill"
        case .nodeModules:  return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .xcode:        return .blue
        case .jsNode:       return .yellow
        case .aiCli:        return .purple
        case .ide:          return .cyan
        case .terminal:     return .green
        case .python:       return .blue
        case .javaAndroid:  return .orange
        case .ruby:         return .red
        case .rust:         return .brown
        case .go:           return .cyan
        case .devtools:     return .indigo
        case .browser:      return .teal
        case .app:          return .pink
        case .downloads:    return .mint
        case .system:       return .gray
        case .docker:       return .blue
        case .nodeModules:  return .yellow
        }
    }
}

enum Risk: String, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    var color: Color {
        switch self {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var label: String {
        switch self {
        case .low:    return "Safe"
        case .medium: return "Caution"
        case .high:   return "Risky"
        }
    }

    static func < (lhs: Risk, rhs: Risk) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum ScanType {
    case directory
    case glob
    case custom
}

// MARK: - CleanupTarget

struct CleanupTarget: Identifiable {
    let id = UUID()
    let group: TargetGroup
    let label: String
    let path: String
    let type: ScanType
    let risk: Risk
    var sizeBytes: Int64 = 0
    var isSelected: Bool = false

    var isAvailable: Bool { sizeBytes > 0 }
}

// MARK: - Category Registry

struct CategoryRegistry {
    static let home = FileManager.default.homeDirectoryForCurrentUser.path

    static func allTargets() -> [CleanupTarget] {
        let h = home
        return [
            // Xcode
            t(.xcode, "DerivedData", "\(h)/Library/Developer/Xcode/DerivedData", .low),
            t(.xcode, "Archives", "\(h)/Library/Developer/Xcode/Archives", .low),
            t(.xcode, "iOS DeviceSupport", "\(h)/Library/Developer/Xcode/iOS DeviceSupport", .low),
            t(.xcode, "watchOS DeviceSupport", "\(h)/Library/Developer/Xcode/watchOS DeviceSupport", .low),
            t(.xcode, "Previews Cache", "\(h)/Library/Developer/Xcode/UserData/Previews", .low),
            t(.xcode, "Xcode Cache", "\(h)/Library/Caches/com.apple.dt.Xcode", .low),
            t(.xcode, "CoreSimulator Caches", "\(h)/Library/Developer/CoreSimulator/Caches", .low),
            t(.xcode, "CoreSimulator Devices", "\(h)/Library/Developer/CoreSimulator/Devices", .medium),
            t(.xcode, "CocoaPods Cache", "\(h)/Library/Caches/CocoaPods", .low),
            t(.xcode, "Carthage Cache", "\(h)/Library/Caches/org.carthage.CarthageKit", .low),
            t(.xcode, "Swift Package Cache", "\(h)/Library/Caches/org.swift.swiftpm", .low),

            // JS/Node
            t(.jsNode, "npm cache", "\(h)/.npm", .low),
            t(.jsNode, "pnpm store", "\(h)/.pnpm-store", .low),
            t(.jsNode, "pnpm store (Library)", "\(h)/Library/pnpm/store", .low),
            t(.jsNode, "yarn cache", "\(h)/Library/Caches/Yarn", .low),
            t(.jsNode, "bun install cache", "\(h)/.bun/install/cache", .low),
            t(.jsNode, "node-gyp cache", "\(h)/Library/Caches/node-gyp", .low),
            t(.jsNode, "node cache", "\(h)/.cache/node", .low),
            t(.jsNode, "tsx cache", "\(h)/.cache/tsx", .low),
            t(.jsNode, "turbo cache", "\(h)/.cache/turbo", .low),
            t(.jsNode, "metro cache", "\(h)/.cache/metro", .low),

            // AI/CLI
            t(.aiCli, "Claude Code versions", "\(h)/.local/share/claude/versions", .low),
            t(.aiCli, "Claude downloads", "\(h)/.claude/downloads", .low),
            t(.aiCli, "Claude shell-snapshots", "\(h)/.claude/shell-snapshots", .low),
            t(.aiCli, "Claude debug logs", "\(h)/.claude/debug", .low),
            t(.aiCli, "Claude telemetry", "\(h)/.claude/telemetry", .low),
            t(.aiCli, "Claude file-history", "\(h)/.claude/file-history", .low),
            t(.aiCli, "Claude plugins", "\(h)/.claude/plugins", .medium),
            t(.aiCli, "Claude App Support", "\(h)/Library/Application Support/Claude", .medium),
            t(.aiCli, "Cursor extensions", "\(h)/.cursor/extensions", .low),
            t(.aiCli, "Cursor worktrees", "\(h)/.cursor/worktrees", .low),
            t(.aiCli, "Copilot cache", "\(h)/.cache/github-copilot", .low),
            t(.aiCli, "OpenCode data", "\(h)/.local/share/opencode", .low),
            t(.aiCli, "chrome-devtools-mcp", "\(h)/.cache/chrome-devtools-mcp", .low),
            t(.aiCli, "Dia App Support", "\(h)/Library/Application Support/Dia", .medium),
            t(.aiCli, "Dia Cache", "\(h)/Library/Caches/Dia", .low),

            // IDE
            tg(.ide, "JetBrains App Data", "\(h)/Library/Application Support/JetBrains", .low),
            tg(.ide, "JetBrains Caches", "\(h)/Library/Caches/JetBrains", .low),
            tg(.ide, "JetBrains Logs", "\(h)/Library/Logs/JetBrains", .low),
            t(.ide, "VSCode extensions", "\(h)/.vscode/extensions", .low),
            t(.ide, "VSCode Cache", "\(h)/Library/Caches/com.microsoft.VSCode", .low),
            t(.ide, "Zed Cache", "\(h)/Library/Caches/dev.zed.Zed", .low),
            t(.ide, "Zed App Data", "\(h)/Library/Application Support/Zed", .medium),
            t(.ide, "nvim data", "\(h)/.local/share/nvim", .low),
            t(.ide, "nvim cache", "\(h)/.cache/nvim", .low),

            // Terminal
            t(.terminal, "Warp App Data", "\(h)/Library/Application Support/dev.warp.Warp-Stable", .medium),
            t(.terminal, "Warp Cache", "\(h)/Library/Caches/dev.warp.Warp-Stable", .low),
            t(.terminal, "Warp Group Data", "\(h)/Library/Group Containers/group.dev.warp.Warp-Stable.SharedContainer", .low),
            t(.terminal, "tabby data", "\(h)/Library/Application Support/tabby", .low),

            // Python
            t(.python, "pip cache", "\(h)/Library/Caches/pip", .low),
            t(.python, "uv cache", "\(h)/.cache/uv", .low),
            t(.python, "uv data", "\(h)/.local/share/uv", .low),
            t(.python, "mypy cache", "\(h)/.cache/mypy", .low),
            t(.python, "ruff cache", "\(h)/.cache/ruff", .low),
            t(.python, "pre-commit cache", "\(h)/.cache/pre-commit", .low),
            t(.python, "Prisma engines", "\(h)/.cache/prisma", .low),

            // Java/Android
            t(.javaAndroid, "Gradle caches", "\(h)/.gradle/caches", .low),
            t(.javaAndroid, "Gradle wrapper", "\(h)/.gradle/wrapper", .low),
            t(.javaAndroid, "Maven repository", "\(h)/.m2/repository", .low),
            t(.javaAndroid, "Android SDK images", "\(h)/Library/Android/sdk/system-images", .medium),
            t(.javaAndroid, "Android NDK", "\(h)/Library/Android/sdk/ndk", .medium),
            t(.javaAndroid, "Android emulator", "\(h)/Library/Android/sdk/emulator", .medium),
            t(.javaAndroid, "Android cache", "\(h)/.android/cache", .low),
            t(.javaAndroid, "Android AVD", "\(h)/.android/avd", .medium),

            // Ruby
            t(.ruby, "gem cache", "\(h)/.gem/cache", .low),
            t(.ruby, "bundler cache", "\(h)/.bundle/cache", .low),

            // Rust
            t(.rust, "cargo registry", "\(h)/.cargo/registry", .low),
            t(.rust, "cargo git", "\(h)/.cargo/git", .low),
            t(.rust, "rustup toolchains", "\(h)/.rustup/toolchains", .medium),

            // Go
            t(.go, "go mod cache", "\(h)/go/pkg/mod", .low),
            t(.go, "go build cache", "\(h)/.cache/go-build", .low),

            // DevTools
            t(.devtools, "Homebrew Cache", "\(h)/Library/Caches/Homebrew", .low),
            t(.devtools, "Docker Desktop", "\(h)/Library/Containers/com.docker.docker", .medium),
            t(.devtools, "Trunk cache", "\(h)/.cache/trunk", .low),
            t(.devtools, "Expo cache", "\(h)/.cache/expo", .low),
            t(.devtools, "Hoppscotch", "\(h)/Library/Application Support/io.hoppscotch.desktop", .low),
            t(.devtools, "Navicat", "\(h)/Library/Application Support/PremiumSoft CyberTech", .medium),
            t(.devtools, "herd-lite", "\(h)/.config/herd-lite", .low),

            // Browser
            t(.browser, "Edge Updater", "\(h)/Library/Application Support/Microsoft/EdgeUpdater", .low),
            t(.browser, "Edge Cache", "\(h)/Library/Caches/Microsoft Edge", .low),
            t(.browser, "Edge SW Cache", "\(h)/Library/Application Support/Microsoft Edge/Default/Service Worker/CacheStorage", .low),
            t(.browser, "Chrome Cache", "\(h)/Library/Caches/Google/Chrome", .low),
            t(.browser, "Chrome SW Cache", "\(h)/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage", .low),
            t(.browser, "Safari Cache", "\(h)/Library/Caches/com.apple.Safari", .low),
            t(.browser, "Firefox Cache", "\(h)/Library/Caches/Firefox", .low),
            t(.browser, "Brave Cache", "\(h)/Library/Caches/BraveSoftware", .low),
            t(.browser, "WebKit Cache", "\(h)/Library/WebKit", .low),
            t(.browser, "GeoServices", "\(h)/Library/Caches/GeoServices", .low),

            // App
            t(.app, "Spotify cache", "\(h)/Library/Caches/com.spotify.client", .low),
            t(.app, "Slack data", "\(h)/Library/Application Support/Slack", .medium),
            t(.app, "Zoom data", "\(h)/Library/Application Support/zoom.us", .low),
            t(.app, "Raycast data", "\(h)/Library/Application Support/com.raycast.macos", .medium),
            t(.app, "WhatsApp data", "\(h)/Library/Group Containers/group.net.whatsapp.WhatsApp.shared", .medium),
            t(.app, "Discord cache", "\(h)/Library/Application Support/discord", .low),
            t(.app, "Telegram cache", "\(h)/Library/Application Support/Telegram Desktop", .low),

            // System
            t(.system, "Trash", "\(h)/.Trash", .low),
            t(.system, "User Logs", "\(h)/Library/Logs", .low),
            t(.system, "CrashReporter", "\(h)/Library/Logs/DiagnosticReports", .low),
            t(.system, "Saved App State", "\(h)/Library/Saved Application State", .low),
            t(.system, "Music Artwork", "\(h)/Library/Containers/com.apple.AMPArtworkAgent", .low),
            t(.system, "CloudKit Cache", "\(h)/Library/Caches/CloudKit", .low),
            t(.system, "Wallpaper Cache", "\(h)/Library/Application Support/com.apple.wallpaper", .low),
        ]
    }

    private static func t(_ group: TargetGroup, _ label: String, _ path: String, _ risk: Risk) -> CleanupTarget {
        CleanupTarget(group: group, label: label, path: path, type: .directory, risk: risk)
    }

    private static func tg(_ group: TargetGroup, _ label: String, _ path: String, _ risk: Risk) -> CleanupTarget {
        CleanupTarget(group: group, label: label, path: path, type: .glob, risk: risk)
    }
}
