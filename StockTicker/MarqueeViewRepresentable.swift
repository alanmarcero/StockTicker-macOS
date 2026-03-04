import SwiftUI

struct MarqueeViewRepresentable: NSViewRepresentable {
    let marqueeView: MarqueeView

    func makeNSView(context: Context) -> MarqueeView {
        marqueeView
    }

    func updateNSView(_ nsView: MarqueeView, context: Context) {}
}
