import AppKit

final class OverlayPanel: NSPanel {
    var handleCommand: ((KeyboardCommand) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        guard let command = KeyboardCommandMapper.command(for: KeyInput(event: event)) else {
            super.keyDown(with: event)
            return
        }
        handleCommand?(command)
    }

    override func cancelOperation(_ sender: Any?) { handleCommand?(.dismiss) }
    override func moveToBeginningOfDocument(_ sender: Any?) { handleCommand?(.selectFirst) }
    override func moveToEndOfDocument(_ sender: Any?) { handleCommand?(.selectLast) }
    override func scrollToBeginningOfDocument(_ sender: Any?) { handleCommand?(.selectFirst) }
    override func scrollToEndOfDocument(_ sender: Any?) { handleCommand?(.selectLast) }
}
