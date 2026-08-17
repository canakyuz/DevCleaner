import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var mainWindow: NSWindow?
    private var diskTimer: Timer?
    private var eventMonitor: Any?
    private let monitor = SystemMonitor()
    private var cachedDiskInfo: DiskSpaceInfo = .zero
    private var cachedPortCount: Int = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
        startDiskMonitor()
        setupEventMonitor()
    }

    // MARK: - Menubar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarDisplay(button: button)
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 360)
        let hostingController = NSHostingController(
            rootView: PopoverView { [weak self] in
                self?.closePopoverAndOpenWindow()
            }
            .preferredColorScheme(.dark)
        )
        popover.contentViewController = hostingController
        self.popover = popover
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopoverAndOpenWindow() {
        popover?.performClose(nil)
        openMainWindow()
    }

    // MARK: - Event Monitor (click outside closes popover)

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                if let popover = self?.popover, popover.isShown {
                    popover.performClose(nil)
                }
            }
        }
    }

    // MARK: - Main Window

    private func openMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DevCleaner"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 680, height: 480)
            window.contentView = NSHostingView(rootView: MainView())
            window.center()
            window.isOpaque = true
            window.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0)
            window.appearance = NSAppearance(named: .darkAqua)
            mainWindow = window
        }

        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        let freeGB = Double(cachedDiskInfo.freeBytes) / 1_073_741_824
        let diskText = String(format: "Disk: %.1f GB free", freeGB)
        menu.addItem(NSMenuItem(title: diskText, action: nil, keyEquivalent: ""))

        let portText = "Network: \(cachedPortCount) aktif port"
        menu.addItem(NSMenuItem(title: portText, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Full Window", action: #selector(openFromMenu), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openFromMenu() {
        openMainWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Disk Monitor

    private func startDiskMonitor() {
        updateDiskDisplay()
        diskTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDiskDisplay()
            }
        }
    }

    private func updateDiskDisplay() {
        Task {
            cachedDiskInfo = await monitor.getDiskInfo()
            cachedPortCount = await Task.detached {
                NetworkScanner.scanPorts().count
            }.value
            if let button = statusItem?.button {
                updateMenuBarDisplay(button: button)
            }
        }
    }

    private func updateMenuBarDisplay(button: NSStatusBarButton) {
        let freeGB = Double(cachedDiskInfo.freeBytes) / 1_073_741_824
        let usedPercent = cachedDiskInfo.usedPercent

        let attachment = NSTextAttachment()
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if let image = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            attachment.image = image
        }

        let attrStr = NSMutableAttributedString()
        attrStr.append(NSAttributedString(attachment: attachment))

        if cachedDiskInfo.totalBytes > 0 {
            let sizeText: String
            if freeGB < 10 {
                sizeText = String(format: " %.1fGB", freeGB)
            } else {
                sizeText = String(format: " %.0fGB", freeGB)
            }

            let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: usedPercent > 90 ? .bold : .regular)
            let color: NSColor = usedPercent > 95 ? .systemRed : usedPercent > 85 ? .systemOrange : .labelColor
            attrStr.append(NSAttributedString(
                string: sizeText,
                attributes: [.font: font, .foregroundColor: color]
            ))

            if cachedPortCount > 0 {
                let portFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
                attrStr.append(NSAttributedString(
                    string: " \(cachedPortCount)P",
                    attributes: [.font: portFont, .foregroundColor: NSColor.systemCyan]
                ))
            }
        }

        button.attributedTitle = attrStr
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
