import AppKit
import SwiftUI

@main
struct MacMirrorlyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPopover(model: model)
        } label: {
            HStack(spacing: 4) {
                // The dollar glyph has a one-point leading bearing, making the visible gap four points.
                HStack(spacing: 3) {
                    Image(nsImage: MenuBarStatusImage.make())
                    if model.sessionState == .signedIn, !model.valuesHidden {
                        Text(Money.whole(model.selectedEquity))
                            .font(Font(NSFont.menuBarFont(ofSize: 0)))
                    }
                }
                if model.sessionState == .signedIn, model.dataWarning != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .accessibilityLabel("MacMirrorly")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow(model: model)
        }
        .windowResizability(.contentSize)
    }
}

private enum MenuBarStatusImage {
    static func make() -> NSImage {
        let iconSize: CGFloat = 20
        let image = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { _ in
            NSImage(named: "MenuBarMark")?.draw(
                in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}
