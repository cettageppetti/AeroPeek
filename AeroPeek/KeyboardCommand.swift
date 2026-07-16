import AppKit

enum KeyboardCommand: Equatable {
    case dismiss, selectFirst, selectLast, activateSelection
    case moveSelection(Int)
    case activateWorkspace(String)
}

struct KeyInput {
    let keyCode: UInt16
    let characters: String?
    let modifiers: NSEvent.ModifierFlags

    init(event: NSEvent) {
        keyCode = event.keyCode
        characters = event.charactersIgnoringModifiers
        modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }

    init(keyCode: UInt16, characters: String? = nil, modifiers: NSEvent.ModifierFlags = []) {
        self.keyCode = keyCode
        self.characters = characters
        self.modifiers = modifiers
    }
}

enum KeyboardCommandMapper {
    static func command(for input: KeyInput) -> KeyboardCommand? {
        if input.keyCode == 115 || input.characters == String(UnicodeScalar(NSHomeFunctionKey)!) { return .selectFirst }
        if input.keyCode == 119 || input.characters == String(UnicodeScalar(NSEndFunctionKey)!) { return .selectLast }

        switch input.keyCode {
        case 53: return .dismiss
        case 125: return .moveSelection(1)
        case 126: return .moveSelection(-1)
        case 123 where input.modifiers.contains(.function): return .selectFirst
        case 124 where input.modifiers.contains(.function): return .selectLast
        case 36, 76: return .activateSelection
        default: break
        }

        let blocked: NSEvent.ModifierFlags = [.command, .control, .option]
        guard input.modifiers.intersection(blocked).isEmpty,
              let key = input.characters?.uppercased(), key.count == 1,
              "123456789ACN".contains(key) else { return nil }
        return .activateWorkspace(key)
    }
}
