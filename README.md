# Auto Hot Key Scripts

For Windows, I use Auto Hot Key to automate some tasks. Here are some of the scripts I use.

## Scripts

### test1.ahk

This script is used to test the functionality of Auto Hot Key. It opens a new notepad window and types "Hello World" in it.

### guilist.ahk

This script is used to automate the process of selecting a value from a list of values in a GUI window. It opens a GUI window with a list of values, and allows the user to select a value from the list.

### bar_cheat.ahk

This script is used to automate the process of cheating in the "Beyond All Reason" game. It opens a GUI window with a treeview list of possible objects to create.

#### Requirements

- [AutoHotkey v2.0](https://www.autohotkey.com/) installed

#### How to Run

1. Double-click `bar_cheat.ahk` (or right-click it and choose "Run Script"). This runs the script in the background with no visible window.
2. In the game, press **Enter** to open the chat/console window. This is required — the script types the cheat code into it.
3. With the game running, press the hotkey (default **Alt+C**, configurable via `bar_cheat.ini`, see Notes) to open the cheat code GUI.
4. Optionally type in the **Search** box to filter the tree as you type (e.g. "big berth"). With matches shown, Enter pastes the first match.
5. Select a cheat from the treeview, adjust the amount if needed, then press **Enter** (or click "Paste Code" / double-click the entry). The GUI closes and the cheat command is typed into the game's chat and submitted.
6. Press **Escape** in the GUI to close it without pasting.
7. Stop the script by right-clicking the green AutoHotkey "H" icon in the system tray and choosing "Exit".

Important: cheating requires the game to have cheats enabled — the host must run `/cheat` first (there's a "Cheat ON" entry in the Game Commands category).

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

`bar_cheat.ahk` is a single cross-platform source: the same file runs on
Windows (official AutoHotkey v2) and on the [AutoHotkey v2 Linux port](https://github.com/MonoEven/Autohotkey_Linux)
(v2.0.26-linux.23) with no edits. `LINUX-PORT.md` documents the small set of
porting accommodations built into it.

### 1. Install AutoHotkey for Linux

Download the package for your system from
[GitHub Releases](https://github.com/MonoEven/Autohotkey_Linux/releases), then:

- **Debian / Ubuntu (including WSL2):**
  ```bash
  sudo apt install ./autohotkey-linux-2.0.26-linux.23-amd64.deb
  ```
- **Fedora:**
  ```bash
  sudo dnf install ./autohotkey-linux-2.0.26-linux.23-x86_64.rpm
  ```
- **Any Linux (no root; easiest for distrobox/Silverblue):** extract the generic
  tarball and run its installer into `~/.local`:
  ```bash
  tar xf <tarball>
  ./tools/linux/install.sh --prefix ~/.local --yes
  export PATH="$HOME/.local/bin:$PATH"     # add to ~/.bashrc
  ```

Verify the install and that the script parses:

```bash
ahk --version
ahk --check bar_cheat.ahk
```

### 2. Run the cheat

```bash
cd /path/to/AutoHotkey
ahk bar_cheat.ahk
```

The GUI, tabs, unit tree, preview images, favorites and recents behave the same
as on Windows. State files (`bar_cheat.ini`, favorites, recents, tree state)
are read/written in the script folder, so the folder must be writable.

For startup diagnostics (parse/load errors), the script ships with a diagnostic
build that auto-opens the GUI and writes `./wsl_dbg.log`:

```bash
python3 gen_wsl.py      # regenerates bar_cheat_wsl.ahk from bar_cheat.ahk
ahk bar_cheat_wsl.ahk
```

### 3. Input caveats (hotkey + typing into the game)

The **game-facing features need a real input backend**, which depends on where
you run it:

- **Stock WSL2:** there is no `/dev/uinput` and no X server input grab, so the
  global **Alt+C** hotkey and `Send` into the game do **not** work. Use WSL2 to
  test/preview the GUI (run `bar_cheat_wsl.ahk`; the GUI auto-opens).
- **X11 / XWayland desktop session** (e.g. "GNOME on Xorg"): fully supported —
  Alt+C and typing the paste work out of the box (XTEST backend).
- **Native Wayland** (GNOME/KDE Wayland session): the global hotkey needs the
  port's optional GNOME Shell extension or the XDG portal path, and `Send`
  needs the libei consent flow (or the evdev/uinput daemon). See the port's
  [docs](https://monoeven.github.io/Autohotkey_Linux/). The simplest reliable
  lane today is an **Xorg session**.

### 4. Fedora Silverblue

Silverblue's root filesystem is immutable, so **don't** `rpm-ostree`-layer the
AHK RPM onto the host image (it pins a GUI runtime to the image, needs a reboot,
and is dropped on the next rebase). Instead, run AHK in a **distrobox**
container — mutable, and it wires up `$DISPLAY`/`$WAYLAND_DISPLAY`, XWayland,
D-Bus and devices automatically:

```bash
distrobox create --name ahk --image fedora:latest
distrobox enter --name ahk

# inside the container:
sudo dnf install ./autohotkey-linux-2.0.26-linux.23-x86_64.rpm   # or use the
#   ~/.local tarball install from section 1 — either works
ahk --version

# your home directory (incl. this repo) is mounted inside the container:
cd ~/Documents/AutoHotkey
ahk bar_cheat.ahk
```

Needed only once (pod/image create); afterwards it starts with
`distrobox enter --name ahk`. For the simplest input path on Silverblue choose
an **Xorg session** ("GNOME on Xorg") at login rather than Wayland.

