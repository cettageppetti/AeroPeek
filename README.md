# AeroPeek

A native, keyboard-first macOS workspace overlay for AeroSpace.

Open `AeroPeek.xcodeproj`, select the AeroPeek scheme, and run.

## Configure AeroSpace

Add this binding under `[mode.main.binding]` in `~/.aerospace.toml` to toggle AeroPeek with Option–Backtick:

```toml
alt-backtick = 'exec-and-forget open "$HOME/Applications/AeroPeek.app"'
```

Controls: Up/Down selects, Right expands a workspace, Left collapses it, Home/End jumps, a configured single-character workspace key switches directly, Return activates the selected workspace or window, and Escape closes the overlay. Use the Quit button or Command-Q to quit AeroPeek.
