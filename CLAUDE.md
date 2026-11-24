# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Cliphoard is a macOS 15+ menu bar app (Swift 6, SwiftUI) that keeps a searchable SQLite history of copied text. User-facing behaviour, keyboard shortcuts and release steps are in `README.md`.

## Commands

- `scripts/build.sh [Debug|Release]` – build once (default Release); prints only `file:line: error/warning` and `** BUILD` lines. Output app: `build/DerivedData/Build/Products/<config>/Cliphoard.app`.
- `make dev` (`scripts/dev.sh`) – long-running loop: Debug build, launch in the background, rebuild + relaunch on every change in `Cliphoard/` or the project. The user often has it running; it picks up edits automatically.
- `make run`, `make install` (Release → `/Applications`, then launch), `make uninstall`, `make clean`.
- `scripts/release.sh [--publish]` – DMG + Homebrew cask in `build/`; `--publish` tags, pushes and creates a GitHub release (outward-facing: only on request).

There is no test target and no linter. To test logic, compile the non-UI sources together with a scratch `main.swift` (outside the repo):

```sh
cd Cliphoard && xcrun swiftc -swift-version 6 -default-isolation MainActor -o /tmp/t \
  ClipboardItem.swift ClipboardFilter.swift ClipboardStore.swift ClipboardMonitoring.swift \
  ClipboardMonitor.swift Secrets.swift db/Creator.swift db/Migrator.swift /path/to/main.swift
```

`main.swift` must stub `enum HistoryLimit { static var current: Int { 10_000 } }` (it lives in `SettingsView.swift`), open a temp DB via `DatabaseCreator.open(at:migrations: Migration.load(from: <db/Migrations dir>))`, use a private `NSPasteboard(name:)`, and a `SecretCipher(service:)` with a throwaway service name whose keychain item is deleted afterwards. Never touch the real database (`~/Library/Application Support/dev.local.Cliphoard/`), the real keychain item, or the user's clipboard in tests.

SourceKit diagnostics like "Cannot find type … in scope" are noise from indexing single files; trust `scripts/build.sh`.

## Project setup

- Hand-written Xcode project using a folder-synchronized group: any file added under `Cliphoard/` is compiled/bundled automatically; no pbxproj edits needed. `.sql` files are copied flat into the bundle's Resources.
- Build settings: default MainActor isolation (types meant for background use are marked `nonisolated`), no App Sandbox, ad-hoc signing, `LSUIElement = YES`, bundle ID `dev.local.Cliphoard`.

## Architecture

- `CliphoardApp` creates the shared objects (`ClipboardMonitor`, `GlobalHotKeyController`, `SecretVault`) in `init` and wires the scenes: a single `Window` (id `main`), a `MenuBarExtra`, and `Settings`. The `MenuBarExtra` label view is always alive, so it hands the global hot key its `openWindow` action. `DockVisibility` switches the activation policy to `.regular` while a window is open (Dock + ⌘-Tab) and back to `.accessory` otherwise.
- `ClipboardMonitoring` protocol is what views depend on; `ClipboardMonitor` is the real one, `PreviewClipboardMonitor` (DEBUG) serves `#Preview`s with in-memory sample data. Protocol changes must be implemented in both.
- `ClipboardMonitor` polls `NSPasteboard.changeCount` every 100 ms (no change notification exists), guesses the source app from the frontmost app, skips repeats via `latestText`, inserts into the store, enforces the max-items limit after every save, and pages the list (100 per page, keyset pagination in `ClipboardStore.items(matching:before:limit:)`). Its own writes to the pasteboard are marked as seen so they aren't recorded with Cliphoard as source.
- `ClipboardStore` wraps the SQLite3 C API directly (no ORM). Filtering (text `LIKE`, app, timeframe) happens in SQL; `ClipboardFilter.matches` mirrors it in memory for newly recorded items.
- Database: `db/Creator.swift` opens the per-user DB (folder 0700, file 0600, WAL, `secure_delete`), `db/Migrator.swift` applies `db/Migrations/NNNN_*.sql` in order using `PRAGMA user_version`, each in a transaction. Never edit a shipped migration; add a new numbered file.
- Secrets (`Secrets.swift`):
  - `SecretDetector` decides plain/secret/skip from nspasteboard.org markers (concealed/auto-generated → secret, transient → not stored), known password-manager bundle IDs, and the `looksLikePassword` heuristic. Bump `contentCheckVersion` when the heuristic changes so existing items are rescanned once.
  - Secret rows have empty `text` and an AES-GCM `ciphertext`; `secret_reviewed` records a user's manual mark/unmark so detection never overrides it.
  - `SecretCipher` keeps the key in the login keychain (generic password, not the data-protection keychain, because ad-hoc builds lack a team ID). The key is read lazily: only when a secret is stored, revealed or copied – never at launch or for plain items. Decrypting never creates a key.
  - `SecretVault` gates reveal/copy/unmark in the UI with `LAContext` (Touch ID or password), unlocked for 5 minutes or until screen lock/sleep.
- Settings persist in `UserDefaults` (`@AppStorage` in `SettingsView`, keys defined next to their owners, e.g. `HistoryLimit`, `SecretDetector.byContentKey`) and are pushed into the monitor on change.
- `GlobalHotKey.swift` uses Carbon `RegisterEventHotKey` (no Accessibility permission needed). `LaunchAtLogin` uses `SMAppService.mainApp`; Release builds register on first launch only, Debug builds never auto-register.
- UI: `ContentView` owns navigation (`NavigationStack`), filters, selection and all list keyboard handling (`onKeyPress`, plus an `NSEvent` monitor for Tab in the search field, and a hidden button for ⌘, because the app menu isn't available without a Dock icon). Keep `KeyboardHelpView` and the README shortcut table in sync with key handling.

## Conventions

- Keep comments sparse: only non-obvious reasons, no doc comments restating names.
- Treat clipboard contents as sensitive: don't print history content when inspecting the real DB (counts only).
- Don't commit unless asked.
