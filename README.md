# Omnibox History Hider

A macOS native helper that visually shields Chrome's omnibox suggestion popup. It works outside Chrome extension limits by watching Chrome with macOS Accessibility APIs and placing a top-level shield window over the suggestion area.

Type `;;` in the address bar to reveal suggestions for the rest of that omnibox session. Press Enter, Escape, or move focus away to hide again next time.

Build and run:

```sh
swift run omnibox-shield
```

That command intentionally keeps running while the helper is active. Stop it with **Shield** → **Quit** in the macOS menu bar, or press `Ctrl-C` in the terminal.

After the first build, you can run the compiled binary directly:

```sh
.build/debug/omnibox-shield
```

## Build a macOS app

Create a normal `.app` bundle:

```sh
./scripts/build_app.sh
```

Then open it:

```sh
open "dist/Omnibox Shield.app"
```

To install it permanently, move `dist/Omnibox Shield.app` into `/Applications`.

After launching the app version for the first time, grant Accessibility permission to **Omnibox Shield** in **System Settings** → **Privacy & Security** → **Accessibility**. You may need to quit and reopen the app after enabling the permission.

The app checks permission silently. If you want macOS to open the Accessibility prompt from the command line, run:

```sh
"/Applications/Omnibox Shield.app/Contents/MacOS/omnibox-shield" --prompt-accessibility
```

If you rebuild and reinstall the app, macOS may ask again because local ad-hoc signed builds can look like a changed app identity to the privacy system.

On first launch, macOS should ask for Accessibility permission. If it does not, enable it manually:

1. Open **System Settings**.
2. Go to **Privacy & Security** → **Accessibility**.
3. Enable permission for the terminal app running `omnibox-shield`.

For Ghostty:

1. Open **System Settings** → **Privacy & Security** → **Accessibility**.
2. Click **+**.
3. Select **Ghostty.app** from `/Applications`.
4. Turn the Ghostty toggle on.
5. Fully quit Ghostty with `Cmd-Q`, reopen it, then run `swift run omnibox-shield -- --debug` again.

If Ghostty is not in `/Applications`, drag the Ghostty app icon from Finder into the Accessibility list.

The helper adds a small shield icon to the macOS menu bar with a Quit command.
Its menu also shows whether Accessibility permission is granted. If it says **Accessibility: Missing**, use **Open Accessibility Settings** from that menu.

This does not delete or alter Chrome history. It covers the native suggestions visually, which is the part Chrome itself does not let extensions control.

## License

[MIT](LICENSE)
