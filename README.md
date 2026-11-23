# Cliphoard

A macOS menu bar app that keeps a searchable history of everything you copy.
Only text is recorded; images, files and other clipboard types are ignored.

The history is stored locally in SQLite at
`~/Library/Application Support/dev.local.Cliphoard/history.sqlite`, readable only by your user.

## Settings

Open with ⌘, or from the menu bar icon.

- **Maximum items**: how many items to keep (default 10,000). The oldest are deleted when the limit is reached.
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
| Search | ⇥ or ↩                  | Go to the first result          |
|        | ⇧⇥ (from the list)      | Back to search                  |
| Detail | ← or h                  | Back to the list                |
|        | c                       | Copy item                       |
| App    | ⌘,                      | Settings                        |

j, k, l and c don't start a search; type / first.

## Development

Requires Xcode and macOS 15. `scripts/dev.sh` builds the app, launches it in the
background and rebuilds and relaunches on every change.
