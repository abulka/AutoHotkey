# Auto Hot Key Scripts

For Windows, I use Auto Hot Key to automate some tasks. Here are some of the scripts I use.

## Scripts

### bar_cheat.ahk

This script is used to automate the process of cheating in the "Beyond All Reason" game. It opens a GUI window with a treeview list of possible objects to create.

#### Requirements

- [AutoHotkey v2.0](https://www.autohotkey.com/) installed

#### Running cheats manually (background)

In *Beyond All Reason*, cheats are normally typed by hand:

1. Press **Enter** in-game to open the console.
2. Run `/cheat` and press **Enter** once to enable cheat mode (the host must do this).
3. Enter a cheat and press **Enter** — e.g. `/give 10 armck 0` to spawn units, or `/godmode` for a command.

Units are spawned at the position of your **last mouse click** in the game, so click where you want them first.

#### How to Run (this script)

The script automates the whole Enter → cheat code → Enter sequence:

1. Double-click `bar_cheat.ahk` (or right-click it and choose "Run Script"). It runs in the background with no visible window.
2. With the game running, press the hotkey (default **Alt+C**, configurable via `bar_cheat.ini`, see Notes) to open the cheat GUI.
3. Switch to the **Meta** tab and double-click **Cheat ON** — this runs `/cheat` and enables cheat mode for you.
4. Switch to the **Units**, **Recent** or **Favorites** tab, adjust the amount if needed, then double-click an entry (or press **Enter** / click "Paste Code"). The script opens the console, types the cheat code and presses Enter — the Enter → cheat → Enter sequence is done for you.
5. Optionally type in the **Search** box to filter the tree as you type (e.g. "big berth"). With matches shown, Enter pastes the first match.
6. Press **Escape** in the GUI to close it without pasting.
7. Stop the script by right-clicking the green AutoHotkey "H" icon in the system tray and choosing "Exit".

Press **Alt+C** again any time to reopen the GUI and spawn more units.

Notes:

- **Tabs**: the GUI has five tabs — **Units** (searchable unit tree with image preview), **Recent** (recently used cheats), **Favorites** (starred + "Fav" cheats), **Meta** (cheat commands like `/cheat`, `/godmode`), and **Settings**.
- **Favorites star**: favorited entries are marked with a ★ in the Units tree, Recent and Meta lists. The ★ Favorite button toggles the star on the selected unit; favorites are deduplicated by name (amount differences don't create new entries).
- **Selection memory**: the last selected tab, the last selected item, expand state and scroll position of the units tree are all restored on reopen; the Units tab also remembers its last used Amount value.
- **Shared Amount area**: the Amount box (+/− and 1/2/5/10 presets) sits below the tabs and applies to whichever tab you're on — pick a unit, recent, or favorite, set an amount like 7, and Enter pastes e.g. `/give 7 <unit> 0`.
- **Recent**: every pasted cheat is recorded in `bar_cheats_recent.txt` and shown on the Recent tab — deduplicated by name, so only the most recent invocation of each cheat is kept. The Recent tab has its own search box; the Remove button deletes the selected entry.
- **Dark mode** palette: window `#202020`, lists/edits `#2D2D2D`, buttons classic gray with black text (`-Theme` — true dark button faces aren't achievable without owner-drawing), status line `#1A1A1A`, light text, and dark themes for the tab headers, checkboxes and tree (Windows 10 1809+; older systems fall back gracefully). The "Amount" groupbox caption is a colored text control so it stays readable.
- **Image preview**: a unit preview shows on the Units, Recent and Favorites tabs (192px, collapsed with the "Hide Img" button so the lists grow). The toggle is remembered in `bar_cheat.ini`.
- **Favorites**: two sources, both shown on the Favorites tab — (1) categories starting with "Fav" (e.g. "Fav Units") in `bar_cheats.txt`, and (2) cheats starred with the "★ Favorite" button (works on the Cheats/Units trees), stored in `bar_cheats_favorites.txt` (gitignored). Starred ones can be removed from the GUI; "Fav" category entries are managed by editing `bar_cheats.txt`. The Favorites tab has its own search box.
- **Tree memory**: expand/collapse state, last selected item, and scroll position are remembered for both trees (`bar_treeview_state.txt` / `bar_cheattree_state.txt`), and the last used tab is restored on reopen.
- **Custom hotkey**: set it on the Settings tab with the hotkey box (or edit `Hotkey=` in `bar_cheat.ini`, e.g. `^!c` for Ctrl+Alt+C, see [AutoHotkey hotkey notation](https://www.autohotkey.com/docs/v2/Hotkeys.htm)). An invalid value falls back to Alt+C.
- **Settings tab** also has toggles for **Always on top**, **Remember window position**, and **Dark mode** — all persisted to `bar_cheat.ini`.
- **Game detection**: pasting only happens when the game window is detected; otherwise a tray notification is shown and nothing is typed. The window is matched by trying each criterion in `GameWinCriteria` in the script (currently the `spring.exe` engine process, then any window title containing "Beyond All Reason") — adjust if your setup differs.
- Recent cheats are remembered in `bar_cheats_recent.txt` and shown in a "Recent" category at the top of the tree.
- The treeview expand/collapse state is saved in `bar_treeview_state.txt`.
- Unit preview images are loaded from the `unit_images/` folder when a selected unit has a matching image.
- `bar_cheats.txt` can be edited (even while the script is running); the list reloads automatically next time the GUI is opened.

#### Example Codes

```
Units
    Constructors|/give 10 armck 0
    Construction Kbot|/give 10 armack 0
    Spider|/give 10 armsptk 0
    Titan (Bantha)|/give 10 armbanth 0
    Butler - Fast Assist / Repair Bot|/give 10 armfark 0
    DUMMYX TEST UNIT|/give 10 armcom 0
Buildings
    Construction Turret|/give 1 armnanotc 0
    Tech 2 Lab|/give 1 armalab 0
    Tech 3 Lab|/give 1 armshltx 0
    Advanced Radar|/give 1 armarad 0
    Shield|/give 1 armgate 0
Weapons
    Anti Missile (Ferret)|/give 1 armferret 0
    Flak|/give 1 armflak 0
    Big Bertha|/give 1 armbrtha 0
    Mobile Tachyon Weapon|/give 2 armmanni 0
    Ragnarok - Rapid-Fire Long-Range Plasma Cannon|/give 1 armvulc 0
Aircraft
    Strategic Bomber|/give 20 armpnix 0
    Atomic Bomber|/give 2 armliche 0
    Advanced Construction Aircraft|/give 10 armaca 0
Game Commands
    Cheat ON|/cheat
    Infinite resources|/give resourcecheat 0
    Toggle Visibility|/globallos 0
    God mode control any unit|/godmode
    No cost ON|/nocost
    No cost OFF|/nocost 0
```

## Running on Linux

`bar_cheat.ahk` is a single cross-platform source: the same file runs on Windows
(official AutoHotkey v2) and on the [AutoHotkey v2 Linux port](https://github.com/MonoEven/Autohotkey_Linux)
(v2.0.26-linux.23) with no edits. On Linux it uses the port's **X11 backend**
for the global hotkey and a `/dev/uinput` virtual keyboard to type and submit
the cheat code. Technical internals, port quirks and debugging recipes live in
[docs/linux-port-internals.md](docs/linux-port-internals.md).

### Distrobox (immutable distros, e.g. Fedora Silverblue)

On immutable (atomic) distros such as Fedora Silverblue the root filesystem is
read-only, so run AutoHotkey in a **distrobox** container instead of layering
the package (a layer is dropped on the next rebase). The steps below were
tested on **Fedora Silverblue 44 / GNOME Wayland with Flatpak BAR**; other
distrobox hosts work too, adjusting the Flatpak/display notes as needed. The
Flatpak BAR exposes only the X11 socket, and distrobox wires up the display,
D-Bus and devices automatically.

1. Create the container (once):
   ```bash
   distrobox create --name ahk --image ubuntu:24.04
   ```

2. Install AutoHotkey inside it (once). Ubuntu 24.04 is required: Fedora 44's
   libjpeg-turbo no longer ships `libjpeg.so.8`, which the AHK runtime needs.
   ```bash
   distrobox enter --name ahk
   curl -fLO https://github.com/MonoEven/Autohotkey_Linux/releases/download/v2.0.26-linux.23/autohotkey-linux-2.0.26-linux.23-amd64.deb
   sudo apt install ./autohotkey-linux-2.0.26-linux.23-amd64.deb
   ahk --version          # then leave the container with: exit
   ```

3. Let the cheat type into the game (once, on the host). This makes
   `/dev/uinput` writable, so pasting types the code and presses Enter with no
   permission dialog:
   ```bash
   echo 'KERNEL=="uinput", MODE="0666"' | sudo tee /etc/udev/rules.d/60-ahk-uinput.rules
   sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=uinput
   ls -l /dev/uinput      # expect crw-rw-rw-
   ```

4. Run the cheat from the host:
   ```bash
   cd /path/to/AutoHotkey
   ./run_bar_cheat_distrobox.sh
   ```

In the game, press **Alt+C** with the game focused, pick a cheat and press
**Paste**: the code is typed into the console and submitted automatically. The
launcher can be started from anywhere and uses the X11 backend by default.

#### Starting the cheat (after the one-time setup)

The four steps above are one-time. To actually use the cheat, just run the
launcher from the repo:

```bash
cd /path/to/AutoHotkey
./run_bar_cheat_distrobox.sh
```

That wrapper enters the `ahk` container and starts the script for you. If you
prefer to do it by hand, the equivalent is:

```bash
distrobox enter --name ahk
cd ~/AutoHotkey                    # adjust if your checkout is elsewhere
AHK_INPUT_BACKEND=x11 ahk bar_cheat.ahk
```

Then press **Alt+C** with the game focused to open the cheat window.

### Debian / Ubuntu (native)

Download the AutoHotkey v2 Linux port `.deb` from the
[releases page](https://github.com/MonoEven/Autohotkey_Linux/releases) (or use
the pinned version below) and install it:

```bash
curl -fLO https://github.com/MonoEven/Autohotkey_Linux/releases/download/v2.0.26-linux.23/autohotkey-linux-2.0.26-linux.23-amd64.deb
sudo apt install ./autohotkey-linux-2.0.26-linux.23-amd64.deb
ahk --version
```

Then run the script directly (the `run_bar_cheat_distrobox.sh` launcher in the
Distrobox section is only for distrobox-based setups):

```bash
cd /path/to/AutoHotkey
AHK_INPUT_BACKEND=x11 ahk bar_cheat.ahk
```

An Xorg session works out of the box. On Wayland the script uses the
X11/XWayland lane (the Flatpak BAR already renders in XWayland).

### Windows Subsystem for Linux (WSL2) - testing only

WSL2 is intended mainly for **testing the GUI** (tabs, layout, images) during
development. WSLg provides an X display so the GTK window opens, but stock WSL2
has no usable input backend: the global Alt+C hotkey is not delivered to the
script, so `bar_cheat.ahk` just sits there with no window (the terminal swallows
Alt+C as `^[c`). This is not a supported way to cheat in a real game.

Install AutoHotkey with the Debian/Ubuntu steps above, then generate and run the
diagnostic build, which auto-opens the GUI about a second after start and writes
a `wsl_dbg.log` census next to the script:

```bash
cd /path/to/AutoHotkey
python3 gen_wsl.py
AHK_INPUT_BACKEND=x11 ahk bar_cheat_wsl.ahk
```

Do **not** use `run_bar_cheat_distrobox.sh` here: it is specific to
distrobox-based setups (immutable distros) and fails with
`distrobox: command not found` elsewhere.

See [docs/linux-port-internals.md](docs/linux-port-internals.md) for the WSL
debugging recipes.

### Other Linux (tarball, no root)

`libjpeg-turbo` 2.x/3.0.x is required (Fedora 44+ is not suitable):

```bash
tar xf <tarball>
./tools/linux/install.sh --prefix ~/.local --yes
export PATH="$HOME/.local/bin:$PATH"     # add to ~/.bashrc
```

### Notes & troubleshooting

- **The one-time `/dev/uinput` rule matters.** Without it, pasting falls back to
  XTEST text: a "remote interaction" Allow/Share dialog appears on first use,
  and you must press Enter yourself to submit. `run_bar_cheat_distrobox.sh`
  prints the rule whenever `/dev/uinput` is not writable.
- **Normal Enter keeps working in other applications**: on Linux the script no
  longer grabs Enter/Escape globally (the Enter grab exists only while the
  cheat window is focused).
- **Change the hotkey** by editing `Hotkey=` in `bar_cheat.ini` (for example
  `^!c`); the port's Settings hotkey box is unreliable.
- **Settings and state** (`bar_cheat.ini`, recents, favorites, tree state) live
  in the script folder, which must be writable.
- **Stock WSL2** can only preview the GUI (no input backend); run
  `bar_cheat_wsl.ahk` to auto-open it - see the WSL2 section above and the
  internals doc.
- **Diagnostics**: `distrobox enter ahk -- ahk --diag` reports the input
  backend and whether `/dev/uinput` is writable.


## Other Test Scripts

You can ignore these.

### test1.ahk

This script is used to test the functionality of Auto Hot Key. It opens a new notepad window and types "Hello World" in it.

### guilist.ahk

This script is used to automate the process of selecting a value from a list of values in a GUI window. It opens a GUI window with a list of values, and allows the user to select a value from the list.

