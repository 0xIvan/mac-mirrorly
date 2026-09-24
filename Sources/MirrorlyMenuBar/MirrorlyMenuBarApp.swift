import AppKit
import SwiftUI

@main
struct MirrorlyMenuBarApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPopover(model: model)
        } label: {
            HStack(spacing: 5) {
                Text("M").fontWeight(.heavy)
                Text(Money.whole(model.selectedEquity))
                if model.sessionState == .signedIn, model.dataWarning != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow(model: model)
        }
    }
}
