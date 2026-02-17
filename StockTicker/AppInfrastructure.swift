import Foundation
import AppKit
import SwiftUI

// MARK: - Opaque Container View

/// NSView subclass that draws a solid opaque background to eliminate SwiftUI transparency.
/// Use this as a container for NSHostingView when creating windows that need zero transparency.
final class OpaqueContainerView: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}

// MARK: - File System Protocol

protocol FileSystemProtocol {
    var homeDirectoryForCurrentUser: URL { get }
    func fileExists(atPath path: String) -> Bool
    func createDirectoryAt(_ url: URL, withIntermediateDirectories: Bool) throws
    func contentsOfFile(atPath path: String) -> Data?
    func writeData(_ data: Data, to url: URL) throws
}

extension FileManager: FileSystemProtocol {
    func createDirectoryAt(_ url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        try createDirectory(at: url, withIntermediateDirectories: createIntermediates)
    }

    func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    func contentsOfFile(atPath path: String) -> Data? {
        contents(atPath: path)
    }
}

// MARK: - Workspace Protocol

protocol WorkspaceProtocol {
    func openURL(_ url: URL)
}

extension NSWorkspace: WorkspaceProtocol {
    func openURL(_ url: URL) {
        open(url)
    }
}

// MARK: - Color Mapping

enum ColorMapping {
    static func nsColor(from name: String) -> NSColor {
        switch name.lowercased() {
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "red": return .systemRed
        case "pink": return .systemPink
        case "purple": return .systemPurple
        case "blue": return .systemBlue
        case "cyan": return .systemCyan
        case "teal": return .systemTeal
        case "green": return .systemGreen
        case "gray", "grey": return .systemGray
        case "brown": return .systemBrown
        default: return .systemYellow
        }
    }

    static func color(from name: String) -> Color {
        Color(nsColor: nsColor(from: name))
    }
}
