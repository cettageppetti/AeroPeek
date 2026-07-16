import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = WorkspaceModel()
    private var panel: OverlayPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory); createPanel(); show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.isVisible ? hide() : show(); return true
    }

    private func createPanel() {
        panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 540), styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        let contentView = NSHostingView(rootView: OverlayView(model: model))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 18
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
        panel.contentView = contentView
        panel.isFloatingPanel = true; panel.level = .floating; panel.hasShadow = true
        panel.backgroundColor = .clear; panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.handleCommand = { [weak self] in self?.handle($0) }
    }

    private func handle(_ command: KeyboardCommand) {
        switch command {
        case .dismiss: hide()
        case .moveSelection(let offset): model.move(by: offset)
        case .selectFirst: model.selectFirst()
        case .selectLast: model.selectLast()
        case .expandSelection: model.expandSelection()
        case .collapseSelection: model.collapseSelection()
        case .activateSelection: model.activateSelection(); hide()
        case .activateWorkspace(let id):
            if model.selectWorkspace(id) { model.activateWorkspace(id); hide() }
        }
    }

    private func show() {
        model.refresh()
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - panel.frame.width / 2, y: screen.visibleFrame.midY - panel.frame.height / 2))
        panel.orderFrontRegardless(); panel.makeKey()
    }
    private func hide() { panel.orderOut(nil) }
}
