# DevCleaner

A native macOS menubar app for developers to reclaim disk space by cleaning caches, managing apps, optimizing RAM, and finding large files.

Built with **Swift + SwiftUI**. No Electron. No web views. Pure native performance.

## Features

### Dashboard
- Real-time disk and RAM gauges
- Memory pressure indicator
- Cleanup history with stats

### Smart Clean (90+ targets)
- **Xcode**: DerivedData, Simulators, CocoaPods, SPM cache
- **JS/Node**: npm, yarn, pnpm, bun, node_modules (age-based, active projects protected)
- **AI/CLI**: Claude, Cursor, Copilot, Dia caches and versions
- **IDE**: JetBrains, VSCode, Zed, nvim
- **Terminal**: Warp, tabby
- **Python**: pip, uv, mypy, ruff, prisma, pre-commit
- **Java/Android**: Gradle, Maven, Android SDK, emulators, AVDs
- **Rust/Go**: cargo, rustup, go mod/build cache
- **DevTools**: Homebrew, Docker, Trunk, Expo, Terraform
- **Browser**: Chrome, Edge, Safari, Firefox, Brave caches
- **Apps**: Spotify, Slack, Zoom, Discord, Telegram caches
- **System**: Trash, logs, crash reports, saved states

Each target shows:
- Size with proportional bar
- Risk level (safe / caution)
- Hover tooltip with full path
- Group select/deselect

### Large File Finder
- Scans Downloads, Documents, Desktop, Movies, Library
- Configurable minimum size (50MB - 1GB)
- File type detection (video, image, archive, disk image, etc.)
- Reveal in Finder
- Bulk delete selected

### App Manager
- Lists all installed apps with sizes
- Breakdown: bundle size + cache + app data
- Per-app cache cleaning
- Full uninstall (app + leftover data moved to Trash)
- Search and sort by size

### RAM Optimizer
- Real-time memory breakdown (Active, Wired, Compressed, Inactive, Free)
- Stacked visualization bar
- Memory pressure indicator
- One-click RAM optimization (purges inactive memory)

### Menubar
- Live disk free space display (color-coded)
- Left click: open main window
- Right click: quick actions menu

## Requirements

- macOS 14.0+
- Xcode 15+ (for building)

## Build

```bash
# Install XcodeGen (if not installed)
brew install xcodegen

# Generate project and build
cd app
xcodegen generate
xcodebuild -project DevCleaner.xcodeproj \
  -scheme DevCleaner \
  -configuration Release \
  -derivedDataPath build \
  build

# Install
cp -R build/Build/Products/Release/DevCleaner.app /Applications/
```

Or use the setup script:

```bash
cd app
./setup.sh
```

## CLI Version

A bash script (`cleanup.sh`) is also included for terminal usage:

```bash
./cleanup.sh                    # Interactive mode
./cleanup.sh --dry-run          # Preview only
./cleanup.sh --min-size 100M    # Filter by size
./cleanup.sh --auto             # Clean everything
./cleanup.sh --json-log         # Save cleanup log
```

## Architecture

```
Sources/
  App/                     # Entry point, menubar, window
  Core/
    Models/                # CleanupTarget, AppInfo, SystemInfo
    Services/              # DiskScanner, CleanupService, SystemMonitor,
                           # AppManagerService, LargeFileScanner
  Features/
    Dashboard/             # System overview with gauges
    SmartClean/            # Cache cleaner (90+ targets)
    LargeFiles/            # Large file finder
    AppManager/            # App uninstaller + cache cleaner
    RAM/                   # Memory optimizer
  Shared/
    Components/            # Reusable UI (gauges, bars, badges)
  Navigation/              # Sidebar + routing
```

Key design decisions:
- **Parallel scanning**: All targets scanned concurrently via Swift `TaskGroup`
- **Actor-based services**: Thread-safe scanning and cleanup
- **FileManager native**: No shell commands for disk scanning
- **No sandbox**: Full filesystem access (required for cleanup)

## License

MIT
