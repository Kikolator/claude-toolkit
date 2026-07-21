#!/usr/bin/env bash
# notify.sh — ring the terminal and raise a desktop notification.
#
# Usage: notify.sh "<title>" ["<message>"] [--urgent]
#
# Always rings the terminal bell (works over SSH, in tmux, in any terminal that
# has the bell enabled) and additionally fires a native desktop notification when
# one is available. Never fails the caller: notification is a courtesy, not a
# gate, so every backend is best-effort and the script always exits 0.

set -uo pipefail

TITLE="${1:-Claude}"
MESSAGE="${2:-}"
URGENT=0
for arg in "$@"; do
  [[ "$arg" == "--urgent" ]] && URGENT=1
done

# 1. Terminal bell. Cheap, universal, works where nothing else does.
# Write to /dev/tty when there is one (survives redirected stdout), else stdout.
bell() {
  if { : >/dev/tty; } 2>/dev/null; then
    printf '\a' >/dev/tty
  else
    printf '\a'
  fi
}

bell
if [[ $URGENT -eq 1 ]]; then
  sleep 0.3; bell
  sleep 0.3; bell
fi

# 2. Desktop notification, best effort by platform.
notified=0

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound Glass >/dev/null 2>&1 && notified=1
elif [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
  # Escape double quotes for AppleScript.
  esc_title=${TITLE//\"/\\\"}
  esc_msg=${MESSAGE//\"/\\\"}
  osascript -e "display notification \"${esc_msg}\" with title \"${esc_title}\" sound name \"Glass\"" >/dev/null 2>&1 && notified=1
elif command -v notify-send >/dev/null 2>&1; then
  if [[ $URGENT -eq 1 ]]; then
    notify-send -u critical "$TITLE" "$MESSAGE" >/dev/null 2>&1 && notified=1
  else
    notify-send "$TITLE" "$MESSAGE" >/dev/null 2>&1 && notified=1
  fi
fi

# 3. Always echo, so the summary survives in the scrollback even if every
#    notification backend is missing (headless CI, container, bare SSH).
if [[ -n "$MESSAGE" ]]; then
  printf '\n[%s] %s\n' "$TITLE" "$MESSAGE"
else
  printf '\n[%s]\n' "$TITLE"
fi

[[ $notified -eq 0 ]] && printf '(no desktop notifier found; bell only)\n' >&2

exit 0
