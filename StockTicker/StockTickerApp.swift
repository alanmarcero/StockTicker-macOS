import SwiftUI

@main
struct StockTickerApp: App {
    @StateObject private var menuBarController = MenuBarController()

    init() {
        guard !ProcessInfo.processInfo.environment.keys.contains("XCTestConfigurationFilePath") else { return }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.stonks"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            NSApp.terminate(nil)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
