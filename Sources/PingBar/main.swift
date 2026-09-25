import AppKit
import PingBarCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var monitor: LatencyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings()
        let monitor = LatencyMonitor(settings: settings)
        statusBar = StatusBarController(monitor: monitor, settings: settings)
        self.monitor = monitor
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }
}

let app = NSApplication.shared
// .accessory = no Dock icon, no main menu. Works even without LSUIElement (e.g. `swift run`).
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
