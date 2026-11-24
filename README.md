# Cliphoard

A macOS menu bar app that keeps a searchable history of everything you copy.
Only text is recorded; images, files and other clipboard types are ignored.

The history is stored locally in SQLite at
`~/Library/Application Support/dev.local.Cliphoard/history.sqlite`, readable only by your user.

## Secrets

Passwords and tokens are hidden in the list, left out of searches and stored
encrypted. Showing or copying one asks for Touch ID or your password, then stays
unlocked for 5 minutes or until the screen locks.

An item is a secret when the password manager marks it as concealed
([nspasteboard.org](http://nspasteboard.org)), when it was copied from a password
manager, or when it looks like a password (can be turned off in Settings). Items
the password manager marks as transient aren't stored at all. Right-click an item,
or use the lock button on its detail page, to mark or unmark it yourself.

The encryption key is in your login keychain. This is not the highest possible security with the secure enclave. But since secure enclave is only available with a team signed app which in turn requires a developer account I leave it like that for now.

## Settings

Open with ⌘, or from the menu bar icon.

- **Maximum items**: how many items to keep (default 10,000). The oldest are deleted when the limit is reached.
- **Secrets**: whether to detect passwords and tokens by their content (on by default).
- **Global shortcut**: brings Cliphoard to the front from any app. Off by default; when enabled it defaults to ⌘⇧C and can be changed.

## Keyboard shortcuts

| Where  | Keys                    | Action                          |
| ------ | ----------------------- | ------------------------------- |
| List   | ↓ or j                  | Next item                       |
|        | ↑ or k                  | Previous item                   |
|        | → or l or ↩             | Open item                       |
|        | c                       | Copy item                       |
|        | esc                     | Clear selection                 |
|        | / or a letter or number | Search                          |
| Search | ⇥                       | Go to the first result          |
|        | ⇧⇥ (from the list)      | Back to search                  |
| Detail | ← or h                  | Back to the list                |
|        | c                       | Copy item                       |
| App    | ⌘,                      | Settings                        |

j, k, l and c don't start a search; type / first.

## Development

Requires Xcode and macOS 15. `scripts/dev.sh` builds the app, launches it in the
background and rebuilds and relaunches on every change.
