import AppKit

// MARK: - Marquee Constants

enum MarqueeConfig {
    static let tickInterval: TimeInterval = 0.25
    static let pixelsPerTick: CGFloat = 8              // ~32 px/sec
    static let viewWidth: CGFloat = LayoutConfig.Marquee.width
    static let viewHeight: CGFloat = LayoutConfig.Marquee.height
    static let separator = "   "                        // 3 spaces
    static let pingFadeStep: CGFloat = 0.03
    static let pingFadeInterval: TimeInterval = 0.05
    static let pingAlphaMultiplier: CGFloat = 0.4
}

// MARK: - Marquee View

class MarqueeView: NSView {
    private var attributedText: NSAttributedString = NSAttributedString()
    private var scrollOffset: CGFloat = 0
    private var textWidth: CGFloat = 0
    private var separatorWidth: CGFloat = 0
    private var scrollTimer: Timer?
    private var highlightIntensity: CGFloat = 0
    private var highlightTimer: Timer?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateText(_ text: NSAttributedString) {
        attributedText = text
        textWidth = text.size().width
        separatorWidth = NSAttributedString(
            string: MarqueeConfig.separator,
            attributes: [.font: MenuItemFactory.monoFont]
        ).size().width
        setNeedsDisplay(bounds)
    }

    func startScrolling() {
        guard scrollTimer == nil else { return }
        scrollTimer = Timer(timeInterval: MarqueeConfig.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(scrollTimer!, forMode: .common)
    }

    func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    func triggerPing() {
        highlightIntensity = 1.0
        startHighlightFade()
        setNeedsDisplay(bounds)
    }

    private func tick() {
        let totalWidth = textWidth + separatorWidth
        guard totalWidth > 0 else { return }

        scrollOffset += MarqueeConfig.pixelsPerTick
        if scrollOffset >= totalWidth {
            scrollOffset -= totalWidth
        }
        setNeedsDisplay(bounds)
    }

    private func startHighlightFade() {
        highlightTimer?.invalidate()
        highlightTimer = Timer(timeInterval: MarqueeConfig.pingFadeInterval, repeats: true) { [weak self] _ in
            self?.fadeHighlight()
        }
        RunLoop.main.add(highlightTimer!, forMode: .common)
    }

    private func fadeHighlight() {
        highlightIntensity = max(0, highlightIntensity - MarqueeConfig.pingFadeStep)
        setNeedsDisplay(bounds)
        if highlightIntensity <= 0 {
            highlightTimer?.invalidate()
            highlightTimer = nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        if highlightIntensity > 0 {
            let bgColor = NSColor.gray.withAlphaComponent(highlightIntensity * MarqueeConfig.pingAlphaMultiplier)
            bgColor.setFill()
            bounds.fill()
        }

        let totalWidth = textWidth + separatorWidth
        let yOffset = (bounds.height - attributedText.size().height) / 2

        context.clip(to: bounds)

        let firstX = -scrollOffset
        attributedText.draw(at: NSPoint(x: firstX, y: yOffset))

        if totalWidth > 0 {
            let secondX = firstX + totalWidth
            if secondX < bounds.width {
                attributedText.draw(at: NSPoint(x: secondX, y: yOffset))
            }
            let beforeX = firstX - totalWidth
            if beforeX + textWidth > 0 {
                attributedText.draw(at: NSPoint(x: beforeX, y: yOffset))
            }
        }
    }
}
