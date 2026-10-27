import AppKit
import CoreGraphics

// SPIKE: the RPG view is two layers. The pixel-art world is rendered small on the CPU and shown by a layer whose nearest-neighbour
// magnification filter lets the GPU do the enlarging (drawing that scaled image with CoreGraphics took about two thirds of every
// frame). The HUD, text and windows are drawn on top by `RpgOverlayView` at full resolution.

/// Shows the latest low-resolution world frame, enlarged by the GPU without smoothing.
final class RpgWorldLayerView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layer?.contentsGravity = .resize
        layer?.backgroundColor = NSColor(red: 0.08, green: 0.07, blue: 0.1, alpha: 1).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Swaps in a new frame at `rect` (the screen-shake offset moves it) without implicit animation.
    func show(_ image: CGImage, at rect: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = image
        frame = rect
        CATransaction.commit()
    }
}

/// Transparent view the HUD and windows are drawn into, above the world layer.
final class RpgOverlayView: NSView {
    var drawing: ((CGContext) -> Void)?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawing?(ctx)
    }
}

/// The dark translucent plate behind a window. A layer, so the GPU blends it instead of the CPU filling a big rounded path every frame.
final class RpgBackdropView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        layer?.cornerRadius = 8
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
