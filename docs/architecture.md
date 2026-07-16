# Architecture

AppKit owns application and nonactivating-panel lifecycle; SwiftUI renders its material-backed content. `OverlayPanel` captures raw events, `KeyboardCommandMapper` converts them into testable semantic commands, and `AppDelegate` dispatches commands to `WorkspaceModel`. The model calls AeroSpace asynchronously and parses each window into per-application and per-workspace counts. `AppIconProvider` resolves icons through `NSWorkspace` and falls back to the native generic application icon. No global event tap or accessibility permission is required.
