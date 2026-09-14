# AeroPeek

A native, keyboard-first macOS workspace overlay for AeroSpace.

Open `AeroPeek.xcodeproj`, select the AeroPeek scheme, and run.

## Configure AeroSpace

Add this binding under `[mode.main.binding]` in `~/.aerospace.toml` to toggle AeroPeek with Option–Backtick:

```toml
alt-backtick = 'exec-and-forget open "$HOME/Applications/AeroPeek.app"'
```

Controls: Up/Down selects, Right expands a workspace, Left collapses it, Home/End jumps, a configured single-character workspace key switches directly, Return activates the selected workspace or window, and Escape closes the overlay. Tab is intentionally unused. Click the Quit button or press Command-Q to quit AeroPeek.

## License

AeroPeek is made available under the [MIT License](LICENSE). This project was developed with substantial assistance from AI coding tools; to the extent that I hold copyright or other licensable rights in the project, I make those rights available under the MIT License, and no claim of copyright is made over material that is not eligible for copyright protection.

