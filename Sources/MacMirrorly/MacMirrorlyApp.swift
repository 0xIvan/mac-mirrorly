import AppKit
import SwiftUI

@main
struct MacMirrorlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        Settings {
            SettingsWindow(model: appDelegate.model, updater: updater)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(model: model)
    }
}
