import SwiftUI

@main
struct StockTickerApp: App {
    @StateObject private var menuBarController = MenuBarController()

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
