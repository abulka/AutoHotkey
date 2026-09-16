#!/usr/bin/env bash
# Run the BAR cheat helper on Fedora Silverblue (GNOME Wayland).
#
# Input backend can be chosen via AHK_BACKEND (default: x11, where Alt+C is
# grabbed reliably on Fedora/GNOME; the portal lane drops Alt+C when no
# remote-interaction session is active). Set AHK_BACKEND=portal to force it.
set -euo pipefail
cd "$(dirname "$0")"
BACKEND="${AHK_BACKEND:-x11}"

# uinput gives dialog-free auto-typing and auto-submit (no XTEST/libei consent)
if [ ! -w /dev/uinput ]; then
    cat >&2 <<'EOF'
note: /dev/uinput is not writable, so pasting falls back to XTEST text
      (needs the "remote interaction" Allow/Share consent, and you press
      Enter to submit).  For dialog-free auto-typing and auto-submit:
        echo 'KERNEL=="uinput", MODE="0666"' | sudo tee /etc/udev/rules.d/60-ahk-uinput.rules
        sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=uinput
EOF
fi

distrobox enter --name ahk -- bash -lc "cd ~/AutoHotkey && AHK_INPUT_BACKEND=$BACKEND ahk bar_cheat.ahk"