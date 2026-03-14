import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var diskTimer: Timer?
    private let monitor = SystemMonitor()
    private var cachedDiskInfo: DiskSpaceInfo = .zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startDiskMonitor()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarDisplay(button: button)
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleMainWindow()
        }
    }

    // MARK: - Main Window

    private func toggleMainWindow() {
        if let window = mainWindow, window.isVisible {
            window.close()
        } else {
            openMainWindow()
        }
    }

    private func openMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DevCleaner"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 650, height: 450)
            window.contentView = NSHostingView(rootView: MainView())
            window.center()

            // Vibrancy
            window.isOpaque = false
            window.backgroundColor = .clear

            mainWindow = window
        }

        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        let freeGB = Double(cachedDiskInfo.freeBytes) / 1_073_741_824
        let diskText = String(format: "Disk: %.1f GB bos", freeGB)
        menu.addItem(NSMenuItem(title: diskText, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "DevCleaner Ac", action: #selector(openFromMenu), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Cikis", action: #selector(quitApp), keyEquivalent: "q")
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
        }

        button.attributedTitle = attrStr
    }
}
