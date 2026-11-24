#!/bin/bash
#
# Dev loop: build Cliphoard, launch it, and rebuild + relaunch whenever a
# source file or the Xcode project changes. Press Ctrl-C to stop (this also
# quits the app).
#
# Uses `fswatch` if installed (brew install fswatch); otherwise polls.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/DerivedData/Build/Products/Debug/Cliphoard.app"
EXECUTABLE="$APP/Contents/MacOS/Cliphoard"
WATCH_PATHS=("Cliphoard" "Cliphoard.xcodeproj")
POLL_INTERVAL=0.5

log() { printf '\033[1;34m[dev]\033[0m %s %s\n' "$(date +%H:%M:%S)" "$*"; }

build() {
    log "Building…"
    local start=$SECONDS
    "$ROOT/scripts/build.sh" Debug
    local status=$?
    if [ "$status" -eq 0 ]; then
        log "Build succeeded in $((SECONDS - start))s"
    else
        log "Build FAILED, keeping the previous app running"
    fi
    return "$status"
}

# Quit only the instance built by this script (not one launched from Xcode).
quit_app() {
    pkill -TERM -f "^$EXECUTABLE" 2>/dev/null || return 0
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -f "^$EXECUTABLE" >/dev/null || return 0
        sleep 0.2
    done
    pkill -KILL -f "^$EXECUTABLE" 2>/dev/null
}

launch_app() {
    quit_app
    log "Launching (in background)"
    # Send the app's print() output to this terminal when there is one.
    local tty_path
    tty_path="$(tty 2>/dev/null)"
    if [ -n "$tty_path" ] && [ "$tty_path" != "not a tty" ]; then
        open -n -g "$APP" --stdout "$tty_path" --stderr "$tty_path"
    else
        open -n -g "$APP"
    fi
}

rebuild_and_launch() {
    build && launch_app
}

# Fingerprint of all watched files (path, size, mtime), ignoring Xcode's
# per-user state, which changes constantly while Xcode is open.
fingerprint() {
    find "${WATCH_PATHS[@]}" -type f \
        -not -path '*/xcuserdata/*' -not -name '.DS_Store' \
        -exec stat -f '%N %z %m' {} + 2>/dev/null | md5
}

wait_for_change_poll() {
    local before now
    before="$(fingerprint)"
    while :; do
        sleep "$POLL_INTERVAL"
        now="$(fingerprint)"
        [ "$now" != "$before" ] && break
    done
    # Debounce: wait until saves settle (e.g. Xcode writing several files).
    while :; do
        sleep 0.3
        before="$now"
        now="$(fingerprint)"
        [ "$now" = "$before" ] && break
    done
}

wait_for_change_fswatch() {
    fswatch -1 --latency 0.3 -r \
        --exclude '/xcuserdata/' --exclude '\.DS_Store$' \
        "${WATCH_PATHS[@]}" >/dev/null
}

cleanup() {
    echo
    log "Stopping"
    quit_app
    exit 0
}
trap cleanup INT TERM

if command -v fswatch >/dev/null; then
    wait_for_change() { wait_for_change_fswatch; }
    log "Watching with fswatch"
else
    wait_for_change() { wait_for_change_poll; }
    log "Watching by polling every ${POLL_INTERVAL}s (brew install fswatch for instant events)"
fi

rebuild_and_launch
while :; do
    wait_for_change
    log "Change detected"
    rebuild_and_launch
done
