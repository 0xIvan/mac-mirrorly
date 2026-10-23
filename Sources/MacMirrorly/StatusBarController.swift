import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = MenuPanel()
    private var hostingController: NSHostingController<AnyView>?
    private var cancellables: Set<AnyCancellable> = []
    private var outsideClickMonitor: Any?

    init(model: AppModel) {
        self.model = model
        super.init()

        let hostingController = NSHostingController(rootView: AnyView(MenuPopover(model: model)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
                self?.resizePanel(to: size)
            }))
        hostingController.sizingOptions = []
        self.hostingController = hostingController
        panel.setContent(hostingController.view)
        panel.delegate = self
        panel.onOrderOut = { [weak self] in self?.didClose() }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.setAccessibilityLabel("MacMirrorly")
        }
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)
        updateButton()
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = hostingController?.sizeThatFits(in: CGSize(width: 10_000, height: 10_000)) ?? panel.frame.size
        let screenFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .infinite
        let x = min(max(buttonFrame.minX, screenFrame.minX + 6), screenFrame.maxX - size.width - 6)
        panel.setFrame(NSRect(x: x, y: buttonFrame.minY - size.height - 5, width: size.width, height: size.height), display: true)

        button.highlight(true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.orderOut(nil) }
        }
    }

    private func resizePanel(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: panel.isVisible)
        panel.invalidateShadow()
    }

    private func didClose() {
        statusItem.button?.highlight(false)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        panel.orderOut(nil)
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarStatusImage.make()
        button.imagePosition = .imageLeading

        let title = NSMutableAttributedString()
        let font = NSFont.menuBarFont(ofSize: 0)
        if model.sessionState == .signedIn, !model.valuesHidden {
            title.append(NSAttributedString(string: Money.whole(model.selectedEquity), attributes: [.font: font]))
        }
        if model.sessionState == .signedIn, model.dataWarning != nil,
           let warning = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: "Data warning")?
            .withSymbolConfiguration(.init(pointSize: font.pointSize - 1, weight: .regular).applying(.init(paletteColors: [.white, .systemOrange]))) {
            let attachment = NSTextAttachment()
            attachment.image = warning
            attachment.bounds = NSRect(x: 0, y: font.descender + 1, width: warning.size.width, height: warning.size.height)
            title.append(NSAttributedString(string: title.length > 0 ? " " : "", attributes: [.font: font]))
            title.append(NSAttributedString(attachment: attachment))
        }
        button.attributedTitle = title
    }
}

private final class MenuPanel: NSPanel {
    var onOrderOut: () -> Void = {}

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }

    override func orderOut(_ sender: Any?) {
        let wasVisible = isVisible
        super.orderOut(sender)
        if wasVisible { onOrderOut() }
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }

    func setContent(_ view: NSView) {
        let cornerRadius: CGFloat = 12
        let background: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            background = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .menu
            effect.state = .active
            effect.blendingMode = .behindWindow
            effect.wantsLayer = true
            effect.layer?.cornerRadius = cornerRadius
            effect.layer?.masksToBounds = true
            background = effect
        }
        // Content sits beside the glass, not inside it: as glass content it is rendered monochrome and loses the P&L colours.
        // The window shadow follows the drawn alpha, which is square under the glass unless the whole panel is clipped.
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        for subview in [background, view] {
            subview.frame = container.bounds
            subview.autoresizingMask = [.width, .height]
            container.addSubview(subview)
        }
        contentView = container
    }
}

enum MenuBarStatusImage {
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
