import AppKit
import XCTest
@testable import PokeTokenBar

@MainActor
final class MenuProviderIconsTests: XCTestCase {
    func testTwoIconsKeepPercentColorsAndUnknownProvider() {
        let text = NSMutableAttributedString(string: "12K\nClaude 40% · Codex 70% · Cursor 20%")
        MenuLimitColoring.apply([.init(text: "Codex 70%", tier: .over)], to: text)
        render(text, artwork: ["Claude": NSImage(size: NSSize(width: 36, height: 36)),
                               "Codex": NSImage(size: NSSize(width: 36, height: 36))])
        XCTAssertEqual(text.string, "12K\n\u{fffc} 40% · \u{fffc} 70% · Cursor 20%")
        let range = (text.string as NSString).range(of: "70%")
        XCTAssertNotNil(text.attribute(.foregroundColor, at: range.location, effectiveRange: nil))
        var count = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment {
                count += 1
                XCTAssertLessThanOrEqual(attachment.bounds.height, 10)
            }
        }
        XCTAssertEqual(count, 2)
    }

    func testUncoloredAndMissingImageFallback() {
        let text = NSMutableAttributedString(string: "Claude 40% · Codex 70%")
        render(text, artwork: ["Claude": NSImage(size: NSSize(width: 36, height: 36))])
        XCTAssertEqual(text.string, "\u{fffc} 40% · Codex 70%")
        let fallback = NSMutableAttributedString(string: "Claude 40% · Codex 70%")
        render(fallback, artwork: [:])
        XCTAssertEqual(fallback.string, "Claude 40% · Codex 70%")
    }

    private func render(_ text: NSMutableAttributedString, artwork: [String: NSImage]) {
        MenuProviderIcons.apply(to: text,
            parts: [.init(text: "Claude 40%", utilization: 40, pace: nil),
                    .init(text: "Codex 70%", utilization: 70, pace: nil)],
            font: .systemFont(ofSize: 9), height: 10,
            appearance: NSAppearance(named: .aqua)!, artwork: artwork)
    }
}
