import AppKit

/// Personal menu-bar artwork, loaded locally rather than shipped with the app.
@MainActor
enum MenuProviderIcons {
    private static let images: [String: NSImage] = {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/swiftbar-assets")
        return ["Claude": "claude-logo-36.png", "Codex": "codex-logo-36.png"]
            .compactMapValues { NSImage(contentsOf: directory.appendingPathComponent($0)) }
    }()

    static func apply(to title: NSMutableAttributedString, parts: [UsageStore.MenuLimitPart],
                      font: NSFont, height: CGFloat, appearance: NSAppearance,
                      artwork: [String: NSImage]? = nil) {
        let sources = artwork ?? images
        let original = title.string as NSString
        let replacements = parts.compactMap { part -> (NSRange, String, NSImage)? in
            guard let label = part.text.split(separator: " ").first.map(String.init),
                  let image = sources[label], image.size.width > 0, image.size.height > 0 else { return nil }
            let itemRange = original.range(of: part.text)
            guard itemRange.location != NSNotFound else { return nil }
            return (NSRange(location: itemRange.location, length: (label as NSString).length), label, image)
        }.sorted { $0.0.location > $1.0.location }

        for (range, label, source) in replacements {
            let side = min(16, height)
            let size = NSSize(width: side * source.size.width / source.size.height, height: side)
            let image = NSImage(size: size)
            appearance.performAsCurrentDrawingAppearance {
                image.lockFocus()
                source.draw(in: NSRect(origin: .zero, size: size))
                if label == "Codex" {
                    NSColor.labelColor.setFill()
                    NSRect(origin: .zero, size: size).fill(using: .sourceIn)
                }
                image.unlockFocus()
            }
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = NSRect(x: 0, y: (font.capHeight - side) / 2,
                                       width: size.width, height: side)
            let replacement = NSMutableAttributedString(attachment: attachment)
            var attributes = title.attributes(at: range.location, effectiveRange: nil)
            attributes.removeValue(forKey: .foregroundColor)
            replacement.addAttributes(attributes, range: NSRange(location: 0, length: replacement.length))
            title.replaceCharacters(in: range, with: replacement)
        }
    }
}
