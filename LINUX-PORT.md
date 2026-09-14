# Linux Port — Operating Notes

## One source, two interpreters

Since the **Option A** fold, `bar_cheat.ahk` is the single cross-platform source.
It runs unchanged on Windows (standard AutoHotkey v2) **and** on the Linux port
(AHK v2.0.26-linux.23). There is no separate `bar_cheat_linux.ahk` maintenance
anymore.

```
bar_cheat.ahk            <- single source of truth (Windows + Linux)
   │  gen_wsl.py injects a debug wrapper (OnError logger + startup census)
   ▼
bar_cheat_wsl.ahk        <- generated diagnostic build, used on WSL/Silverblue
```

- `bar_cheat_wsl.ahk` is a **generated artifact** — regenerate it, don't edit it
  by hand. Add `bar_cheat_wsl.ahk` to `.gitignore` if it becomes noise; it is
  committed right now for convenience.
- `bar_cheat_linux.ahk` is kept as a byte-identical copy of `bar_cheat.ahk`
  (verified with `diff`). Drop it whenever you like — it exists only so a
  branch checkout can run the port without running the generator first.

## How the single source detects the platform

The port throws on `DllCall("user32\...")` ("Windows DLL is not available on
Linux"), so `IsWslPort` is a one-time feature-detect, NOT a platform variable
(the port lacks `A_OSType`):

```
DetectWslPort() {
    try { DllCall("user32\GetForegroundWindow"); return false }
    return true
}
```

`if !IsWslPort` gates the Windows-only behaviors that must differ on the port:
clearing Picture controls (`ClearSelectionUI`, `LoadUnitImage`).

## The porting fold (what made the original cross-platform)

1. Forward-slash paths — the port does **NOT** translate `\` to `/`. Ghost
   files literally named `\bar_cheats.txt` shadowed real data in the script dir
   (this was the "nothing has changed" bug). `A_ScriptDir "/file"` works on both.
2. `Integer()`/`Number()` coercions for GUI `.Value` (port is strict: strings
   rejected where numbers are expected).
3. `PortClick(fn)` wrapper on every `OnEvent("Click", ...)` binding — the port
   fires `Click` on **both** mouse-press (event info = button#) and
   mouse-release/keyboard (info = 0). The wrapper runs the handler only when
   `info == 0`, so one physical click = one action. On Windows info is 0 for a
   click, so it passes straight through. No debounce, rapid clicking preserved.
4. Remove-from-list is done by rebuild (`UpdateFavList`/`UpdateRecentList`)
   instead of win32 `SendMessage` (inert/LB_GETCOUNT=0 on the port's GTK
   listboxes) — verified on Windows-equivalent path and harmless there.
5. win32 bits (`WithListRedrawSuppressed` scroll/redraw, `DeleteListItemInPlace`
   InvalidateRect, `DwmSetWindowAttribute` dark title bar, `WinActivate`
   guards) all wrapped in `try` — full behavior on Windows, silent no-ops on
   the port (inert messages / throwing but caught DllCalls).
6. `cheatNameFromItem` guards `GetSelection() == 0` (the port may not track a
   scripted selection; `GetText(0)` would hang).

## Workflow

- Edit `bar_cheat.ahk` (any platform). Regenerate the debug build:
  `python3 gen_wsl.py` (reads `/tmp/bar_proj/bar_cheat_linux.ahk` — update the
  source path if it moves).
- Run on WSL: `cd <repo> && /home/andy/.local/bin/ahk bar_cheat_wsl.ahk`
  (set `WAYLAND_DISPLAY=` if using Xvfb so GTK doesn't hit the WSLg compositor).
- Diagnostic output: `wsl_dbg.log` (gitignored).

## Verified on Linux port (Xvfb quarantine)

- Parse + full GUI render, 8 categories / 192 unit images / recents / favorites.
- Favorite toggle + star marker in tree; favorite/recent removal (no throw);
  amount increment; image preview load; click-double-fire fixed (PortClick).
- Interaction tested headless: synthetic clicks CANNOT be delivered to the port
  GUI in this sandbox; double-fire logic is proven from the port C++ source
  (`script_gui_linux.cpp`: press -> `signal_button` info=1, release ->
  `signal_clicked` info=0).

## Gates NOT yet done

- **Windows regressions (Phase 5 gate):** check out `bar_cheat.ahk` on real
  Windows AHK v2 and smoke-test — paths with `/`, guards no-op, PortClick
  single-fires, picture clearing still happens, dark title bar still sets,
  framerate/flicker unchanged. Then push/merge onward.
- Silverblue/Wayland: hotkey via GNOME portal and XTEST Send into BAR are still
  untested (WSL2 cannot exercise the input lane; needs `/dev/uinput`/inputd).