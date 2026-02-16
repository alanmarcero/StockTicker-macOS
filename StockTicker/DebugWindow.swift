import SwiftUI
import AppKit

// MARK: - Constants (referencing centralized LayoutConfig)

private enum DebugWindowSize {
    static let width: CGFloat = LayoutConfig.DebugWindow.width
    static let height: CGFloat = LayoutConfig.DebugWindow.height
    static let minWidth: CGFloat = LayoutConfig.DebugWindow.minWidth
    static let minHeight: CGFloat = LayoutConfig.DebugWindow.minHeight
}

private enum DebugTiming {
    static let refreshIntervalNanoseconds: UInt64 = 1_000_000_000  // 1 second
}

// MARK: - Debug View

struct DebugView: View {
    @StateObject private var viewModel = DebugViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            requestList
        }
        .frame(minWidth: DebugWindowSize.minWidth, minHeight: DebugWindowSize.minHeight)
        .onAppear {
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("API Requests (Last 60s)")
                    .font(.headline)
                if viewModel.errorCount > 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("\(viewModel.errorCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
                Spacer()
                Text("\(viewModel.entries.count) requests")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Button("Clear") {
                    viewModel.clear()
                }
                .buttonStyle(.borderless)
            }
            if let errorMessage = viewModel.lastErrorMessage {
                Text("Last error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private var requestList: some View {
        Group {
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                List(viewModel.entries) { entry in
                    RequestRowView(entry: entry)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No requests in the last 60 seconds")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Request Row View

struct RequestRowView: View {
    let entry: RequestLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.formattedTimestamp)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(entry.method)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.blue)

                Spacer()

                Text(entry.statusDescription)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(statusColor)

                Text(entry.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(entry.formattedSize)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: LayoutConfig.DebugWindow.statusColumnWidth, alignment: .trailing)
            }

            Text(entry.url.absoluteString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            copyButtons
        }
        .padding(.vertical, 6)
    }

    private var copyButtons: some View {
        HStack(spacing: 12) {
            Button {
                copyToClipboard(entry.url.absoluteString)
            } label: {
                Label("Copy URL", systemImage: "link")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Button {
                copyToClipboard(entry.copyableRequest)
            } label: {
                Label("Copy Request", systemImage: "arrow.up.doc")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Button {
                copyToClipboard(entry.copyableResponse)
            } label: {
                Label("Copy Response", systemImage: "arrow.down.doc")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var statusColor: Color {
        if entry.error != nil {
            return .red
        }
        guard let code = entry.statusCode else {
            return .secondary
        }
        switch code {
        case 200..<300: return .green
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .secondary
        }
    }
}

// MARK: - Debug View Model

@MainActor
class DebugViewModel: ObservableObject {
    @Published var entries: [RequestLogEntry] = []
    @Published var errorCount: Int = 0
    @Published var lastErrorMessage: String?
    private let logger: RequestLogger
    private var refreshTask: Task<Void, Never>?

    init(logger: RequestLogger = .shared) {
        self.logger = logger
    }

    func refresh() {
        Task {
            entries = await logger.getEntries()
            errorCount = await logger.getErrorCount()
            let lastError = await logger.getLastError()
            lastErrorMessage = lastError?.error ?? lastError.map { "HTTP \($0.statusCode ?? 0)" }
        }
    }

    func clear() {
        Task {
            await logger.clear()
            entries = []
            errorCount = 0
            lastErrorMessage = nil
        }
    }

    func startAutoRefresh() {
        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: DebugTiming.refreshIntervalNanoseconds)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.refresh()
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

// MARK: - Debug Window Controller

@MainActor
class DebugWindowController {
    private var window: NSWindow?

    func showWindow() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let debugView = DebugView()
        let hostingView = NSHostingView(rootView: debugView)
        hostingView.autoresizingMask = [.width, .height]

        let opaqueContainer = OpaqueContainerView(frame: NSRect(x: 0, y: 0, width: DebugWindowSize.width, height: DebugWindowSize.height))
        hostingView.frame = opaqueContainer.bounds
        opaqueContainer.addSubview(hostingView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: DebugWindowSize.width, height: DebugWindowSize.height),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "Debug - API Requests"
        newWindow.contentView = opaqueContainer
        newWindow.isOpaque = true
        newWindow.backgroundColor = .windowBackgroundColor
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }
}
