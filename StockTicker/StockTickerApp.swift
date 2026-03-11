import SwiftUI

@main
struct StockTickerApp: App {
    @StateObject private var menuBarController = MenuBarController()

    private static let knownBundleIDs = ["com.stonks.app", "com.stockticker.app"]

    init() {
        guard !ProcessInfo.processInfo.environment.keys.contains("XCTestConfigurationFilePath") else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let alreadyRunning = Self.knownBundleIDs.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }.contains { $0.processIdentifier != myPID }
        if alreadyRunning {
            NSApp.terminate(nil)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
