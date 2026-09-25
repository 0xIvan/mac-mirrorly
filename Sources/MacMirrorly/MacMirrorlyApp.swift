import AppKit
import SwiftUI

@main
struct MacMirrorlyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPopover(model: model)
        } label: {
            HStack(spacing: 0) {
                Image(nsImage: MenuBarStatusImage.make(
                    amount: model.sessionState == .signedIn ? Money.whole(model.selectedEquity) : nil
                ))
                    .accessibilityLabel("MacMirrorly")
                if model.sessionState == .signedIn, model.dataWarning != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .padding(.leading, 4)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow(model: model)
        }
        .windowResizability(.contentSize)
    }
}

private enum MenuBarStatusImage {
    static func make(amount: String?) -> NSImage {
        let iconSize: CGFloat = 20
        let gap: CGFloat = 4
        // The dollar glyph starts one point inside its text origin; offset it so the visible gap is four points.
        let textOrigin = iconSize + gap - 1
        let font = NSFont.menuBarFont(ofSize: 0)
        let statusFont = NSFontManager.shared.convert(font, toSize: font.pointSize + 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: statusFont,
            .foregroundColor: NSColor.black
        ]
        let text = amount as NSString? ?? ""
        let textSize = text.size(withAttributes: attributes)
        let width = amount == nil ? iconSize : textOrigin + ceil(textSize.width)

        let image = NSImage(size: NSSize(width: width, height: iconSize), flipped: false) { _ in
            NSImage(named: "MenuBarMark")?.draw(
                in: NSRect(x: 0, y: -1, width: iconSize, height: iconSize),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            if amount != nil {
                text.draw(
                    at: NSPoint(x: textOrigin, y: (iconSize - textSize.height) / 2),
                    withAttributes: attributes
                )
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
