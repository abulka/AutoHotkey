# Linux Port — Internals & Maintenance Guide

Audience: future maintainers/agents working on the Linux lane of
`bar_cheat.ahk`. This is the technical source of truth; user-facing
installation lives in [`README.md`](../README.md).

- **README.md** — install/run instructions for users (Windows + Linux).
- **docs/linux-port-internals.md** — this file: environment, architecture, port
  defects and their workarounds, testing recipes, history.
- **code comments** — line-level specifics next to each workaround.

Do not duplicate the sections here into the README; link instead.

---

## 1. Environment

- **Host**: Fedora Silverblue 44, GNOME 50, native Wayland (machine used while
  developing: `hp-g9`).
- **Game**: Beyond All Reason as Flatpak `info.beyondallreason.bar` (Electron +
  Spring). The sandbox exposes only `sockets=x11` — no Wayland socket — so the
  game renders through **XWayland**. Window title `Beyond All Reason (Spring ...)`,
  `WM_CLASS = "spring","spring"`.
- **AutoHotkey**: [AutoHotkey v2 Linux port](https://github.com/MonoEven/Autohotkey_Linux)
  v2.0.26-linux.23 inside a **distrobox** container named `ahk`
  (`ubuntu:24.04`). Ubuntu is required: the runtime links `libjpeg.so.8`, which
  Fedora 44's libjpeg-turbo 3.1+ no longer ships (no compat package), so the
  RPM/tarball fail on the host with `ahk_core: error while loading shared
  libraries: libjpeg.so.8`. Never `rpm-ostree`-layer AHK onto Silverblue.
- **Launcher**: `run_bar_cheat_linux.sh` runs
  `distrobox enter --name ahk -- bash -lc "cd ~/AutoHotkey && AHK_INPUT_BACKEND=$BACKEND ahk bar_cheat.ahk"`.
  `AHK_BACKEND` overrides the default `x11`; it also prints the `/dev/uinput`
  udev rule when the device is not writable.
- **Container tooling** (installed during development): `Xvfb`/`xvfb-run`,
  `xdotool`, `xinput`, `xev`, `wmctrl`, `imagemagick` (`import`/`convert`),
  `xclip`.

## 2. Architecture: one source, two interpreters

`bar_cheat.ahk` is the single cross-platform source. It runs unchanged on
Windows (official AHK v2) and on the Linux port; everything Linux-specific is
gated by `IsWslPort`.

- **Platform detection** — the port throws on `DllCall("user32\...")`
  (`"Windows DLL is not available on Linux"`), so the script feature-detects
  once at startup (the port also lacks `A_OSType`):

  ```ahk
  global IsWslPort := DetectWslPort()
  DetectWslPort() {
      try { DllCall("user32\GetForegroundWindow"); return false }
      return true
  }
  ```

- **GDK backend** — distrobox sets both `DISPLAY` and `WAYLAND_DISPLAY`. GTK3
  then prefers Wayland and creates a native-Wayland GUI window, which the
  port's `WinActive`/`WinActivate` cannot see (they are X11-only). The script
  therefore sets `GDK_BACKEND=x11` before GTK initialises, but only when
  `DISPLAY` exists (pure-Wayland systems still get a GUI):

  ```ahk
  if IsWslPort {
      try {
          if EnvGet("DISPLAY") != ""
              EnvSet("GDK_BACKEND", "x11")
      }
  }
  ```

- **Generated artifacts** (do not hand-edit):
  - `bar_cheat_wsl.ahk` — diagnostic build produced by `python3 gen_wsl.py`.
    It injects `#Warn All, Off`, an `OnError` logger to `wsl_dbg.log`, a
    startup census (categories/recents/favorites counts) and a timer that
    auto-opens the GUI. Used for headless/UI inspection.
  - `bar_cheat_linux.ahk` — byte-identical copy of `bar_cheat.ahk` (keep in
    sync with `cp` + `diff -q`).
- **State files** — `bar_cheat.ini`, `bar_cheats_recent.txt`,
  `bar_cheats_favorites.txt`, `bar_treeview_state.txt` are written next to the
  script (gitignored).
- **Windows paths are untouched**: new code is either inside `if IsWslPort`
  branches or only ever called from one.

## 3. Input pipeline

### 3.1 Global hotkey

- Default **Alt+C**, configurable via `Hotkey=` in `bar_cheat.ini`. On the port
  it is registered with `Hotkey()` and grabbed with XGrabKey (x11 backend),
  which works while the game is focused. Press it with the **game** focused.
- The port's Settings hotkey box is blank/unusable — edit the ini instead.
- The **portal** backend was tested and rejected: its GlobalShortcuts binding
  dies with the remote session, and it caused console toggle-looping.

### 3.2 Enter/Escape — why there are no global grabs on Linux

The original script had `#HotIf WinActive("BAR Cheat")` + `Enter::`/`Escape::`.
On the port, a passive XGrabKey is global: when the `#HotIf` criterion is
false, the runtime re-injects the key with **XTEST**
(`core_hotkey_linux.cpp`, audit P0-3). Fedora's libei-bridged XWayland silently
drops XTEST **non-text** keys, so the re-injected Enter vanished — in the game
and in every other application — for as long as the script ran. Numpad Enter
worked because it is a different keycode. This was the real cause of the
system-wide Enter loss (not GNOME/libei itself; confirmed with `xev` after
stopping the old instance).

Linux changes:

- No Enter/Escape hotkey registration at startup.
- `PortFocusWatch()` (100 ms timer) toggles `Hotkey("Enter", ..., "On"/"Off")`
  based on `WinActive("BAR Cheat")`. `Hotkey(..., "Off")` performs XUngrabKey,
  so Enter is only grabbed while the cheat window is focused.
- Escape is handled by `gGui.OnEvent("Escape", CloseGui)` (the port's GTK
  window key handler; verified working under Xvfb).
- Windows keeps the original `HotIfWinActive` runtime registration unchanged.

### 3.3 Typing and auto-submit: the uinput virtual keyboard

With `DISPLAY` set, the port always sends through XTEST
(`core_input_linux.cpp` → `LinuxFakeKey`: uinput is only used when there is no
X display). XTEST text needs the libei **RemoteDesktop** consent ("remote
interaction" Allow/Share) and non-text keys are dropped, so Enter cannot be
sent. The script therefore owns its own virtual keyboard:

- `PortUinputAvailable()` creates a `/dev/uinput` device once per process:
  - `open("/dev/uinput", O_WRONLY|O_NONBLOCK)` via libc `DllCall`.
  - `UI_SET_EVBIT` (`0x40045564`) for `EV_KEY` (1) and `EV_REL` (2);
    `UI_SET_KEYBIT` (`0x40045565`) for keycodes 1..0x2FE;
    `UI_SET_RELBIT` (`0x40045566`) for `REL_X` (0) / `REL_Y` (1).
  - `struct uinput_setup` (92 bytes): `BUS_USB` (3), vendor `0x2C2F`,
    product `0x0002`, name `"BAR Cheat virtual keyboard"`, then
    `UI_DEV_SETUP` (`0x405C5503`) and `UI_DEV_CREATE` (`0x5501`).
  - Sleeps 150 ms so libinput/compositor register the device.
- `PortUinputEvent(type, code, value)` writes one 24-byte `input_event`
  (x86_64: 16-byte timeval + u16 type + u16 code + s32 value) followed by a
  `SYN_REPORT` frame, then returns whether the write succeeded.
- `PortUinputCharMap()` maps printable US-layout ASCII to evdev keycodes plus a
  shift flag; `PortUinputTypeText()` types a string (pre-validates the whole
  string; unmapped characters abort to the fallback); `PortUinputEnter()` sends
  `KEY_ENTER` (28) down/up.
- `DoPaste()` Linux flow: activate the game → `PortUinputEnter()` (open console)
  → type the code → `PortRestorePointer()` → `PortUinputEnter()` (submit).
  The code is also copied to the clipboard as a backup.
- The script never uses XTEST for the paste, so no portal consent dialog
  appears and normal Enter/Escape are unaffected.

### 3.4 Pointer restore (spawn position)

`/give` spawns at the pointer's world position. On Windows the flow moves the
cursor back to where it was when the cheat window opened before the final
Enter; Linux must do the same or units spawn where the cursor sat over the
hidden GUI.

- `ShowGui()` captures the cursor with `CoordMode("Mouse", "Screen")` +
  `MouseGetPos(&mouseX, &mouseY)` when the hotkey is pressed.
- `PortRestorePointer(x, y)` uses **`XWarpPointer`** through
  `libX11.so.6` (`XOpenDisplay(NULL)` → `XDefaultRootWindow` →
  `XWarpPointer` → `XFlush` → `XCloseDisplay`). XWarpPointer is a core X11
  request, not XTEST, so it needs no consent and works from a background
  client on XWayland.
- A relative uinput pointer was implemented first (`PortUinputMoveBy`) but
  **GNOME ignores relative motion from uinput pointer devices** (verified with
  a pointer-only device), so it remains only as a non-X fallback.

### 3.5 Host permission fix (the one-time sudo step)

The distrobox container shares the host's `/dev/uinput`, but it is root-only by
default (`crw------- root root`). The runtime cannot type until the device is
writable, so the host needs a one-time udev rule (Silverblue keeps `/etc`
across rebases):

```bash
echo 'KERNEL=="uinput", MODE="0666"' | sudo tee /etc/udev/rules.d/60-ahk-uinput.rules
sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=uinput
ls -l /dev/uinput      # expect crw-rw-rw-
```

- `run_bar_cheat_linux.sh` prints exactly this when `/dev/uinput` is not
  writable.
- Verification performed on the real session: the virtual device typed a full
  string (upper/lowercase, digits, `/`, spaces) into a focused GTK entry,
  `PortUinputEnter` inserted a newline and activated a focused button, and
  `xev` showed the injected `Return` KeyPress/KeyRelease events.

### 3.6 Fallback path (no `/dev/uinput`)

If the rule is missing, `DoPaste` falls back to `SendText` over XTEST:

- Requires the one-time libei "remote interaction" Allow/Share consent.
- Types text only; you must press Enter yourself to submit.
- Still no global Enter grab, so other apps are unaffected.

## 4. Port defects and their workarounds

All workarounds live in the `; ---- Linux port UI/input workarounds ----`
section of `bar_cheat.ahk` and are dead code on Windows. Delete them when a
later port release fixes the underlying defect. Port source references are to
`MonoEven/Autohotkey_Linux` (branch `linux-port`, release linux.23).

| Symptom on Linux | Cause in the port | Workaround |
|---|---|---|
| Second `DllCall` with the same `"lib\func"` literal fails with *Call to nonexistent function* | `core_dllcall_linux.cpp` splits the spec **in place** (writes NUL at the backslash), corrupting the literal | `PortDll(lib, func, params*)` rebuilds the spec at runtime |
| `DllCall` fails from inside a recursive function | port DllCall is not re-entrant | `PortFindTreeByColumns` is iterative (explicit queue) |
| `Invalid arg type` for `"uint"`/`"uptr"` | the port's unsigned-type check is case-sensitive (`'U'`) | use `"UInt"`/`"UPtr"` |
| `.Hwnd` cannot be passed to GTK functions | script-visible Hwnd values are opaque 32-bit handles, not pointers (`to_hwnd` in `script_gui_linux.cpp`) | locate real widgets via `gtk_window_list_toplevels` + title + `g_type_check_instance_is_a`; cache per handle (`PortTreeWidget`) |
| `TreeView.Add(..., "Expand")` / `Modify(id, "Expand"/"Select")` do nothing | `TV_AddModify` ignores its options (`(void)aOptions`) | `PortTreeExpandAll` / `PortTreeExpandItem` / `PortTreeSelectItem` call GTK directly |
| Double-click on a unit starts a label edit instead of pasting | the port always creates the tree renderer with `editable=TRUE` | `PortDisableTreeEdit` sets the `editable` GObject property FALSE via a GValue (`G_TYPE_BOOLEAN` = 20; GTK3 has no setter symbol) |
| ~24 px blank row above the first category on the Units tab | the port calls `gtk_tree_view_set_headers_visible(FALSE)` for ListBox but not TreeView | `PortDisableTreeEdit` also calls it for the tree |
| `GtkTreeView` not accepted as `GtkCellLayout` | in GTK3 the **column** implements `GtkCellLayout`, not the view | get `gtk_tree_view_get_column(view, 0)` first |
| Recent/Favorites/Meta status line, amount and preview never update | the port never raises ListBox `Change`; GTK `cursor-changed` is dispatched as unsupported `ItemFocus` | `PortUiWatch` (150 ms) polls the active list's `.Value` and calls `ListSelectionChanged` |
| Double paste / double click actions | the port dispatches `Click` on press **and** release, and `DoubleClick` from both the button event and `row-activated` | `PortClick(fn)` runs only when info == 0; `PasteSelectedCode` debounces 350 ms (`LastPasteFire`) |
| Search field overlaps the list / looks crushed | single-line Edit minimum height is 34 px (`h24` is ignored) | layout metrics in `GuiLayout()`: port label y48 / entry y40 (bottom y74) / lists y76 h188 (expanded 454); Windows keeps label y34 / entry y32 / lists y56 h204 (expanded 474) |
| Window position never remembered | `WinGetPos("ahk_id ...")` cannot resolve opaque handles; GTK reports the first-show position once the window is hidden | `SaveWindowPos` reads `gtk_window_get_position` on the real GtkWindow **only while visible**; `DoPaste` saves before hiding; remember-position defaults to on |
| `WinActivate`/`WinExist` with `ahk_id` throw | opaque handles; title matching is case-sensitive substring | `FindGameWindow`/`GameWinCriteria` return title strings; calls wrapped in `try` |
| Native-Wayland GUI invisible to `WinActive` | GTK backend selection when both `DISPLAY` and `WAYLAND_DISPLAY` are set | `EnvSet("GDK_BACKEND", "x11")` before GTK init |
| `SendMessage`/`TVM_ENSUREVISIBLE`, dark title bar, redraw gestures | Windows-only or inert on the port | wrapped in `try` / tolerated no-ops |

Porting-fold behaviors kept from session 1 (still required):

- Forward-slash paths only (`A_ScriptDir "/file"`); the port does **not**
  translate `\`, and ghost files named `\bar_cheats.txt` shadow real data.
- `Integer()`/`Number()` coercions for GUI `.Value`.
- `PortClick` on every `OnEvent("Click", ...)` binding (press + release fire).
- List removal by rebuild instead of `SendMessage` row deletion.
- Pictures cannot be cleared on the port (`Value := ""` breaks the control);
  `LoadUnitImage`/`ClearSelectionUI` skip clearing when `IsWslPort`.

## 5. Testing & debugging playbook

**`ahk --check` does not parse the script** — it only reports install
integrity. To validate syntax/load without a blocking dialog, use the
*top-sentinel* technique:

1. Copy `bar_cheat.ahk` to a scratch dir with its data files.
2. Immediately after `#Requires AutoHotkey v2.0` insert:
   `FileAppend("PARSE_OK", A_ScriptDir "/syn_ok.txt")` + `ExitApp`.
3. Run it under `xvfb-run` (see below); if the file parsed, the sentinel is
   written. A failing file leaves the sentinel absent (the port shows a modal
   error dialog that would otherwise hang the run).

Running headless:

```bash
xvfb-run -a -s "-screen 0 1280x900x24" bash -c \
  'export GDK_BACKEND=x11 AHK_INPUT_BACKEND=x11; ahk script.ahk'
```

Useful checks:

- **Diagnostic build**: `python3 gen_wsl.py` then run `bar_cheat_wsl.ahk`; it
  auto-opens the GUI and writes `wsl_dbg.log` (census + OnError entries).
- **Screenshots**: `import -window root shot.png`; zoom a region with
  `convert shot.png -crop 440x170+0+0 +repage -resize 300% crop.png`. Reading
  the PNG back is the fastest way to verify layout changes.
- **Window geometry**: `wmctrl -lG` (frame x/y/w/h) and
  `xdotool getwindowgeometry`. Without a window manager (raw Xvfb) these are
  unreliable.
- **Input**: `xev -event keyboard` verifies delivered keysyms;
  `xinput`/`xinput test-xi2` verifies devices. **On the real Fedora session,
  XTEST non-text keys are dropped, so `xdotool key`/`mousemove` cannot test
  the Alt+C hotkey or inject Enter there.** Under Xvfb, XTEST works normally.
- **Install/backend state**: `ahk --diag` reports the selected backend,
  `uinput-writable`, libei state, GNOME extension presence, etc.
- **Game-not-found debug dump**: `DoPaste` writes `paste_dbg.log` in the
  script dir when `FindGameWindow()` fails.

Pitfalls:

- `pkill -x ahk_core` kills **every** instance, including the user's running
  cheat. Avoid `pkill -f <pattern>` patterns that match their own shell
  command line (that kills the calling shell).
- Test scripts need `#Warn All, Off`: the port surfaces `VarUnset` warnings as
  modal dialogs *before* the script runs, which looks like a parse failure.
- Always kill leftover `Xvfb`/`ahk_core` test processes; stale instances hold
  X grabs and XTEST sessions.
- Test in a scratch directory with copied data files, not the repo root, to
  avoid touching the user's state (`bar_cheat.ini`, recents, tree state).

## 6. File & symbol map

| Path | Purpose |
|---|---|
| `bar_cheat.ahk` | single source (Windows + Linux) |
| `bar_cheat_linux.ahk` | byte-identical copy for branch checkouts |
| `bar_cheat_wsl.ahk` | generated diagnostic build (`gen_wsl.py`) |
| `run_bar_cheat_linux.sh` | host launcher (distrobox, x11 backend, uinput hint) |
| `gen_wsl.py` | injects OnError logger + startup census + auto-open GUI |
| `bar_cheats.txt`, `bar_cheats_recent.txt`, `bar_cheats_favorites.txt` | data (recents/favorites gitignored) |
| `bar_cheat.ini`, `bar_treeview_state.txt` | settings/state (gitignored) |
| `unit_images/` | unit preview PNGs |
| `docs/linux-port-internals.md` | this file |

Key functions in `bar_cheat.ahk` (Linux-relevant):

- Platform/plumbing: `DetectWslPort`, `PortClick`, `PortDll`,
  `PortFocusWatch`, `PortUiWatch`.
- GTK widget access: `PortTreeWidget`, `PortFindWindow`, `PortFindUnitsTree`,
  `PortFindTreeByColumns`, `PortTreePath`, `PortTreeIndex`,
  `PortTreeExpandItem/All`, `PortTreeSelectItem`, `PortDisableTreeEdit`.
- Input: `PortUinputAvailable/Event/CharMap/TypeText/Enter/MoveBy`,
  `PortRestorePointer`.
- Flow: `ShowGui`, `DoPaste`, `PasteSelectedCode`, `CloseGui`,
  `SaveWindowPos`, `UpdateAmountArea`.

Port source files worth reading when something breaks
(`MonoEven/Autohotkey_Linux`):

- `source/linux/core/core_input_linux.cpp` — transport selection
  (`LinuxFakeKey`: XTEST when a display exists, uinput only without one).
- `source/linux/core/core_hotkey_linux.cpp` — XGrabKey handling and the XTEST
  passthrough re-injection (P0-3).
- `source/linux/core/core_uinput_linux.cpp` — reference uinput device setup.
- `source/linux/core/core_dllcall_linux.cpp` — spec splitting, type parsing.
- `source/linux/gui/script_gui_linux.cpp` — GTK controls, click dispatch,
  ListBox/TreeView events, tab offsets (`TAB_CONTENT_X/Y`), opaque handles.
- `source/linux/core/core_win_linux.cpp` — window management (X11 only).

## 7. History (condensed)

**Session 1 — first working setup (compromise)**

- Installed linux.23 in a distrobox; Fedora 44 cannot run it (libjpeg.so.8) →
  Ubuntu 24.04 container.
- Chose the **x11 backend**: Alt+C via XGrabKey always works; the portal
  backend was rejected (hotkey dies with the session, console toggling).
- Discovered XTEST text passes only with RemoteDesktop consent and that XTEST
  non-text keys are dropped on Fedora; workaround was manual Enter.
- Folded portability into the single source: forward-slash paths,
  `Integer()` coercions, `PortClick`, rebuild-based list removal, try-wrapped
  win32 calls.

**Session 2 — root causes and proper fixes**

- Identified the global Enter/Escape grabs + failed XTEST passthrough as the
  system-wide Enter loss; removed them on Linux (`PortFocusWatch` + GUI Escape
  event).
- Implemented the uinput virtual keyboard for text + Enter (auto-submit) and
  documented the one-time host udev rule; verified typing, Enter and `xev`
  delivery on the real session.
- Fixed the GUI bugs: double-click label edit, ignored Expand/Select options,
  stale Recent/Favorites/Meta status, Meta paste button, search auto-expand,
  window position memory, spawn-at-pointer via XWarpPointer, and layout issues
  (search box height, empty TreeView header).
- Mapped the port defects behind each symptom (section 4) so future agents can
  distinguish script bugs from port bugs.

## 8. Open items / limitations

- **Upstream the port defects.** The workarounds are removable once
  `MonoEven/Autohotkey_Linux` fixes the listed defects; consider filing
  issues/PRs with the symptom table.
- **uinput relative pointer** is ignored by GNOME; keep XWarpPointer.
- **Fallback XTEST path** still needs consent + manual Enter; only relevant if
  `/dev/uinput` cannot be made writable.
- **Native-Wayland hotkeys/capture** (GNOME extension / portal / inputd) remain
  port work; the script intentionally uses the X11/XWayland lane.
- **Windows smoke test**: all Linux code is gated, but shared functions
  (`DoPaste`, `UpdateAmountArea`, layout constants, `SaveWindowPos`) are edited
  in place — re-run a quick pass on Windows after changes.
- **Regenerate artifacts** after any `bar_cheat.ahk` edit:
  `cp bar_cheat.ahk bar_cheat_linux.ahk && python3 gen_wsl.py`.
