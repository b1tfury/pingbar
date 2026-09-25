import AppKit
import PingBarCore
import ServiceManagement

/// Owns the NSStatusItem and its dropdown menu. Must be used on the main thread.
final class StatusBarController: NSObject {
    private let item: NSStatusItem
    private let monitor: LatencyMonitor
    private let settings: Settings

    private let targetInfo = NSMenuItem(title: "Target: —", action: nil, keyEquivalent: "")
    private let statsInfo = NSMenuItem(title: "Waiting for first ping…", action: nil, keyEquivalent: "")
    private let intervalMenu = NSMenu()
    private let targetMenu = NSMenu()
    private let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    init(monitor: LatencyMonitor, settings: Settings) {
        self.monitor = monitor
        self.settings = settings
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        item.button?.attributedTitle = Self.title(dot: .systemGray, text: "…")
        item.menu = buildMenu()

        monitor.onUpdate = { [weak self] snap in self?.render(snap) }
    }

    // MARK: - Rendering

    private func render(_ snap: Snapshot) {
        let color: NSColor
        switch snap.status {
        case .green: color = .systemGreen
        case .yellow: color = .systemYellow
        case .red: color = .systemRed
        }

        let text: String
        switch snap.latest {
        case .rtt(let t): text = "\(Int((t * 1000).rounded()))ms"
        case .timeout: text = "--"
        case .error: text = "!"
        }
        item.button?.attributedTitle = Self.title(dot: color, text: text)

        if case .error(let msg) = snap.latest {
            item.button?.toolTip = "PingBar error: \(msg)"
        } else {
            item.button?.toolTip = "PingBar — \(snap.host)"
        }

        let targetName = Target.named(host: snap.host)?.name ?? snap.host
        let viaFallback = snap.host != settings.primary.host
        targetInfo.title = "Target: \(snap.host) (\(targetName))" + (viaFallback ? " · fallback" : "")

        if let avg = snap.avg, let mn = snap.min, let mx = snap.max {
            statsInfo.title = String(
                format: "Last minute: avg %d / min %d / max %d ms · loss %.0f%%",
                Int((avg * 1000).rounded()), Int((mn * 1000).rounded()), Int((mx * 1000).rounded()), snap.lossPercent
            )
        } else {
            statsInfo.title = String(format: "Last minute: no replies · loss %.0f%%", snap.lossPercent)
        }
    }

    private static func title(dot: NSColor, text: String) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let s = NSMutableAttributedString(string: "●", attributes: [.foregroundColor: dot, .font: font])
        s.append(NSAttributedString(string: " \(text)", attributes: [.font: font]))
        return s
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        targetInfo.isEnabled = false
        statsInfo.isEnabled = false
        menu.addItem(targetInfo)
        menu.addItem(statsInfo)
        menu.addItem(.separator())

        let intervalItem = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
        for s in Settings.allowedIntervals {
            let mi = NSMenuItem(title: "\(Int(s)) s", action: #selector(pickInterval(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = s
            intervalMenu.addItem(mi)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        let targetItem = NSMenuItem(title: "Target", action: nil, keyEquivalent: "")
        for t in Target.all {
            let mi = NSMenuItem(title: "\(t.name) \(t.host)", action: #selector(pickTarget(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = t.host
            targetMenu.addItem(mi)
        }
        targetItem.submenu = targetMenu
        menu.addItem(targetItem)

        launchAtLogin.target = self
        menu.addItem(launchAtLogin)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit PingBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        refreshChecks()
        return menu
    }

    private func refreshChecks() {
        for mi in intervalMenu.items {
            mi.state = (mi.representedObject as? TimeInterval) == settings.interval ? .on : .off
        }
        for mi in targetMenu.items {
            mi.state = (mi.representedObject as? String) == settings.primary.host ? .on : .off
        }
        if Self.runningFromBundle {
            launchAtLogin.isEnabled = true
            launchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
            launchAtLogin.toolTip = nil
        } else {
            launchAtLogin.isEnabled = false
            launchAtLogin.state = .off
            launchAtLogin.toolTip = "Available when running PingBar.app (make app)"
        }
    }

    private static var runningFromBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    // MARK: - Actions

    @objc private func pickInterval(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? TimeInterval else { return }
        monitor.setInterval(s)
        refreshChecks()
    }

    @objc private func pickTarget(_ sender: NSMenuItem) {
        guard let host = sender.representedObject as? String, let t = Target.named(host: host) else { return }
        monitor.setTarget(t)
        refreshChecks()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("PingBar: launch at login toggle failed: \(error)")
        }
        refreshChecks()
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshChecks()
    }
}
