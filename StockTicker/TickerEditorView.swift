import SwiftUI
import AppKit

// MARK: - Symbol Validator Protocol

protocol SymbolValidator: Sendable {
    func validate(_ symbol: String) async -> Bool
}

struct YahooSymbolValidator: SymbolValidator {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = LoggingHTTPClient()) {
        self.httpClient = httpClient
    }

    func validate(_ symbol: String) async -> Bool {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d"
        guard let url = URL(string: urlString) else { return false }

        do {
            let (data, response) = try await httpClient.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first,
                  result.meta.regularMarketPrice != nil else {
                return false
            }

            return true
        } catch {
            return false
        }
    }
}

// MARK: - Pure Watchlist Functions (Testable)

enum WatchlistOperations {
    static var maxWatchlistSize: Int { WatchlistConfig.maxWatchlistSize }

    static func normalize(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespaces).uppercased()
    }

    static func canAddSymbol(_ symbol: String, to symbols: [String]) -> SymbolAddResult {
        let normalized = normalize(symbol)

        guard !normalized.isEmpty else {
            return .invalid(reason: .empty)
        }

        guard symbols.count < maxWatchlistSize else {
            return .invalid(reason: .listFull)
        }

        guard !symbols.contains(normalized) else {
            return .invalid(reason: .duplicate)
        }

        return .canAdd(normalized: normalized)
    }

    static func addSymbol(_ symbol: String, to symbols: [String]) -> [String] {
        var result = symbols
        result.append(symbol)
        return result
    }

    static func removeSymbol(_ symbol: String, from symbols: [String]) -> [String] {
        symbols.filter { $0 != symbol }
    }

    static func sortAscending(_ symbols: [String]) -> [String] {
        symbols.sorted()
    }

    static func sortDescending(_ symbols: [String]) -> [String] {
        symbols.sorted(by: >)
    }

    static func hasChanges(current: [String], original: [String]) -> Bool {
        Set(current) != Set(original)
    }
}

enum SymbolAddResult: Equatable {
    case canAdd(normalized: String)
    case invalid(reason: SymbolAddError)
}

enum SymbolAddError: Equatable {
    case empty
    case listFull
    case duplicate
    case notFound(symbol: String)

    var message: String {
        switch self {
        case .empty:
            return "Please enter a symbol"
        case .listFull:
            return "Maximum \(WatchlistOperations.maxWatchlistSize) symbols allowed"
        case .duplicate:
            return "Symbol already in watchlist"
        case .notFound(let symbol):
            return "Invalid symbol: \(symbol) not found"
        }
    }
}

// MARK: - Editor State Protocol (For Testing)

@MainActor
protocol WatchlistEditorStateProtocol: ObservableObject {
    var symbols: [String] { get set }
    var newSymbol: String { get set }
    var isValidating: Bool { get }
    var validationError: String? { get }
    var sortAscending: Bool { get }
    var hasChanges: Bool { get }

    func save()
    func cancel()
    func validateAndAddSymbol()
    func removeSymbol(_ symbol: String)
    func sortSymbolsAscending()
    func sortSymbolsDescending()
}

// MARK: - Editor State (ObservableObject)

@MainActor
class WatchlistEditorState: ObservableObject, WatchlistEditorStateProtocol {
    @Published var symbols: [String]
    @Published var newSymbol: String = ""
    @Published var isValidating: Bool = false
    @Published var validationError: String? = nil
    @Published var sortAscending: Bool = true

    let originalSymbols: [String]
    private let validator: SymbolValidator
    private var onSaveCallback: (([String]) -> Void)?
    private var onCancelCallback: (() -> Void)?

    init(symbols: [String], validator: SymbolValidator = YahooSymbolValidator()) {
        self.symbols = WatchlistOperations.sortAscending(symbols)
        self.originalSymbols = symbols
        self.validator = validator
    }

    func setCallbacks(onSave: @escaping ([String]) -> Void, onCancel: @escaping () -> Void) {
        self.onSaveCallback = onSave
        self.onCancelCallback = onCancel
    }

    func clearCallbacks() {
        self.onSaveCallback = nil
        self.onCancelCallback = nil
    }

    var hasChanges: Bool {
        WatchlistOperations.hasChanges(current: symbols, original: originalSymbols)
    }

    func save() {
        let symbolsToSave = WatchlistOperations.sortAscending(symbols)
        let callback = onSaveCallback
        clearCallbacks()
        DispatchQueue.main.async {
            callback?(symbolsToSave)
        }
    }

    func cancel() {
        let callback = onCancelCallback
        clearCallbacks()
        callback?()
    }

    func validateAndAddSymbol() {
        let result = WatchlistOperations.canAddSymbol(newSymbol, to: symbols)

        switch result {
        case .invalid(let reason):
            validationError = reason.message
            return
        case .canAdd(let normalized):
            performValidation(for: normalized)
        }
    }

    private func performValidation(for symbol: String) {
        isValidating = true
        validationError = nil

        Task {
            let isValid = await validator.validate(symbol)
            await handleValidationResult(symbol: symbol, isValid: isValid)
        }
    }

    private func handleValidationResult(symbol: String, isValid: Bool) async {
        isValidating = false

        guard isValid else {
            validationError = SymbolAddError.notFound(symbol: symbol).message
            return
        }

        symbols = WatchlistOperations.addSymbol(symbol, to: symbols)
        newSymbol = ""
    }

    func removeSymbol(_ symbol: String) {
        symbols = WatchlistOperations.removeSymbol(symbol, from: symbols)
    }

    func sortSymbolsAscending() {
        sortAscending = true
        symbols = WatchlistOperations.sortAscending(symbols)
    }

    func sortSymbolsDescending() {
        sortAscending = false
        symbols = WatchlistOperations.sortDescending(symbols)
    }
}

// MARK: - Window Constants (referencing centralized LayoutConfig)

private enum WindowSize {
    static let defaultWidth: CGFloat = LayoutConfig.EditorWindow.defaultWidth
    static let defaultHeight: CGFloat = LayoutConfig.EditorWindow.defaultHeight
    static let minWidth: CGFloat = LayoutConfig.EditorWindow.minWidth
    static let minHeight: CGFloat = LayoutConfig.EditorWindow.minHeight
}

private enum WindowTiming {
    static let dismissDelaySeconds: TimeInterval = 0.1
}

// MARK: - Window Provider Protocol (For Testing)

protocol WindowProvider {
    func createWindow(contentRect: NSRect, styleMask: NSWindow.StyleMask) -> NSWindow
    func createHostingView<Content: View>(rootView: Content) -> NSView
    func activateApp()
}

struct AppKitWindowProvider: WindowProvider {
    func createWindow(contentRect: NSRect, styleMask: NSWindow.StyleMask) -> NSWindow {
        NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
    }

    func createHostingView<Content: View>(rootView: Content) -> NSView {
        let hostingView = NSHostingView(rootView: rootView)
        return hostingView
    }

    func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Window Controller

@MainActor
class WatchlistEditorWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var editorState: WatchlistEditorState?
    private let windowProvider: WindowProvider
    private let validatorFactory: () -> SymbolValidator

    init(
        windowProvider: WindowProvider = AppKitWindowProvider(),
        validatorFactory: @escaping () -> SymbolValidator = { YahooSymbolValidator() }
    ) {
        self.windowProvider = windowProvider
        self.validatorFactory = validatorFactory
        super.init()
    }

    func showEditor(currentWatchlist: [String], onSave: @escaping ([String]) -> Void) {
        cleanupExistingWindow()

        let state = createEditorState(watchlist: currentWatchlist, onSave: onSave)
        self.editorState = state

        let window = createAndConfigureWindow(with: state)
        self.window = window

        window.makeKeyAndOrderFront(nil)
        windowProvider.activateApp()
    }

    private func cleanupExistingWindow() {
        guard let existingWindow = window else { return }
        editorState?.clearCallbacks()
        editorState = nil
        existingWindow.orderOut(nil)
        window = nil
    }

    private func createEditorState(watchlist: [String], onSave: @escaping ([String]) -> Void) -> WatchlistEditorState {
        let state = WatchlistEditorState(symbols: watchlist, validator: validatorFactory())
        state.setCallbacks(
            onSave: { [weak self] newWatchlist in
                onSave(newWatchlist)
                self?.dismissWindowAfterDelay()
            },
            onCancel: { [weak self] in
                self?.dismissWindowAfterDelay()
            }
        )
        return state
    }

    private func dismissWindowAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + WindowTiming.dismissDelaySeconds) { [weak self] in
            self?.hideWindow()
        }
    }

    private func createAndConfigureWindow(with state: WatchlistEditorState) -> NSWindow {
        let editorView = WatchlistEditorView(state: state)
        let hostingView = windowProvider.createHostingView(rootView: editorView)
        hostingView.autoresizingMask = [.width, .height]

        let opaqueContainer = OpaqueContainerView(frame: NSRect(x: 0, y: 0, width: WindowSize.defaultWidth, height: WindowSize.defaultHeight))
        hostingView.frame = opaqueContainer.bounds
        opaqueContainer.addSubview(hostingView)

        let window = windowProvider.createWindow(
            contentRect: NSRect(x: 0, y: 0, width: WindowSize.defaultWidth, height: WindowSize.defaultHeight),
            styleMask: [.titled, .closable, .resizable]
        )
        window.title = "Edit Watchlist"
        window.contentView = opaqueContainer
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: WindowSize.minWidth, height: WindowSize.minHeight)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()

        return window
    }

    private func hideWindow() {
        editorState?.clearCallbacks()
        editorState = nil
        window?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            editorState?.clearCallbacks()
            editorState = nil
            window = nil
        }
    }
}

// MARK: - SwiftUI View

struct WatchlistEditorView: View {
    @ObservedObject var state: WatchlistEditorState

    var body: some View {
        VStack(spacing: 0) {
            editorContent
        }
        .frame(minWidth: WindowSize.minWidth, minHeight: WindowSize.minHeight)
    }

    private var editorContent: some View {
        VStack(spacing: 16) {
            headerSection
            addSymbolSection
            sortButtonsSection
            symbolListSection
            footerSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Edit Watchlist")
                .font(.headline)
                .padding(.top, 16)

            Text("Maximum \(WatchlistOperations.maxWatchlistSize) symbols allowed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Add Symbol

    private var addSymbolSection: some View {
        VStack(spacing: 4) {
            HStack {
                TextField("Enter symbol", text: $state.newSymbol)
                    .textFieldStyle(.roundedBorder)
                    .disabled(state.isValidating)
                    .onSubmit {
                        state.validateAndAddSymbol()
                    }
                    .onChange(of: state.newSymbol) { _ in
                        state.validationError = nil
                    }

                Button(action: { state.validateAndAddSymbol() }) {
                    addButtonContent
                }
                .disabled(isAddButtonDisabled)
            }

            if let error = state.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var addButtonContent: some View {
        if state.isValidating {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: LayoutConfig.EditorWindow.buttonWidth)
        } else {
            Text("Add")
                .frame(width: LayoutConfig.EditorWindow.buttonWidth)
        }
    }

    private var isAddButtonDisabled: Bool {
        state.newSymbol.trimmingCharacters(in: .whitespaces).isEmpty ||
        state.symbols.count >= WatchlistOperations.maxWatchlistSize ||
        state.isValidating
    }

    // MARK: - Sort Buttons

    private var sortButtonsSection: some View {
        HStack {
            Text("Sort:")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: { state.sortSymbolsAscending() }) {
                HStack(spacing: 2) {
                    Text("A→Z")
                    Image(systemName: "arrow.up")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(state.sortAscending ? .accentColor : .gray)

            Button(action: { state.sortSymbolsDescending() }) {
                HStack(spacing: 2) {
                    Text("Z→A")
                    Image(systemName: "arrow.down")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(state.sortAscending ? .gray : .accentColor)

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Symbol List

    private var symbolListSection: some View {
        List {
            ForEach(state.symbols, id: \.self) { symbol in
                symbolRow(for: symbol)
            }
        }
        .listStyle(.bordered)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func symbolRow(for symbol: String) -> some View {
        HStack {
            Text(symbol)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Button(action: { state.removeSymbol(symbol) }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text("\(state.symbols.count) / \(WatchlistOperations.maxWatchlistSize) symbols")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Cancel") {
                state.cancel()
            }
            .keyboardShortcut(.escape)

            Button("Save") {
                state.save()
            }
            .keyboardShortcut(.return)
            .disabled(!state.hasChanges)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
