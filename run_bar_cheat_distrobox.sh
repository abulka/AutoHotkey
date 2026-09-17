#!/usr/bin/env bash
# Run the BAR cheat helper inside a distrobox container. Intended for immutable
# (atomic) distros such as Fedora Silverblue, where the root filesystem is
# read-only; tested on Fedora Silverblue 44 / GNOME Wayland. On native
# Debian/Ubuntu or WSL, run the script directly instead (see README).
#
# Input backend can be chosen via AHK_BACKEND (default: x11, where Alt+C is
# grabbed reliably on Fedora/GNOME; the portal lane drops Alt+C when no
# remote-interaction session is active). Set AHK_BACKEND=portal to force it.
set -euo pipefail
cd "$(dirname "$0")"
BACKEND="${AHK_BACKEND:-x11}"

if ! command -v distrobox >/dev/null 2>&1; then
    cat >&2 <<'EOF'
error: distrobox not found. This launcher is for distrobox-based setups
       (e.g. Fedora Silverblue). On native Debian/Ubuntu or WSL, run directly:
         AHK_INPUT_BACKEND=x11 ahk bar_cheat.ahk
       To preview the GUI on WSL, use bar_cheat_wsl.ahk (see README).
EOF
    exit 1
fi

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