import AppKit

/// Coalesces transient status-button appearances without updating persisted usage or game state.
@MainActor
final class MenuAppearanceRefresh {
    private weak var button: NSStatusBarButton?
    private var observation: NSKeyValueObservation?
    private var pending: Task<Void, Never>?
    private var renderedColor: NSColor?
    private let refresh: @MainActor () -> Void

    init(button: NSStatusBarButton, refresh: @escaping @MainActor () -> Void) {
        self.button = button
        self.refresh = refresh
        markRendered()
        observation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.requestRefresh() }
        }
    }

    func markRendered() {
        renderedColor = resolvedColor()
    }

    func requestRefresh() {
        guard pending == nil else { return }
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let self else { return }
            self.pending = nil
            guard let color = self.resolvedColor(), color != self.renderedColor else { return }
            // Commit before drawing: title changes can generate further appearance notifications.
            self.renderedColor = color
            self.refresh()
        }
    }

    private func resolvedColor() -> NSColor? {
        guard let button else { return nil }
        var color: NSColor?
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            color = NSColor.labelColor.usingColorSpace(.deviceRGB)
        }
        return color
    }
}
