# DevCleaner

[![build](https://github.com/canakyuz/DevCleaner/actions/workflows/build.yml/badge.svg)](https://github.com/canakyuz/DevCleaner/actions/workflows/build.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![platform](https://img.shields.io/badge/macOS-14.0%2B-lightgrey.svg)](#requirements)

A native macOS menubar app that reclaims disk space from developer tooling. It knows where Xcode, npm, Gradle, cargo, Docker and the AI CLIs hide their caches, shows you what each one costs, and lets you clear them with a risk label attached.

Built with Swift and SwiftUI. No Electron, no web views.

## Screenshots

<!--
TODO: add real captures before the first release.
Suggested set, 2x Retina, light and dark:
  docs/screenshots/dashboard.png     Dashboard with disk and RAM gauges
  docs/screenshots/smart-clean.png   Smart Clean grouped target list
  docs/screenshots/disk-map.png      Disk Map treemap
  docs/screenshots/menubar.png       Menubar popover
-->

_Not captured yet._

## Install

### Download

Grab the latest `.dmg` from [Releases](https://github.com/canakyuz/DevCleaner/releases), drag `DevCleaner.app` into `/Applications`.

The build is signed to run locally rather than notarized, so the first launch needs a right click on the app, then **Open**, then **Open** again in the dialog. macOS remembers the choice.

### Build from source

```bash
brew install xcodegen

git clone https://github.com/canakyuz/DevCleaner.git
cd DevCleaner/app
xcodegen generate
xcodebuild -project DevCleaner.xcodeproj \
  -scheme DevCleaner \
  -configuration Release \
  -derivedDataPath build \
  build

cp -R build/Build/Products/Release/DevCleaner.app /Applications/
```

`app/setup.sh` runs the same sequence.

## What it cleans

**101 targets across 15 groups.** Every target carries a real path, a measured size, and a risk level.

| Group | Covers |
|---|---|
| Xcode | DerivedData, Archives, DeviceSupport, CoreSimulator, CocoaPods, Carthage, SwiftPM |
| JS / Node | npm, yarn, pnpm, bun caches, `node_modules` by age with active projects protected |
| AI / CLI | Claude, Cursor, Copilot, Dia caches and old versions |
| IDE | JetBrains caches and logs, VSCode, Zed, nvim |
| Terminal | Warp, tabby |
| Python | pip, uv, mypy, ruff, prisma, pre-commit |
| Java / Android | Gradle caches and wrappers, Maven, Android SDK, emulators, AVDs |
| Ruby | bundler cache, gem cache |
| Rust | cargo registry, cargo git, rustup toolchains |
| Go | module cache, build cache |
| DevTools | Homebrew, Docker, Trunk, Expo, Terraform |
| Browser | Chrome, Edge, Safari, Firefox, Brave |
| Apps | Spotify, Slack, Zoom, Discord, Telegram |
| Downloads | stale installers and disk images |
| System | Trash, user logs, crash reports, saved application state |

Risk levels are `Safe`, `Caution` and `Risky`. **Select all** picks everything; **Select safe** picks only the `Safe` tier, which is the sensible default for an unattended clean.

## Features

**Dashboard.** Live disk and RAM gauges, memory pressure indicator, cleanup history with totals.

**Smart Clean.** The 101 targets above, grouped and collapsible. Each row shows a proportional size bar, the risk badge, and the full path on hover. Select or deselect a whole group in one click.

**Disk Map.** Treemap of what is actually taking the space, so you can find the offender before deciding what to delete.

**Large File Finder.** Scans Downloads, Documents, Desktop, Movies and Library. Configurable floor from 50 MB to 1 GB, file type detection, reveal in Finder, bulk delete.

**App Manager.** Every installed app with its real footprint broken into bundle, cache and app data. Clean an app's cache, or uninstall it with its leftovers moved to Trash.

**RAM Optimizer.** Active, Wired, Compressed, Inactive and Free in a stacked bar, plus a one click purge of inactive memory.

**Startup Manager.** Login items and launch agents, with the ability to disable them.

**Network.** Live throughput, also surfaced in the menubar.

**Menubar.** The common case never needs the main window. Free disk space sits in the bar, colour coded. Left click opens a 300pt popover with live disk and RAM gauges, and one button that runs the whole loop in place: scan, see how much is reclaimable, clean, see how much came back. Right click gives a plain menu with the same quick actions.

The popover only ever cleans `Safe` targets, meaning caches the owning tool regenerates on its own. `Caution` and `Risky` items are deliberately not reachable from the menubar; they need the full window where the path and the size are in front of you before you delete anything. That boundary is the point of the split, not a limitation of the popover.

## How it works

**Sizing shells out to `du -sk` on purpose.** `FileManager` directory enumeration walks every inode from userspace, which is slow on trees like `DerivedData` or `~/.gradle` that hold hundreds of thousands of small files. `du` does the same walk in one process with far less overhead. The trade is a `Process` spawn per target, which is why the next point matters.

**Targets are scanned concurrently.** `scanAll` fans every target out through a Swift `TaskGroup` and collects results into a map keyed by target id, so total scan time is bounded by the slowest single target rather than their sum.

**Services are actors.** Scanning and cleanup are thread safe by construction rather than by convention.

**The app is not sandboxed.** Reading and deleting caches across the whole home directory is the entire point, and the sandbox forbids it.

**Deletion goes through Trash where it can.** App uninstall moves the bundle and its leftovers to Trash rather than unlinking them, so a mistake is recoverable.

**A failed target does not abort the run.** Quick clean walks its target list and skips anything that throws, so one locked cache cannot strand the other hundred.

## CLI

A standalone bash script is included for terminal use, with no dependency on the app.

```bash
./cleanup.sh                 # interactive
./cleanup.sh --dry-run       # preview only, deletes nothing
./cleanup.sh --min-size 100M # ignore anything smaller
./cleanup.sh --auto          # non interactive
./cleanup.sh --json-log      # write a log of what was removed
```

## Architecture

```
app/Sources/
  App/                   Entry point, menubar, window lifecycle
  Core/
    Models/              CleanupTarget, CategoryRegistry, SystemInfo
    Services/            DiskScanner, CleanupService, SystemMonitor,
                         AppManagerService, LargeFileScanner
  Features/
    Dashboard/           Gauges and system overview
    SmartClean/          Target list, selection, cleanup
    DiskMap/             Treemap
    LargeFiles/          Large file finder
    AppManager/          Uninstaller and per app cache cleaning
    RAM/                 Memory breakdown and purge
    Startup/             Login items and launch agents
    Network/             Throughput
    Popover/             Menubar popover
  Shared/Components/     Gauges, bars, badges
  Navigation/            Sidebar and routing
```

Roughly 4,700 lines of Swift. The target list lives in one place, `CategoryRegistry.allTargets()`, so adding a cache means adding a line.

## Requirements

macOS 14.0 or later. Building additionally needs Xcode 15 or later and XcodeGen.

## Contributing

New cache targets are the most useful contribution. Add a `t(group, label, path, risk)` entry to `CategoryRegistry.allTargets()` in `app/Sources/Core/Models/CleanupTarget.swift`, and pick the risk level conservatively: `Safe` means the tool that owns it will transparently regenerate it.

Bug reports should say which macOS version, which target, and what was expected.

## License

MIT. See [LICENSE](./LICENSE).
