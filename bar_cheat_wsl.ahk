#Requires AutoHotkey v2.0
#Warn All, Off

; Ensure single instance
#SingleInstance Force

; Match window titles by substring (needed for the title-based game fallback)
SetTitleMatchMode(2)

; Cross-platform flag: the AHK Linux port cannot call Windows DLLs
; (DllCall("user32\...") throws "Windows DLL is not available on Linux"),
; so detect the platform once at startup instead of relying on variables
; like A_OSType, which the port does not implement.
;
; Run this script with the standard Windows AHK v2 interpreter on Windows,
; or with the Linux port build on WSL/Silverblue - all feature paths below
; switch on this flag.
global IsWslPort := DetectWslPort()
global EnterKey := IsWslPort ? "{NumpadEnter}" : "{Enter}"

; Keep the GTK GUI on the XWayland lane: the port's Win* functions (window
; activation, the "BAR Cheat" hotkey criterion) cannot see native-Wayland
; windows.  Only force it when an X display exists so pure-Wayland systems
; still get a GUI.
if IsWslPort {
    try {
        if EnvGet("DISPLAY") != ""
            EnvSet("GDK_BACKEND", "x11")
    }
}
global LastPasteFire := 0
global UinputFd := 0
global UinputTried := false
global UinputUsable := false
global PortTreeWidgets := Map()
global PortUiLastTab := -1
global PortUiLastRecent := -1
global PortUiLastFav := -1
global PortUiLastMeta := -1
DetectWslPort() {
    try {
        DllCall("user32\GetForegroundWindow")
        return false
    }
    return true
}

; Global variables
global gGui := ""
global mouseX := 0, mouseY := 0
global AmountBox := ""
global SearchBox := ""
global TabCtrl := ""
global FavList := ""
global FavSearchBox := ""
global FavBtn := ""
global RecentList := ""
global RecentSearchBox := ""
global MetaList := ""
global AmountGroup := ""
global HKBox := ""
global gStatus := ""
global CheatCodesFile := A_ScriptDir "/bar_cheats.txt"
global LastModified := ""
global RecentCheatsFile := A_ScriptDir "/bar_cheats_recent.txt"
global LastModifiedRecent := ""
global FavoritesFile := A_ScriptDir "/bar_cheats_favorites.txt"
global TreeView := ""
global TreeViewStateFile := A_ScriptDir "/bar_treeview_state.txt"
global ImageViewer := ""
global RecentImg := ""
global FavImg := ""
global ImgToggleBtn := ""
global cheatsData := Map()
global unitsData := Map()
global favData := []
global favDisplay := []
global favCheatData := []
global favNameSet := Map()
global metaListData := []
global recentData := []
global recentDisplay := []
global ConfigFile := A_ScriptDir "/bar_cheat.ini"
global GameWinCriteria := ["ahk_exe spring.exe", "Beyond All Reason"]
global CurrentHotkey := ""

; Returns the window title/criteria of the game window, or 0 if not found.
; (WinTitle strings work on Windows and the Linux port; raw hwnds and
; ahk_id/ahk_class do not match reliably on the Linux port.)
FindGameWindow() {
    global GameWinCriteria
    for criteria in GameWinCriteria {
        hwnd := WinExist(criteria)
        if hwnd
            return criteria
    }
    return 0
}

; Settings helpers (stored in bar_cheat.ini)
GetSetting(name, default) {
    global ConfigFile
    return IniRead(ConfigFile, "Settings", name, default)
}

SetSetting(name, value) {
    global ConfigFile
    IniWrite(value, ConfigFile, "Settings", name)
}

; Define hotkeys for when the cheat GUI is active.
; Windows keeps the classic context-sensitive label hotkeys.  On the Linux
; port a grabbed key whose #HotIf criterion is false is passed through with
; XTEST, which this environment drops for non-text keys - a grabbed
; Enter/Escape therefore vanishes system-wide while the script runs.
; Linux instead registers Enter only while the cheat window is focused
; (toggled by PortFocusWatch) and handles Escape through the GUI's own
; Escape event (see ShowGui), so no global grab is ever held.
if IsWslPort {
    HotIfWinActive("BAR Cheat")
    Hotkey("Enter", PasteSelectedCode, "Off")
    HotIf()
    SetTimer(PortFocusWatch, 100)
} else {
    HotIfWinActive("BAR Cheat")
    Hotkey("Enter", PasteSelectedCode)
    Hotkey("Escape", CloseGui)
    HotIf()
}

; === WSL GUI-INSPECT WRAPPER (diagnostic build; not part of the app) ===
DbgLog(msg) {
    FileAppend(msg "`n", A_ScriptDir "/wsl_dbg.log")
}
LogWslError(e, mode) {
    DbgLog("ERR: msg=" e.Message "  line=" e.Line "  what=" e.What "  extra=" e.Extra "  mode=" mode)
    return true
}
DbgStartup() {
    global unitsData, favData, favCheatData, recentData, TreeView, RecentList, FavList, MetaList
    global CheatCodesFile, RecentCheatsFile, FavoritesFile
    DbgLog("=== census ===")
    DbgLog("A_ScriptDir=" A_ScriptDir)
    DbgLog("A_WorkingDir=" A_WorkingDir)
    DbgLog("files: cheats=" FileExist(CheatCodesFile) " recent=" FileExist(RecentCheatsFile) " favs=" FileExist(FavoritesFile))
    DbgLog("paths: cheats='" CheatCodesFile "' recent='" RecentCheatsFile "' favs='" FavoritesFile "'")
    try {
        c := FileRead(CheatCodesFile)
        DbgLog("cheats FileRead len=" StrLen(c) "  head=" SubStr(c, 1, 40))
    } catch as x {
        DbgLog("cheats FileRead THROW: " x.Message)
    }
    DbgLog("dir has files: cheats2=" FileExist(A_ScriptDir "/bar_cheats.txt") " favs2=" FileExist(A_ScriptDir "/bar_cheats_favorites.txt"))
    try {
        all := LoadCheatCodes()
        DbgLog("LoadCheatCodes cats=" all.Count)
        for cat, lst in all
            DbgLog("  cat='" cat "'  len=" lst.Length)
    } catch as x {
        DbgLog("LoadCheatCodes census THROW: " x.Message)
    }
    try {
        DbgLog("unitsData cats=" (IsObject(unitsData) ? unitsData.Count : "n/a"))
        unitCount := 0
        if IsObject(unitsData)
            for cat, lst in unitsData
                unitCount += lst.Length
        DbgLog("unitsData items=" unitCount)
    } catch as x {
        DbgLog("census units failed: " x.Message)
    }
    try {
        DbgLog("favData=" (IsObject(favData) ? favData.Length : "n/a")
               "  favCheatData=" (IsObject(favCheatData) ? favCheatData.Length : "n/a")
               "  recentData=" (IsObject(recentData) ? recentData.Length : "n/a"))
    } catch as x {
        DbgLog("census data failed: " x.Message)
    }
    try {
        DbgLog("list count via data ok")
    } catch as x {
        DbgLog("census lists failed: " x.Message)
    }
    try {
        DbgLog("tree firstCategory=" TreeView.GetChild(0))
    } catch as x {
        DbgLog("census tree failed: " x.Message)
    }
}
OpenGuiForWsl() {
    global gGui
    try FileDelete(A_ScriptDir "/wsl_dbg.log")
    try {
        OnError(LogWslError)
    } catch as x {
        DbgLog("OnError unavailable: " x.Message)
    }
    try {
        ShowGui()
    } catch as e {
        MsgBox "ShowGui failed (WSL test): " e.Message "`nLine: " e.Line "`nExtra: " e.Extra
        ExitApp
    }
    DbgStartup()
    if IsObject(gGui)
        gGui.OnEvent("Close", (*) => (CloseGui(), ExitApp()))
}
SetTimer(OpenGuiForWsl, -1000)


; Registers the show-window hotkey, disabling the previous one.
; Returns true on success. Hotkey callbacks must accept the hotkey
; name parameter, hence the closure.
RegisterHotkey(hk) {
    global CurrentHotkey
    ; Reject empty names and bare modifier prefixes (e.g. "!", "^", "+") -
    ; AHK accepts them but they never trigger
    if hk = "" || RegExMatch(hk, "[#!^+*&~$<>]$")
        return false
    try {
        Hotkey(hk, (*) => ShowGui())
    } catch {
        return false
    }
    if CurrentHotkey != "" && CurrentHotkey != hk
        try Hotkey(CurrentHotkey, , "Off")
    CurrentHotkey := hk
    return true
}

SetupHotkey() {
    global ConfigFile
    if !FileExist(ConfigFile)
        IniWrite("!c", ConfigFile, "Settings", "Hotkey")
    hk := IniRead(ConfigFile, "Settings", "Hotkey", "!c")
    if !RegisterHotkey(hk) {
        ; Configured hotkey is invalid - fall back to Alt+C and repair the ini
        RegisterHotkey("!c")
        IniWrite("!c", ConfigFile, "Settings", "Hotkey")
    }
}

LoadCheatCodes() {
    global CheatCodesFile, RecentCheatsFile, LastModified, LastModifiedRecent

    ; Create default file if it doesn't exist
    if !FileExist(CheatCodesFile) {
        defaultCheats := "
        (
        Units
            Constructors|/give 10 armck 0
            Construction Kbot|/give 10 armack 0
            Spider|/give 10 armsptk 0
            Titan (Bantha)|/give 10 armbanth 0
            Butler - Fast Assist / Repair Bot|/give 10 armfark 0
            DUMMYC TEST UNIT|/give 10 armcom 0
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
        )"
        FileAppend(defaultCheats, CheatCodesFile)
        LastModified := FileGetTime(CheatCodesFile)
    } else {
        LastModified := FileGetTime(CheatCodesFile)
    }

    ; Create recent file if it doesn't exist
    if !FileExist(RecentCheatsFile) {
        FileAppend("Recent`n", RecentCheatsFile)
        LastModifiedRecent := FileGetTime(RecentCheatsFile)
    } else {
        LastModifiedRecent := FileGetTime(RecentCheatsFile)
    }

    ; Parse the main file; categories are split per tab in ShowGui
    return ParseCheatFile(FileRead(CheatCodesFile))
}

AddToRecent(cheatName, cheatCode) {
    recents := LoadRecents()

    ; Remove older invocations of the same cheat (name only - the newest wins)
    newRecents := []
    for r in recents {
        if r.name != cheatName
            newRecents.Push(r)
    }
    newRecents.InsertAt(1, {name: cheatName, code: cheatCode})
    SaveRecents(newRecents)
}

LoadRecents() {
    global RecentCheatsFile
    recents := []
    seen := Map()
    if FileExist(RecentCheatsFile) {
        content := FileRead(RecentCheatsFile)
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if !line || line = "Recent"
                continue
            parts := StrSplit(line, "|", , 2)
            ; Deduplicate by name (amount differences don't count)
            if parts.Length = 2 && !seen.Has(parts[1]) {
                seen[parts[1]] := true
                recents.Push({name: parts[1], code: parts[2]})
            }
        }
    }
    return recents
}

SaveRecents(recents) {
    global RecentCheatsFile
    content := "Recent`n"
    for r in recents
        content .= r.name "|" r.code "`n"
    if FileExist(RecentCheatsFile)
        FileDelete(RecentCheatsFile)
    FileAppend(content, RecentCheatsFile)
}

ParseCheatFile(content) {
    cheats := Map()
    currentCategory := "Uncategorized"

    Loop Parse, content, "`n", "`r" {
        line := Trim(A_LoopField)
        if !line
            continue

        ; Check if line is a category (no pipe character and not indented)
        if !InStr(line, "|") && SubStr(line, 1, 4) != "    " {
            currentCategory := line
            cheats[currentCategory] := []
            continue
        }

        ; If it's a cheat entry (contains pipe character)
        if InStr(line, "|") {
            cheatParts := StrSplit(Trim(line), "|")
            if cheatParts.Length = 2
                cheats[currentCategory].Push({name: cheatParts[1], code: cheatParts[2]})
        }
    }
    return cheats
}

LoadFavorites() {
    global FavoritesFile
    favs := []
    seen := Map()
    if FileExist(FavoritesFile) {
        content := FileRead(FavoritesFile)
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if !line || line = "Favorites"
                continue
            parts := StrSplit(line, "|", , 2)
            ; Deduplicate by name (amount differences don't count)
            if parts.Length = 2 && !seen.Has(parts[1]) {
                seen[parts[1]] := true
                favs.Push({name: parts[1], code: parts[2]})
            }
        }
    }
    return favs
}

SaveFavorites(favs) {
    global FavoritesFile
    content := "Favorites`n"
    for fav in favs
        content .= fav.name "|" fav.code "`n"
    if FileExist(FavoritesFile)
        FileDelete(FavoritesFile)
    FileAppend(content, FavoritesFile)
}

; The Linux port dispatches the Click event on BOTH mouse-press (event info =
; the pressed mouse button number) and mouse-release / keyboard activation
; (event info = 0).  Wrap handlers so only the release/activation event runs
; the action - one physical click = one call, no debounce needed.
PortClick(fn) {
    return (ctrl, info) => (info ? "" : fn.Call())
}

; ---- Linux port UI/input workarounds --------------------------------------
; The GTK3 backend of the Linux port has a few gaps the Windows build does
; not:
;   * TreeView item options ("Expand"/"Select") are ignored, so search
;     auto-expand and scripted selection never happen;
;   * the tree text renderer is always editable, so double-click starts a
;     label edit instead of activating the row;
;   * ListBox selection changes are dispatched as ItemFocus (unsupported by
;     ListBox) instead of Change, so the lists never update the status line;
;   * with an X display present Send always uses XTEST, which needs the libei
;     "remote interaction" consent and drops non-text keys.
; The helpers below drive GTK/uinput directly; Windows never calls them.

; The port's DllCall splits the "lib\function" string in place (it writes a
; NUL at the backslash), corrupting the string literal so that a repeated
; call with the same literal fails with "Call to nonexistent function".
; Build the spec at runtime so every call gets a fresh, disposable string.
PortDll(lib, func, params*) {
    return DllCall(lib "\" func, params*)
}

; Keeps the Enter hotkey grabbed only while the cheat window is focused.
; Hotkey(..., "Off") ungrabs it, so other applications always get Enter.
PortFocusWatch() {
    static wasActive := false
    active := false
    try
        active := WinActive("BAR Cheat") ? true : false
    if active = wasActive
        return
    wasActive := active
    try {
        HotIfWinActive("BAR Cheat")
        Hotkey("Enter", active ? "On" : "Off")
    } finally {
        HotIf()
    }
}

; The port never raises the ListBox Change event; poll the active list while
; the GUI exists so the status line, amount and preview stay in sync.
PortUiWatch() {
    global TabCtrl, RecentList, FavList, MetaList, gGui
    global PortUiLastTab, PortUiLastRecent, PortUiLastFav, PortUiLastMeta
    if !IsObject(gGui) || !IsObject(TabCtrl)
        return
    tab := TabCtrl.Value
    if tab != PortUiLastTab {
        PortUiLastTab := tab
        PortUiLastRecent := RecentList.Value
        PortUiLastFav := FavList.Value
        PortUiLastMeta := MetaList.Value
        if tab = 2
            ListSelectionChanged(RecentList)
        else if tab = 3
            ListSelectionChanged(FavList)
        else if tab = 4
            ListSelectionChanged(MetaList)
        return
    }
    if tab = 2 {
        value := RecentList.Value
        if value != PortUiLastRecent {
            PortUiLastRecent := value
            ListSelectionChanged(RecentList)
        }
    } else if tab = 3 {
        value := FavList.Value
        if value != PortUiLastFav {
            PortUiLastFav := value
            ListSelectionChanged(FavList)
        }
    } else if tab = 4 {
        value := MetaList.Value
        if value != PortUiLastMeta {
            PortUiLastMeta := value
            ListSelectionChanged(MetaList)
        }
    }
}

; Resolves the GtkTreeView pointer behind a TreeView control.  The port's
; script-visible .Hwnd is an opaque 32-bit handle, not a pointer, so the
; widget is located through GTK: the cheat window's unit tree is the
; GtkTreeView whose model has two columns (name + item id), while the
; ListBoxes use one-column models.  Results are cached per control handle.
PortTreeWidget(tv) {
    global PortTreeWidgets
    if !IsObject(tv)
        return 0
    hwnd := tv.Hwnd
    if PortTreeWidgets.Has(hwnd)
        return PortTreeWidgets[hwnd]
    widget := PortFindUnitsTree()
    PortTreeWidgets[hwnd] := widget
    return widget
}

; GtkWindow pointer of the top-level window with the given title, or 0.
PortFindWindow(title) {
    wins := PortDll("libgtk-3.so.0", "gtk_window_list_toplevels", "ptr")
    node := wins
    while node {
        win := NumGet(node, 0, "ptr")
        node := NumGet(node, A_PtrSize, "ptr")
        if !win
            continue
        titlePtr := PortDll("libgtk-3.so.0", "gtk_window_get_title", "ptr", win, "ptr")
        if titlePtr && StrGet(titlePtr, "UTF-8") = title
            return win
    }
    return 0
}

PortFindUnitsTree() {
    win := PortFindWindow("BAR Cheat Codes")
    if !win
        return 0
    return PortFindTreeByColumns(win, 2)
}

; Finds the GtkTreeView whose model has the given column count (the unit
; tree uses 2 columns; the ListBoxes use 1).  Iterative on purpose: the
; port's DllCall breaks when called from a recursive AHK function.
PortFindTreeByColumns(root, columns) {
    tvType := PortDll("libgtk-3.so.0", "gtk_tree_view_get_type", "ptr")
    containerType := PortDll("libgtk-3.so.0", "gtk_container_get_type", "ptr")
    queue := [root]
    while queue.Length {
        widget := queue.Pop()
        if PortDll("libgobject-2.0.so.0", "g_type_check_instance_is_a", "ptr", widget, "ptr", tvType, "int") {
            model := PortDll("libgtk-3.so.0", "gtk_tree_view_get_model", "ptr", widget, "ptr")
            if model && PortDll("libgtk-3.so.0", "gtk_tree_model_get_n_columns", "ptr", model, "int") = columns
                return widget
            continue
        }
        if !PortDll("libgobject-2.0.so.0", "g_type_check_instance_is_a", "ptr", widget, "ptr", containerType, "int")
            continue
        children := PortDll("libgtk-3.so.0", "gtk_container_get_children", "ptr", widget, "ptr")
        if !children
            continue
        node := children
        while node {
            child := NumGet(node, 0, "ptr")
            node := NumGet(node, A_PtrSize, "ptr")
            if child
                queue.Push(child)
        }
        PortDll("libglib-2.0.so.0", "g_list_free", "ptr", children)
    }
    return 0
}

; GTK tree path ("top:child") of a tree item, or "" when it cannot be built.
PortTreePath(tv, itemId) {
    if !IsObject(tv)
        return ""
    parent := tv.GetParent(itemId)
    if !parent {
        topIdx := PortTreeIndex(tv, 0, itemId)
        return topIdx = -1 ? "" : String(topIdx)
    }
    top := parent
    while tv.GetParent(top)
        top := tv.GetParent(top)
    topIdx := PortTreeIndex(tv, 0, top)
    childIdx := PortTreeIndex(tv, parent, itemId)
    if topIdx = -1 || childIdx = -1
        return ""
    return topIdx ":" childIdx
}

; 0-based index of targetId among the children of parentId, or -1.
PortTreeIndex(tv, parentId, targetId) {
    id := tv.GetChild(parentId)
    idx := 0
    while id {
        if id = targetId
            return idx
        id := tv.GetNext(id, "Next")
        idx += 1
    }
    return -1
}

; Expands one item (Modify "Expand" is a no-op on the port).
PortTreeExpandItem(tv, itemId) {
    widget := PortTreeWidget(tv)
    if !widget
        return
    pathStr := PortTreePath(tv, itemId)
    if pathStr = ""
        return
    try {
        path := PortDll("libgtk-3.so.0", "gtk_tree_path_new_from_string", "astr", pathStr, "ptr")
        if !path
            return
        PortDll("libgtk-3.so.0", "gtk_tree_view_expand_row", "ptr", widget, "ptr", path, "int", 0)
        PortDll("libgtk-3.so.0", "gtk_tree_path_free", "ptr", path)
    } catch {
    }
}

PortTreeExpandAll(tv) {
    widget := PortTreeWidget(tv)
    if !widget
        return
    try
        PortDll("libgtk-3.so.0", "gtk_tree_view_expand_all", "ptr", widget)
    catch {
    }
}

; Selects one item (Modify "Select" is a no-op on the port).
PortTreeSelectItem(tv, itemId) {
    widget := PortTreeWidget(tv)
    if !widget
        return
    pathStr := PortTreePath(tv, itemId)
    if pathStr = ""
        return
    try {
        path := PortDll("libgtk-3.so.0", "gtk_tree_path_new_from_string", "astr", pathStr, "ptr")
        if !path
            return
        sel := PortDll("libgtk-3.so.0", "gtk_tree_view_get_selection", "ptr", widget, "ptr")
        PortDll("libgtk-3.so.0", "gtk_tree_selection_select_path", "ptr", sel, "ptr", path)
        PortDll("libgtk-3.so.0", "gtk_tree_view_set_cursor", "ptr", widget, "ptr", path, "ptr", 0, "int", 0)
        PortDll("libgtk-3.so.0", "gtk_tree_view_scroll_to_cell", "ptr", widget, "ptr", path, "ptr", 0, "int", 0, "float", 0.5, "float", 0.0)
        PortDll("libgtk-3.so.0", "gtk_tree_path_free", "ptr", path)
    } catch {
    }
}

; The port creates the tree text renderer editable and leaves the (empty)
; column header visible, unlike its ListBox; turn both off.  GTK3 exposes
; "editable" only as a GObject property (no setter symbol), so set it through
; a GValue.
PortDisableTreeEdit(tv) {
    widget := PortTreeWidget(tv)
    if !widget
        return
    try {
        column := PortDll("libgtk-3.so.0", "gtk_tree_view_get_column", "ptr", widget, "int", 0, "ptr")
        if !column
            return
        cells := PortDll("libgtk-3.so.0", "gtk_cell_layout_get_cells", "ptr", column, "ptr")
        if !cells
            return
        renderer := PortDll("libglib-2.0.so.0", "g_list_nth_data", "ptr", cells, "UInt", 0, "ptr")
        try PortDll("libglib-2.0.so.0", "g_list_free", "ptr", cells)
        if !renderer
            return
        gval := Buffer(24, 0)
        PortDll("libgobject-2.0.so.0", "g_value_init", "ptr", gval.Ptr, "ptr", 20, "ptr")  ; G_TYPE_BOOLEAN = 20
        PortDll("libgobject-2.0.so.0", "g_value_set_boolean", "ptr", gval.Ptr, "int", 0)
        PortDll("libgobject-2.0.so.0", "g_object_set_property", "ptr", renderer, "astr", "editable", "ptr", gval.Ptr)
        PortDll("libgobject-2.0.so.0", "g_value_unset", "ptr", gval.Ptr)
        ; The port forgets this for TreeView (it sets it for ListBox), leaving
        ; an empty ~24px column header row above the first category.
        PortDll("libgtk-3.so.0", "gtk_tree_view_set_headers_visible", "ptr", widget, "int", 0)
    } catch {
    }
}

; ---- Linux uinput injection -----------------------------------------------
; The port only prefers its uinput lane when there is no X display, and XTEST
; text injection requires the libei "remote interaction" consent (whose
; session also captures the physical keyboard).  Instead the script owns a
; virtual keyboard through /dev/uinput: kernel-level injection needs no
; consent and delivers Enter like a real key.  Requires the one-time udev
; rule documented in README.md; without it the script falls back to SendText.

; Opens /dev/uinput and creates the virtual keyboard once per process.
PortUinputAvailable() {
    global UinputFd, UinputTried, UinputUsable
    if UinputTried
        return UinputUsable
    UinputTried := true
    try {
        fd := PortDll("libc.so.6", "open", "astr", "/dev/uinput", "int", 0x801, "int", 0, "int")
        if fd < 0
            return false
        ; EV_KEY plus every keycode (mirrors the port's device setup).
        if PortDll("libc.so.6", "ioctl", "int", fd, "UInt", 0x40045564, "int", 1, "int") != 0
            return false
        Loop 0x2FE {
            if PortDll("libc.so.6", "ioctl", "int", fd, "UInt", 0x40045565, "int", A_Index, "int") != 0
                return false
        }
        ; EV_REL + REL_X/REL_Y: the shortcut can also move the pointer back
        ; to where it was when the cheat window opened (see PortRestorePointer).
        if PortDll("libc.so.6", "ioctl", "int", fd, "UInt", 0x40045564, "int", 2, "int") != 0
            return false
        Loop 2 {
            if PortDll("libc.so.6", "ioctl", "int", fd, "UInt", 0x40045566, "int", A_Index - 1, "int") != 0
                return false
        }
        ; struct uinput_setup { input_id id; char name[80]; __u32 ff_effects_max; }
        setup := Buffer(92, 0)
        NumPut("ushort", 3, setup, 0)        ; BUS_USB
        NumPut("ushort", 0x2C2F, setup, 2)   ; vendor
        NumPut("ushort", 0x0002, setup, 4)   ; product
        NumPut("ushort", 1, setup, 6)        ; version
        StrPut("BAR Cheat virtual keyboard", setup.Ptr + 8, 80, "UTF-8")
        if PortDll("libc.so.6", "ioctl", "int", fd, "UInt", 0x405C5503, "ptr", setup.Ptr, "int") != 0
            return false
        if PortDll("libc.so.6", "ioctl", "int", fd, "UInt", 0x5501, "int") != 0
            return false
        UinputFd := fd
        UinputUsable := true
        Sleep(150)   ; let libinput/compositor register the device
        return true
    } catch {
        return false
    }
}

; Writes one input_event plus the SYN_REPORT frame terminator.
PortUinputEvent(type, code, value) {
    global UinputFd
    evt := Buffer(24, 0)
    NumPut("ushort", type, evt, 16)
    NumPut("ushort", code, evt, 18)
    NumPut("int", value, evt, 20)
    written := PortDll("libc.so.6", "write", "int", UinputFd, "ptr", evt.Ptr, "UPtr", 24, "ptr")
    if written != 24
        return false
    syn := Buffer(24, 0)   ; EV_SYN / SYN_REPORT / 0
    written := PortDll("libc.so.6", "write", "int", UinputFd, "ptr", syn.Ptr, "UPtr", 24, "ptr")
    return written = 24
}

; char -> {kc, shift} for the printable US-layout characters.
PortUinputCharMap() {
    static chars := 0
    if IsObject(chars)
        return chars
    chars := Map()
    lower := "abcdefghijklmnopqrstuvwxyz"
    lowerKc := [30,48,46,32,18,33,34,35,23,36,37,38,50,49,24,25,16,19,31,20,22,47,17,45,21,44]
    Loop Parse, lower
        chars[A_LoopField] := {kc: lowerKc[A_Index], shift: false}
    upper := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    Loop Parse, upper
        chars[A_LoopField] := {kc: lowerKc[A_Index], shift: true}
    digits := "1234567890"
    digitKc := [2,3,4,5,6,7,8,9,10,11]
    Loop Parse, digits
        chars[A_LoopField] := {kc: digitKc[A_Index], shift: false}
    shiftedDigits := "!@#$%^&*()"
    Loop Parse, shiftedDigits
        chars[A_LoopField] := {kc: digitKc[A_Index], shift: true}
    unshifted := Map("-", 12, "=", 13, "[", 26, "]", 27, "\", 43, ";", 39, "'", 40, "``", 41, ",", 51, ".", 52, "/", 53, " ", 57)
    for c, kc in unshifted
        chars[c] := {kc: kc, shift: false}
    shifted := Map("_", 12, "+", 13, "{", 26, "}", 27, "|", 43, ":", 39, "`"", 40, "~", 41, "<", 51, ">", 52, "?", 53)
    for c, kc in shifted
        chars[c] := {kc: kc, shift: true}
    return chars
}

; Types text through the virtual keyboard.  Returns false when the lane is
; unavailable or any character is unmapped (caller uses the XTEST fallback).
PortUinputTypeText(text) {
    if !PortUinputAvailable()
        return false
    chars := PortUinputCharMap()
    for ch in StrSplit(text)
        if !chars.Has(ch)
            return false
    for ch in StrSplit(text) {
        info := chars[ch]
        if info.shift
            PortUinputEvent(1, 42, 1)   ; KEY_LEFTSHIFT down
        ok := PortUinputEvent(1, info.kc, 1)
        if PortUinputEvent(1, info.kc, 0) = false
            ok := false
        if info.shift
            PortUinputEvent(1, 42, 0)
        if !ok
            return false
        Sleep(8)
    }
    return true
}

PortUinputEnter() {
    if !PortUinputAvailable()
        return false
    ok := PortUinputEvent(1, 28, 1)   ; KEY_ENTER
    Sleep(30)
    if PortUinputEvent(1, 28, 0) = false
        ok := false
    return ok
}

; Moves the pointer by a relative delta through the virtual pointer.
PortUinputMoveBy(dx, dy) {
    if !PortUinputAvailable()
        return false
    ok := PortUinputEvent(2, 0, dx)   ; EV_REL / REL_X
    if PortUinputEvent(2, 1, dy) = false   ; EV_REL / REL_Y
        ok := false
    return ok
}

; Puts the pointer back where it was when the cheat window opened.  /give
; spawns at the pointer, exactly like the Windows flow's MouseMove before the
; final Enter.  XWarpPointer is a core X11 request (not XTEST), so it needs
; no consent and works from a background client on XWayland.  Falls back to
; the virtual pointer's relative motion when no X display is available.
PortRestorePointer(targetX, targetY) {
    try {
        dpy := PortDll("libX11.so.6", "XOpenDisplay", "ptr", 0, "ptr")
        if dpy {
            root := PortDll("libX11.so.6", "XDefaultRootWindow", "ptr", dpy, "ptr")
            PortDll("libX11.so.6", "XWarpPointer", "ptr", dpy, "ptr", 0, "ptr", root
                , "int", 0, "int", 0, "UInt", 0, "UInt", 0, "int", targetX, "int", targetY, "int")
            PortDll("libX11.so.6", "XFlush", "ptr", dpy, "int")
            PortDll("libX11.so.6", "XCloseDisplay", "ptr", dpy, "int")
            return true
        }
    } catch {
    }
    if !PortUinputAvailable()
        return false
    try
        MouseGetPos(&cx, &cy)
    catch
        return false
    return PortUinputMoveBy(targetX - cx, targetY - cy)
}

ShowGui() {
    global gGui, AmountBox, SearchBox, TabCtrl, FavList, FavSearchBox, RecentList, RecentSearchBox, MetaList, AmountGroup, FavBtn, HKBox, gStatus
    global TreeView, ImageViewer, RecentImg, FavImg, ImgToggleBtn
    global IncBtn, DecBtn, Btn1, Btn2, Btn5, Btn10, PasteBtn, CloseBtn, RemoveFavBtn, RemoveRecentBtn
    global chkTopmost, chkRememberPos, chkDark
    global mouseX, mouseY, CheatCodesFile, RecentCheatsFile, TreeViewStateFile
    global cheatsData, unitsData, favData, recentData, favDisplay, favCheatData
    global PortTreeWidgets, PortUiLastTab, PortUiLastRecent, PortUiLastFav, PortUiLastMeta

    ; New controls get new handles: drop the cached GtkTreeView pointer and
    ; force the list watch to re-sync on the first tick.
    PortTreeWidgets := Map()
    PortUiLastTab := -1
    PortUiLastRecent := -1
    PortUiLastFav := -1
    PortUiLastMeta := -1

    ; Check if either file has been modified
    shouldReload := false
    if FileExist(CheatCodesFile) {
        currentModified := FileGetTime(CheatCodesFile)
        shouldReload := currentModified != LastModified
    }
    if FileExist(RecentCheatsFile) {
        currentModifiedRecent := FileGetTime(RecentCheatsFile)
        shouldReload := shouldReload || currentModifiedRecent != LastModifiedRecent
    }

    ; Capture current mouse position
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)

    ; If GUI exists and file hasn't changed, show and activate it
    try {
        if IsObject(gGui) && WinExist("ahk_id " gGui.Hwnd) && !shouldReload {
            ForceActivateWindow(gGui)
            return
        }
    }

    ; Save the old GUI's state before rebuilding it
    if IsObject(gGui) {
        try {
            SaveTreeViewState(TreeView, TreeViewStateFile, true)
            if IsObject(TabCtrl)
                SetSetting("LastTab", TabCtrl.Value)
        }
    }

    dark := Integer(GetSetting("DarkMode", 0))
    topmost := Integer(GetSetting("AlwaysOnTop", 1))

    ; Create new GUI
    gGui := Gui(topmost ? "+AlwaysOnTop +Owner" : "+Owner", "BAR Cheat")
    gGui.Title := "BAR Cheat Codes"
    gGui.SetFont("s10" (dark ? " cE0E0E0" : " c000000"))
    if dark
        gGui.BackColor := "202020"

; Creation-time options for dark mode (Theme/-Theme only works at creation,
    ; so dark styling is baked in here rather than applied later)
    btnOpt := dark ? "-Theme" : ""
    lstOpt := dark ? "Background2D2D2D" : ""
    txtOpt := dark ? "Background1A1A1A" : ""
    gbOpt := dark ? "-Theme" : ""

    ; Tab area holds only the lists; Amount/buttons are shared below it
    TabCtrl := gGui.Add("Tab3", "x8 y6 w408 h560", ["Units", "Recent", "Favorites", "Meta", "Settings"])
    TabCtrl.OnEvent("Change", TabChanged)

    ; ---- Units tab (UseTab makes coords relative to the tab page) ----
    TabCtrl.UseTab(1)
    gGui.Add("Text", "x16 y48 w60", "Search:")
    SearchBox := gGui.Add("Edit", "x78 y40 w322 h24 " lstOpt, "")
    SearchBox.OnEvent("Change", FilterTreeView)

    TreeView := gGui.Add("TreeView", "x16 y76 w384 h188")
    if IsWslPort
        PortDisableTreeEdit(TreeView)
    TreeView.OnEvent("DoubleClick", PasteSelectedCode)
    TreeView.OnEvent("ItemSelect", UpdateCheatAmount)

    ; Image viewer with fixed size and centered (256x256 native)
    ImageViewer := gGui.Add("Picture", "x80 y268 w256 h256 +Center")

    ; ---- Recent tab ----
    TabCtrl.UseTab(2)
    gGui.Add("Text", "x16 y48 w60", "Search:")
    RecentSearchBox := gGui.Add("Edit", "x78 y40 w322 h24 " lstOpt, "")
    RecentSearchBox.OnEvent("Change", FilterRecentList)
    RecentList := gGui.Add("ListBox", "x16 y76 w384 h188 " lstOpt)
    RecentList.OnEvent("DoubleClick", PasteSelectedCode)
    RecentList.OnEvent("Change", ListSelectionChanged)
    RecentImg := gGui.Add("Picture", "x80 y268 w256 h256 +Center")
    RemoveRecentBtn := gGui.Add("Button", "x16 y532 w384 " btnOpt, "Remove Selected from Recent")

    ; ---- Favorites tab ----
    TabCtrl.UseTab(3)
    gGui.Add("Text", "x16 y48 w60", "Search:")
    FavSearchBox := gGui.Add("Edit", "x78 y40 w322 h24 " lstOpt, "")
    FavSearchBox.OnEvent("Change", FilterFavList)
    FavList := gGui.Add("ListBox", "x16 y76 w384 h188 " lstOpt)
    FavList.OnEvent("DoubleClick", PasteSelectedCode)
    FavList.OnEvent("Change", ListSelectionChanged)
    FavImg := gGui.Add("Picture", "x80 y268 w256 h256 +Center")
    RemoveFavBtn := gGui.Add("Button", "x16 y532 w384 " btnOpt, "Remove Selected from Favorites")

    ; ---- Meta tab ----
    TabCtrl.UseTab(4)
    MetaList := gGui.Add("ListBox", "x16 y34 w384 h496 " lstOpt)
    MetaList.OnEvent("DoubleClick", PasteSelectedCode)
    MetaList.OnEvent("Change", ListSelectionChanged)

    ; ---- Settings tab ----
    TabCtrl.UseTab(5)
    gGui.Add("Text", "x16 y32 w384", "Hotkey to show the cheat window:")
    HKBox := gGui.Add("Hotkey", "x16 y52 w150")
    if CurrentHotkey != ""
        HKBox.Value := CurrentHotkey
    HKBox.OnEvent("Change", ApplyHotkeySetting)

    chkTopmost := gGui.Add("CheckBox", "x16 y84 w384", "Always on top")
    chkTopmost.Value := Integer(topmost)
    chkTopmost.OnEvent("Click", PortClick(ApplyTopmostSetting))

    chkRememberPos := gGui.Add("CheckBox", "x16 y108 w384", "Remember window position")
    chkRememberPos.Value := Integer(GetSetting("RememberPos", 1))
    chkRememberPos.OnEvent("Click", PortClick(ApplyRememberPosSetting))

    chkDark := gGui.Add("CheckBox", "x16 y132 w384", "Dark mode (reopens the window)")
    chkDark.Value := Integer(dark)
    chkDark.OnEvent("Click", PortClick(ApplyDarkModeSetting))

    gGui.Add("Text", "x16 y156 w384", "Settings are saved to bar_cheat.ini in the script folder.")

    ; Stop associating controls with the tab pages
    TabCtrl.UseTab()

    ; ---- Shared Amount area (used by Units, Recent, Favorites and Meta) ----
    ; The caption is a separate Text control so dark mode can color it
    ; (groupbox captions ignore font colors)
    AmountGroup := gGui.Add("GroupBox", "x16 y576 w384 h56 " gbOpt, "")
    gGui.Add("Text", "x24 y572 w60 " (dark ? "Background202020" : ""), "Amount")
    AmountBox := gGui.Add("Edit", "x26 y598 w50 " lstOpt, "")
    IncBtn := gGui.Add("Button", "x88 y598 w30 " btnOpt, "+")
    DecBtn := gGui.Add("Button", "x120 y598 w30 " btnOpt, "-")
    Btn1 := gGui.Add("Button", "x160 y598 w30 " btnOpt, "1")
    Btn2 := gGui.Add("Button", "x192 y598 w30 " btnOpt, "2")
    Btn5 := gGui.Add("Button", "x224 y598 w30 " btnOpt, "5")
    Btn10 := gGui.Add("Button", "x256 y598 w36 " btnOpt, "10")
    ImgToggleBtn := gGui.Add("Button", "x300 y598 w84 " btnOpt, "Hide Img")
    ImgToggleBtn.OnEvent("Click", PortClick(ToggleImagePreview))

    ; Paste is the default button, placed first for prominence.
    ; In dark mode it loses the default glow (Enter still works via hotkey).
    PasteBtn := gGui.Add("Button", "x16 y640 w186 " (dark ? "" : "+Default "), "Paste Code (Enter)")
    PasteBtn.SetFont("w600")
    FavBtn := gGui.Add("Button", "x210 y640 w96 " btnOpt, "★ Favorite")
    CloseBtn := gGui.Add("Button", "x314 y640 w86 " btnOpt, "Close (Esc)")

    ; Dark mode: classic (-Theme) buttons need dark text on the gray face
    if dark {
        for ctrl in [IncBtn, DecBtn, Btn1, Btn2, Btn5, Btn10, PasteBtn, FavBtn, CloseBtn,
                     RemoveFavBtn, RemoveRecentBtn, ImgToggleBtn]
            try ctrl.SetFont(ctrl = PasteBtn ? "w600 c000000" : "c000000")
    }

    ; Restore the last used tab
    lastTab := Integer(GetSetting("LastTab", 1))
    if lastTab >= 1 && lastTab <= 5
        TabCtrl.Value := Integer(lastTab)

    ; Load favorites first so trees/lists can mark favorites with a star
    favData := LoadFavorites()
    RebuildFavoriteNames()

    ; Split the parsed categories into per-tab datasets:
    ; "Fav *" categories -> favorites, "Cheat" -> meta list, rest -> units tree
    cheatsData := Map(), unitsData := Map(), favCheatData := []
    for category, cheatList in LoadCheatCodes() {
        if InStr(category, "Fav") = 1 {
            for cheat in cheatList
                favCheatData.Push({name: cheat.name, code: cheat.code})
        } else if InStr(category, "Cheat") {
            cheatsData[category] := cheatList
        } else {
            unitsData[category] := cheatList
        }
    }
    RebuildFavoriteNames()
    PopulateTreeView(TreeView, unitsData)
    RestoreTreeViewState(TreeView, TreeViewStateFile)

    ; Populate the lists
    recentData := LoadRecents()
    RefreshRecentList()
    RefreshFavList()
    RefreshMetaList()

; Enable/disable the shared Amount area for the restored tab
    UpdateAmountArea()

    ; Apply the persisted image preview state (collapsed/expanded)
    ApplyImageState()

    ; Apply dark styling to list-like controls
    if dark
        ApplyDarkControls()

    ; Event handlers
    FavBtn.OnEvent("Click", PortClick(ToggleFavorite))
    PasteBtn.OnEvent("Click", PortClick(PasteSelectedCode))
    CloseBtn.OnEvent("Click", PortClick(CloseGui))
    IncBtn.OnEvent("Click", PortClick(IncrementAmount))
    DecBtn.OnEvent("Click", PortClick(DecrementAmount))
    Btn1.OnEvent("Click", PortClick((*) => SetAmount(1)))
    Btn2.OnEvent("Click", PortClick((*) => SetAmount(2)))
    Btn5.OnEvent("Click", PortClick((*) => SetAmount(5)))
    Btn10.OnEvent("Click", PortClick((*) => SetAmount(10)))
    RemoveFavBtn.OnEvent("Click", PortClick(RemoveFavorite))
    RemoveRecentBtn.OnEvent("Click", PortClick(RemoveRecent))

    ; Status line shows the selected cheat code and hints (a text control
    ; instead of a real status bar so dark mode can style it)
    statusHints := "Select a cheat - Enter=Paste, Esc=Close"
    gStatus := gGui.Add("Text", "x8 y674 w408 h24 +Border +0x200 " txtOpt, statusHints)

    ; Handle GUI close event
    gGui.OnEvent("Close", CloseGui)

    ; The port has no global Escape grab (see the hotkey setup): close the
    ; window through its own Escape event instead.
    if IsWslPort
        gGui.OnEvent("Escape", CloseGui)

    ; Show the window, restoring the saved position if enabled
    showOpts := "w424 h704"
    if Integer(GetSetting("RememberPos", 1)) {
        px := IniRead(ConfigFile, "WindowPos", "X", "")
        py := IniRead(ConfigFile, "WindowPos", "Y", "")
        if px != "" && py != "" {
            px := Min(Max(Number(px), -200), Number(A_ScreenWidth) - 100)
            py := Min(Max(Number(py), 0), Number(A_ScreenHeight) - 100)
            showOpts .= " x" px " y" py
        }
    }
gGui.Show(showOpts)
    if dark {
        ; Dark title bar (Windows 10 2004+); no-op on the Linux port where the
        ; DllCall throws (caught) instead of silently succeeding.
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", gGui.Hwnd, "uint", 20, "int*", 1, "uint", 4)
    }
    ForceActivateWindow(gGui)

    ; Set a timer to delay the selection and event trigger
    SetTimer(DelayedSelect, -100)

    ; The port does not raise ListBox Change events; poll the lists instead
    if IsWslPort
        SetTimer(PortUiWatch, 150)
}

; Dark-mode extras that can only be applied at runtime (most styling is
; baked in at control creation in ShowGui).
; Palette: window #202020, lists/edits #2D2D2D, classic gray buttons with
; black text (-Theme), status line #1A1A1A, text #E0E0E0.
ApplyDarkControls() {
    global TreeView, TabCtrl, chkTopmost, chkRememberPos, chkDark, HKBox

    ; Checkboxes and hotkey box: dark glyph (Win10 1809+)
    for ctrl in [chkTopmost, chkRememberPos, chkDark, HKBox]
        try DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

    ; Tab header: dark mode theme (Win10 1809+)
    try DllCall("uxtheme\SetWindowTheme", "ptr", TabCtrl.Hwnd, "str", "DarkMode_Elements", "ptr", 0)

    ; TreeView: dark colors + dark scrollbars
    DllCall("uxtheme\SetWindowTheme", "ptr", TreeView.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)
    SendMessage(0x111E, 0, 0xE0E0E0, TreeView)  ; TVM_SETTEXTCOLOR
    SendMessage(0x111D, 0, 0x202020, TreeView)  ; TVM_SETBKCOLOR
    TreeView.Redraw()
}

; Collapses/expands the image preview on the Units, Recent and Favorites
; tabs; the lists grow/shrink to use the freed space. Persisted in the ini.
ApplyImageState() {
    global ImgToggleBtn, ImageViewer, RecentImg, FavImg, TreeView, RecentList, FavList
    show := GetSetting("ImagePreview", 1) = "1"
    if IsObject(ImgToggleBtn)
        ImgToggleBtn.Text := show ? "Hide Img" : "Show Img"
    if !IsObject(TreeView)
        return
    listH := show ? 188 : 454
    for ctrl in [TreeView, RecentList, FavList]
        try ctrl.Move(, , , listH)
    for ctrl in [ImageViewer, RecentImg, FavImg]
        ctrl.Visible := show ? true : false
}

ToggleImagePreview(*) {
    SetSetting("ImagePreview", GetSetting("ImagePreview", 1) = "1" ? 0 : 1)
    ApplyImageState()
}

; Loads the unit preview image for a cheat code into the given Picture
; control. The images are 256x256 and the preview boxes are 256x256, so
; they display 1:1 without scaling.
LoadUnitImage(pic, cheatCode) {
    if !IsObject(pic)
        return
    ; Clear the current image on Windows.  On the Linux port setting Value to
    ; "" breaks the Picture control (later sets throw "Invalid value"), so the
    ; previous image is simply left in place there.
    if !IsWslPort
        pic.Value := ""
    if !RegExMatch(cheatCode, "/give \d+ (\w+) \d+", &unitName)
        return
    imagePath := A_ScriptDir "/unit_images/" unitName[1] ".png"
    if !FileExist(imagePath)
        return
    try
        pic.Value := imagePath
    catch
        return
}

; Settings tab handlers
ApplyHotkeySetting(*) {
    global HKBox, CurrentHotkey
    hk := HKBox.Value
    if hk = "" || hk = CurrentHotkey
        return
    if RegisterHotkey(hk) {
        SetSetting("Hotkey", hk)
    } else {
        HKBox.Value := CurrentHotkey
    }
}

ApplyTopmostSetting(ctrl, *) {
    global gGui
    SetSetting("AlwaysOnTop", ctrl.Value ? 1 : 0)
    if IsObject(gGui)
        gGui.Opt(ctrl.Value ? "+AlwaysOnTop" : "-AlwaysOnTop")
}

ApplyRememberPosSetting(ctrl, *) {
    SetSetting("RememberPos", ctrl.Value ? 1 : 0)
}

ApplyDarkModeSetting(ctrl, *) {
    SetSetting("DarkMode", ctrl.Value ? 1 : 0)
    ; Rebuild the GUI so every control picks up the new colors
    SetTimer(RebuildGui, -10)
}

RebuildGui() {
    CloseGui()
    ShowGui()
}

DelayedSelect() {
    global TreeView

    ; Only pick a default selection if the state restore didn't provide one
    ; (guarded on the port: scripted selection tracking is unreliable)
    try {
        if TreeView.GetSelection()
            return
        firstCategory := TreeView.GetChild(0)
        if firstCategory {
            firstChild := TreeView.GetChild(firstCategory)
            if firstChild {
                if IsWslPort {
                    PortTreeExpandItem(TreeView, firstCategory)
                    PortTreeSelectItem(TreeView, firstChild)
                } else {
                    TreeView.Modify(firstCategory, "Expand")
                    TreeView.Modify(firstChild, "Select")
                }
            }
        }
    }
}

; Enables/disables the shared Amount area: dimmed on the Meta and Settings
; tabs (only Close works there).
TabChanged(*) {
    UpdateAmountArea()
    if IsObject(gStatus)
        UpdateStatusBar(GetDisplayedCheatCode())
}

UpdateAmountArea() {
    global TabCtrl, AmountBox, IncBtn, DecBtn, Btn1, Btn2, Btn5, Btn10, PasteBtn, FavBtn
    tab := IsObject(TabCtrl) ? TabCtrl.Value : 1
    dim := tab >= 4
    for ctrl in [AmountBox, IncBtn, DecBtn, Btn1, Btn2, Btn5, Btn10, FavBtn]
        ctrl.Enabled := !dim
    ; Meta has no amount, but its commands must still be pasteable; only the
    ; Settings tab has nothing to paste.
    if IsObject(PasteBtn)
        PasteBtn.Enabled := tab != 5
}

PopulateTreeView(TreeView, cheats, expand := false) {
    TreeView.Delete()
    itemMap := Map()  ; Store mapping of items to their command strings

    for category, cheatList in cheats {
        ; Add category (optionally expanded, e.g. for filtered results)
        parentId := TreeView.Add(category, 0, expand ? "Expand" : "")

        ; Verify that parentId is an integer
        if !IsInteger(parentId) {
            MsgBox "parentId is not an integer: " parentId
            Return
        }

        ; Add cheats under category, marking favorites with a star
        for cheat in cheatList {
            childId := TreeView.Add(FavMark(cheat.name), parentId, 0)
            itemMap[childId] := cheat.code
        }
    }

    ; Store the item map for later use
    TreeView.itemMap := itemMap
}

; Returns true if every space-separated token in searchText appears in name
MatchSearch(name, searchText) {
    for token in StrSplit(Trim(searchText), " ") {
        if token != "" && !InStr(name, token)
            return false
    }
    return true
}

FilterTreeView(*) {
    global SearchBox, TreeView, unitsData, TreeViewStateFile, FavBtn

    searchText := SearchBox.Value
    if Trim(searchText) = "" {
        ; No search text: show everything and restore saved expand state
        PopulateTreeView(TreeView, unitsData)
        RestoreTreeViewState(TreeView, TreeViewStateFile)
    } else {
        ; Build a filtered map of categories to matching units
        filtered := Map()
        for category, cheatList in unitsData {
            matched := []
            for cheat in cheatList {
                if MatchSearch(cheat.name, searchText)
                    matched.Push(cheat)
            }
            if matched.Length
                filtered[category] := matched
        }
        PopulateTreeView(TreeView, filtered, true)
        ; The port ignores the "Expand" item option
        if IsWslPort
            PortTreeExpandAll(TreeView)

        ; Select the first match so Enter pastes it right away
        firstCategory := TreeView.GetChild(0)
        if firstCategory {
            firstMatch := TreeView.GetChild(firstCategory)
            if firstMatch {
                if IsWslPort
                    PortTreeSelectItem(TreeView, firstMatch)
                else
                    TreeView.Modify(firstMatch, "Select")
                UpdateCheatAmount(firstMatch)
                return
            }
        }
    }
    if IsObject(FavBtn)
        FavBtn.Text := "★ Favorite"
}

SaveTreeViewState(tv, filePath, skipIfFiltered := false) {
    global SearchBox
    ; Don't overwrite the saved state while the tree is filtered by search
    if skipIfFiltered && IsObject(SearchBox) && Trim(SearchBox.Value) != ""
        return

    ; Expanded categories
    state := ""
    itemId := 0
    Loop {
        itemId := tv.GetNext(itemId, "Full")
        if !itemId
            break
        if tv.Get(itemId, "Expand")
            state .= tv.GetText(itemId) "`n"
    }

    ; Last used (selected) item
    sel := tv.GetSelection()
    if sel && tv.GetParent(sel)
        state .= "Selected:" tv.GetText(sel) "`n"

    ; Scroll position (first visible item)
    topItem := SendMessage(0x110A, 0, 0, tv)  ; TVM_GETFIRSTVISIBLE
    if topItem
        state .= "Top:" tv.GetText(topItem) "`n"

    file := FileOpen(filePath, "w")
    if file {
        file.Write(state)
        file.Close()
    } else {
        MsgBox "Failed to open file: " filePath
    }
}

RestoreTreeViewState(tv, filePath) {
    if !FileExist(filePath)
        return

    state := FileRead(filePath, "UTF-8")
    expandedItems := []
    selName := ""
    topName := ""
    Loop Parse, state, "`n", "`r" {
        line := A_LoopField
        if SubStr(line, 1, 9) = "Selected:"
            selName := SubStr(line, 10)
        else if SubStr(line, 1, 4) = "Top:"
            topName := SubStr(line, 5)
        else if Trim(line) != ""
            expandedItems.Push(line)
    }

    itemId := 0
    selId := 0
    topId := 0
    Loop {
        itemId := tv.GetNext(itemId, "Full")
        if !itemId
            break
        itemText := tv.GetText(itemId)
        for expandedItem in expandedItems {
            if itemText = expandedItem {
                if IsWslPort
                    PortTreeExpandItem(tv, itemId)
                else
                    tv.Modify(itemId, "Expand")
                break
            }
        }
        if selName != "" && itemText = selName && tv.GetParent(itemId)
            selId := itemId
        if topName != "" && itemText = topName
            topId := itemId
    }

    ; Restore selection (fires ItemSelect -> status bar/amount update) and scroll
    if selId {
        if IsWslPort
            PortTreeSelectItem(tv, selId)
        else
            tv.Modify(selId, "Select")
    }
    if topId
        try SendMessage(0x1114, 0, topId, tv)  ; TVM_ENSUREVISIBLE (guarded: SendMessage is flaky on the port)
}

SaveWindowPos() {
    global gGui, ConfigFile
    if !IsObject(gGui) || !GetSetting("RememberPos", 1)
        return
    try {
        if IsWslPort {
            ; WinGetPos("ahk_id ...") is unreliable on the port (opaque
            ; handles); read the real position from GTK.  Only while the
            ; window is visible: GTK reports a stale position once it is
            ; hidden (do a visible save in DoPaste before hiding).
            win := PortFindWindow("BAR Cheat Codes")
            if !win
                return
            gdkWin := PortDll("libgtk-3.so.0", "gtk_widget_get_window", "ptr", win, "ptr")
            if !gdkWin || !PortDll("libgtk-3.so.0", "gdk_window_is_visible", "ptr", gdkWin, "int")
                return
            pos := Buffer(8, 0)
            PortDll("libgtk-3.so.0", "gtk_window_get_position", "ptr", win, "ptr", pos.Ptr, "ptr", pos.Ptr + 4)
            wx := NumGet(pos, 0, "int")
            wy := NumGet(pos, 4, "int")
        } else {
            WinGetPos(&wx, &wy, , , "ahk_id " gGui.Hwnd)
        }
        IniWrite(wx, ConfigFile, "WindowPos", "X")
        IniWrite(wy, ConfigFile, "WindowPos", "Y")
    }
}

ForceActivateWindow(gui) {
    ; Show the window if it's hidden
    gui.Show()

    ; Force the window to be active (wrapped: throws on Linux when unmatchable)
    try
        WinActivate("ahk_id " gui.Hwnd)
    catch {
        try
            WinActivate("BAR Cheat")
        catch {
        }
    }

    ; Additional forced focus after a small delay
    SetTimer(FocusWindow.Bind(gui.Hwnd), -50)
}

FocusWindow(hwnd) {
    ; The window may have been closed before this timer fired
    try {
        if WinExist("ahk_id " hwnd)
            WinActivate("ahk_id " hwnd)
        else
            WinActivate("BAR Cheat")
    } catch {
    }
}

; Returns the cheat code of the selected unit in the units tree,
; or "" if nothing valid is selected.
GetSelectedCheatCode() {
    global TreeView
    selectedItemId := TreeView.GetSelection()
    if !selectedItemId || !TreeView.GetParent(selectedItemId)
        return ""
    return TreeView.itemMap[selectedItemId]
}

; Extracts the default amount from a /give cheat code, or "" if none.
ExtractCheatAmount(cheatCode) {
    if !InStr(cheatCode, "/give") || !RegExMatch(cheatCode, " (\d+) ")
        return ""
    return RegExReplace(cheatCode, ".*? (\d+) .*", "$1")
}

; Substitutes a new amount into a /give cheat code.
ReplaceCheatAmount(cheatCode, amount) {
    if amount = ""
        return cheatCode
    return RegExReplace(cheatCode, " (\d+) ", " " amount " ")
}

ClearSelectionUI() {
    global AmountBox, ImageViewer, RecentImg, FavImg
    AmountBox.Value := ""
    ; Pictures cannot be cleared on the Linux port - Value := "" breaks the
    ; control (later sets throw "Invalid value"). Leave the last image shown.
    if !IsWslPort
        for ctrl in [ImageViewer, RecentImg, FavImg]
            if IsObject(ctrl)
                ctrl.Value := ""
    UpdateStatusBar("")
}

UpdateStatusBar(cheatCode) {
    global gStatus
    if !IsObject(gStatus)
        return
    if cheatCode != ""
        gStatus.Text := cheatCode "    [Enter=Paste  Esc=Close]"
    else
        gStatus.Text := "Select a cheat - Enter=Paste, Esc=Close"
}

UpdateCheatAmount(*) {
    global AmountBox, ImageViewer, FavBtn

    cheatCode := GetSelectedCheatCode()
    if !cheatCode {
        ClearSelectionUI()
        return
    }

; The Units tab remembers the last amount value used
    lastAmount := GetSetting("LastUnitsAmount", "")
    AmountBox.Value := lastAmount != "" ? lastAmount : ExtractCheatAmount(cheatCode)

    ; Load the unit image if it exists
    LoadUnitImage(ImageViewer, cheatCode)

    if IsObject(FavBtn)
        FavBtn.Text := IsFavorite(BaseName(cheatNameFromItem())) ? "★ Unfavorite" : "★ Favorite"

    UpdateStatusBar(GetDisplayedCheatCode())
}

; Helper: name of the currently selected unit (without favorite marker).
cheatNameFromItem() {
    global TreeView
    ; On the Linux port, scripted selections (Modify ... "Select") may not be
    ; tracked, leaving GetSelection() == 0; GetText(0) would hang the port.
    sel := TreeView.GetSelection()
    if !sel
        return ""
    return BaseName(TreeView.GetText(sel))
}

; Applies the Amount box value to a /give cheat code (if applicable).
ApplyAmount(cheatCode) {
    global AmountBox
    if InStr(cheatCode, "/give") && RegExMatch(cheatCode, " (\d+) ")
        return ReplaceCheatAmount(cheatCode, AmountBox.Value)
    return cheatCode
}

; Returns the cheat code of the selected item on the Recent/Favorites/Meta tabs.
GetSelectedListCode() {
    global TabCtrl, RecentList, recentDisplay, FavList, favDisplay, MetaList, metaListData
    if !IsObject(TabCtrl)
        return ""
    if TabCtrl.Value = 2 {
        idx := RecentList.Value
        return (idx && idx <= recentDisplay.Length) ? recentDisplay[idx].code : ""
    }
    if TabCtrl.Value = 3 {
        idx := FavList.Value
        return (idx && idx <= favDisplay.Length) ? favDisplay[idx].code : ""
    }
    if TabCtrl.Value = 4 {
        idx := MetaList.Value
        return (idx && idx <= metaListData.Length) ? metaListData[idx].code : ""
    }
    return ""
}

; Returns true if the active tab has a valid selection.
HasSelection() {
    global TabCtrl, RecentList, recentDisplay, FavList, favDisplay, MetaList, metaListData
    if !IsObject(TabCtrl)
        return false
    if TabCtrl.Value = 2
        return RecentList.Value && RecentList.Value <= recentDisplay.Length
    if TabCtrl.Value = 3
        return FavList.Value && FavList.Value <= favDisplay.Length
    if TabCtrl.Value = 4
        return MetaList.Value && MetaList.Value <= metaListData.Length
    return GetSelectedCheatCode() != ""
}

; Returns the code of the current selection (tree or list) with the
; Amount box value applied.
GetDisplayedCheatCode() {
    global TabCtrl
    if IsObject(TabCtrl) && (TabCtrl.Value >= 2 && TabCtrl.Value <= 4)
        cheatCode := GetSelectedListCode()
    else
        cheatCode := GetSelectedCheatCode()
    if !cheatCode
        return ""
    return ApplyAmount(cheatCode)
}

; Selection change on the Recent/Favorites/Meta lists -> fill the amount
; from the selected code, update the image preview and the status bar
ListSelectionChanged(ctrl, *) {
    global AmountBox, RecentList, recentDisplay, FavList, favDisplay, MetaList, metaListData
    global RecentImg, FavImg, FavBtn, TabCtrl
    cheatCode := ""
    itemName := ""
    idx := ctrl.Value
    if IsObject(RecentList) && ctrl.Hwnd = RecentList.Hwnd {
        cheatCode := (idx && idx <= recentDisplay.Length) ? recentDisplay[idx].code : ""
        if idx && idx <= recentDisplay.Length
            itemName := BaseName(recentDisplay[idx].name)
        LoadUnitImage(RecentImg, cheatCode)
    } else if IsObject(FavList) && ctrl.Hwnd = FavList.Hwnd {
        cheatCode := (idx && idx <= favDisplay.Length) ? favDisplay[idx].code : ""
        if idx && idx <= favDisplay.Length
            itemName := BaseName(favDisplay[idx].name)
        LoadUnitImage(FavImg, cheatCode)
    } else if IsObject(MetaList) && ctrl.Hwnd = MetaList.Hwnd {
        cheatCode := (idx && idx <= metaListData.Length) ? metaListData[idx].code : ""
        if idx && idx <= metaListData.Length
            itemName := BaseName(metaListData[idx].name)
    }
    if cheatCode != ""
        AmountBox.Value := ExtractCheatAmount(cheatCode)
    ; Keep the Favorite button label in sync with the selection
    if IsObject(FavBtn) && IsObject(TabCtrl) && TabCtrl.Value >= 2 && itemName != ""
        FavBtn.Text := IsFavorite(itemName) ? "★ Unfavorite" : "★ Favorite"
    UpdateStatusBar(GetDisplayedCheatCode())
}

AdjustAmount(delta, min := 0) {
    global AmountBox

    if !HasSelection()
        return

    amount := AmountBox.Value
    if amount != "" {
        amount += delta
        if amount < min
            amount := min
    }
    AmountBox.Value := amount

    ; Update the cheat code display with the new amount
    UpdateStatusBar(GetDisplayedCheatCode())
}

IncrementAmount(*) {
    AdjustAmount(1)
}

DecrementAmount(*) {
    AdjustAmount(-1, 1)
}

SetAmount(amount) {
    global AmountBox

    if !HasSelection()
        return

    AmountBox.Value := amount

    ; Update the cheat code display with the new amount
    UpdateStatusBar(GetDisplayedCheatCode())
}

; ---- Favorites ----

; Rebuilds the set of favorite names (starred + "Fav *" categories).
RebuildFavoriteNames() {
    global favData, favCheatData, favNameSet
    favNameSet := Map()
    for src in [favData, favCheatData] {
        for fav in src
            favNameSet[fav.name] := true
    }
}

; Strips the favorite marker from a display name.
BaseName(name) {
    return SubStr(name, 1, 2) = "★ " ? SubStr(name, 3) : name
}

; Returns true if the given (base) name is a favorite.
IsFavorite(name) {
    global favNameSet
    return IsObject(favNameSet) && favNameSet.Has(name)
}

; Returns the display name for a list/tree entry, starred if it's a favorite.
FavMark(name) {
    return IsFavorite(name) ? "★ " name : name
}

; Builds the combined favorites list: starred favorites plus all entries
; from "Fav *" categories in bar_cheats.txt, deduplicated by name.
GetFavoriteDisplayList() {
    global favData, favCheatData
    list := []
    seen := Map()
    for src in [favData, favCheatData] {
        for fav in src {
            if !seen.Has(fav.name) {
                seen[fav.name] := true
                list.Push({name: fav.name, code: fav.code})
            }
        }
    }
    return list
}

RefreshFavList() {
    global FavList, favDisplay
    if !IsObject(FavList)
        return
    favDisplay := GetFavoriteDisplayList()
    UpdateFavList(favDisplay)
}

FilterFavList(*) {
    global FavSearchBox
    if Trim(FavSearchBox.Value) = "" {
        RefreshFavList()
        return
    }
    filtered := []
    for fav in GetFavoriteDisplayList() {
        if MatchSearch(fav.name, FavSearchBox.Value)
            filtered.Push(fav)
    }
    UpdateFavList(filtered)
}

UpdateFavList(list) {
    global FavList, favDisplay
    if !IsObject(FavList)
        return
    favDisplay := list
    items := []
    for fav in list
        items.Push(fav.name)
    FavList.Delete()
    if items.Length
        FavList.Add(items)
    if items.Length
        FavList.Choose(1)
}

ToggleFavorite(*) {
    global FavBtn, TabCtrl, TreeView, RecentList, recentDisplay

    if !IsObject(TabCtrl)
        return

    ; Recent tab: toggle the star on the selected recent entry
    if TabCtrl.Value = 2 {
        idx := RecentList.Value
        if !idx || idx > recentDisplay.Length
            return
        name := BaseName(recentDisplay[idx].name)
        starred := ToggleByName(name, recentDisplay[idx].code)
        UpdateTreeStar(name, starred)   ; keep the units tree marker in sync
        ; Rebuild the list without flicker, keeping selection and scroll
        apply() {
            RefreshRecentList()
            RecentList.Choose(idx)
        }
        WithListRedrawSuppressed(RecentList, apply)
        RefreshFavList()        ; favorites tab now shows it at the top
        FavBtn.Text := starred ? "★ Unfavorite" : "★ Favorite"
        return
    }

    ; Favorites tab: the button removes the selected favorite
    if TabCtrl.Value = 3 {
        RemoveFavorite()
        return
    }

    ; Units tab: toggle the star on the selected tree item
    if TabCtrl.Value != 1
        return
    sel := TreeView.GetSelection()
    if !sel || !TreeView.GetParent(sel)
        return
    name := BaseName(TreeView.GetText(sel))
    starred := ToggleByName(name, ApplyAmount(GetSelectedCheatCode()))
    TreeView.Modify(sel, "", starred ? "★ " name : name)
    FavBtn.Text := starred ? "★ Unfavorite" : "★ Favorite"
    RefreshFavList()
}

; Adds/removes a favorite by name; returns the new starred state.
ToggleByName(name, code) {
    global favData
    for i, fav in favData {
        if fav.name = name {
            favData.RemoveAt(i)
            SaveFavorites(favData)
            RebuildFavoriteNames()
            return false
        }
    }
    favData.InsertAt(1, {name: name, code: ApplyAmount(code)})
    SaveFavorites(favData)
    RebuildFavoriteNames()
    return true
}

; Runs fn with the listbox's redrawing suspended, then restores the scroll
; position - rebuilds happen without flicker or scroll jumps.
WithListRedrawSuppressed(ctrl, fn) {
    ; win32 redraw suspension gives flicker-free rebuilds on Windows.  On the
    ; Linux port the messages are inert no-ops and the InvalidateRect DllCall
    ; throws (caught), so it degrades to a plain fn.Call() there.
    top := SendMessage(0x018E, 0, 0, ctrl.Hwnd)   ; LB_GETTOPINDEX
    SendMessage(0x000B, false, 0, ctrl.Hwnd)      ; WM_SETREDRAW off
    fn.Call()
    SendMessage(0x0197, top, 0, ctrl.Hwnd)        ; LB_SETTOPINDEX
    SendMessage(0x000B, true, 0, ctrl.Hwnd)       ; WM_SETREDRAW on
    try
        DllCall("user32\InvalidateRect", "ptr", ctrl.Hwnd, "ptr", 0, "int", 1)
}

; Updates the star marker on the matching units-tree item (if visible).
UpdateTreeStar(name, starred) {
    global TreeView
    itemId := 0
    Loop {
        itemId := TreeView.GetNext(itemId, "Full")
        if !itemId
            break
        if !TreeView.GetParent(itemId)
            continue
        if BaseName(TreeView.GetText(itemId)) = name {
            TreeView.Modify(itemId, "", starred ? "★ " name : name)
            break
        }
    }
}

RemoveFavorite(*) {
    global FavList, favData, favDisplay, FavBtn
    idx := FavList.Value
    if !idx || idx > favDisplay.Length
        return
    name := BaseName(favDisplay[idx].name)
    found := false
    for i, fav in favData {
        if fav.name = name {
            favData.RemoveAt(i)
            SaveFavorites(favData)
            RebuildFavoriteNames()
            found := true
            break
        }
    }
    if !found {
        TrayTip("This favorite comes from a Fav category in bar_cheats.txt - remove it there.", "BAR Cheat")
        return
    }
    ; The Linux port cannot delete one ListBox row in place; rebuild instead.
    favDisplay.RemoveAt(idx)
    UpdateTreeStar(name, IsFavorite(name))
    UpdateFavList(favDisplay)
    newIdx := Min(idx, favDisplay.Length)
    if newIdx
        FavList.Choose(newIdx)
    FavBtn.Text := "★ Favorite"
    UpdateStatusBar(GetDisplayedCheatCode())
}

; Removes one ListBox row in place, keeping the scroll position intact.
DeleteListItemInPlace(ctrl, idx) {
    top := SendMessage(0x018E, 0, 0, ctrl.Hwnd)      ; LB_GETTOPINDEX
    SendMessage(0x000B, false, 0, ctrl.Hwnd)         ; WM_SETREDRAW off
    SendMessage(0x0183, idx - 1, 0, ctrl.Hwnd)       ; LB_DELETESTRING
    SendMessage(0x0197, top, 0, ctrl.Hwnd)           ; LB_SETTOPINDEX
    SendMessage(0x000B, true, 0, ctrl.Hwnd)          ; WM_SETREDRAW on
    try
        DllCall("user32\InvalidateRect", "ptr", ctrl.Hwnd, "ptr", 0, "int", 1)
}

; ---- Recents ----

RefreshRecentList() {
    global RecentSearchBox, recentData
    if !IsObject(RecentList)
        return
    if IsObject(RecentSearchBox) && Trim(RecentSearchBox.Value) != "" {
        filtered := []
        for r in recentData {
            if MatchSearch(r.name, RecentSearchBox.Value)
                filtered.Push(r)
        }
        UpdateRecentList(filtered)
        return
    }
    UpdateRecentList(recentData)
}

FilterRecentList(*) {
    RefreshRecentList()
}

UpdateRecentList(list) {
    global RecentList, recentDisplay
    if !IsObject(RecentList)
        return
    recentDisplay := list
    items := []
    for r in list
        items.Push(FavMark(r.name))
    RecentList.Delete()
    if items.Length
        RecentList.Add(items)
    if items.Length
        RecentList.Choose(1)
}

RemoveRecent(*) {
    global RecentList, recentData, recentDisplay
    idx := RecentList.Value
    if !idx || idx > recentDisplay.Length
        return
    name := BaseName(recentDisplay[idx].name)
    for i, r in recentData {
        if r.name = name {
            recentData.RemoveAt(i)
            break
        }
    }
    SaveRecents(recentData)
    ; The Linux port cannot delete one ListBox row in place; rebuild instead.
    recentDisplay.RemoveAt(idx)
    UpdateRecentList(recentDisplay)
    newIdx := Min(idx, recentDisplay.Length)
    if newIdx
        RecentList.Choose(newIdx)
    UpdateStatusBar(GetDisplayedCheatCode())
}

; ---- Meta ----

; Flat list of the "Cheat" category commands.
RefreshMetaList() {
    global MetaList, metaListData, cheatsData
    if !IsObject(MetaList)
        return
    metaListData := []
    for category, cheatList in cheatsData {
        for cheat in cheatList
            metaListData.Push({name: cheat.name, code: cheat.code})
    }
    items := []
    for m in metaListData
        items.Push(FavMark(m.name))
    MetaList.Delete()
    if items.Length
        MetaList.Add(items)
    if items.Length
        MetaList.Choose(1)
}

PasteRecent(*) {
    global RecentList, recentDisplay
    idx := RecentList.Value
    if !idx || idx > recentDisplay.Length
        return
    r := recentDisplay[idx]
    DoPaste(r.name, ApplyAmount(r.code))
}

; ---- Pasting ----

; Shared paste routine: activates the game window and types the code.
DoPaste(cheatName, cheatCode) {
    global gGui, mouseX, mouseY

    ; Verify the game is running; only paste into Beyond All Reason
    game := FindGameWindow()
    if !game {
        dbg := "[" A_Hour ":" A_Min ":" A_Sec "] FindGameWindow failed`n"
        for crit in GameWinCriteria {
            try
                dbg .= "  crit='" crit "' hwnd=" (WinExist(crit) ? WinExist(crit) : 0) "`n"
            catch as e
                dbg .= "  crit='" crit "' THROW: " e.Message "`n"
        }
        try {
            dbg .= "  WinGetList count=" WinGetList().Length "`n"
            for w in WinGetList()
                dbg .= "    win=" (WinGetTitle(w) ? WinGetTitle(w) : "<none>") "`n"
        } catch as e {
            dbg .= "  WinGetList THROW: " e.Message "`n"
        }
        FileAppend dbg, A_ScriptDir "/paste_dbg.log"
        TrayTip("Beyond All Reason window not found - cheat not pasted.", "BAR Cheat")
        CloseGui()
        return
    }

    ; Add to recent cheats
    AddToRecent(cheatName, cheatCode)

    ; Backup: put the cheat code on the clipboard so it can be pasted manually
    try
        A_Clipboard := cheatCode
    catch {
    }

    ; Remember the window position while it is still visible: GTK reports a
    ; stale position once the window is hidden (see SaveWindowPos).
    SaveWindowPos()

    ; Hide GUI
    gGui.Hide()

    ; Wait a moment before trying to activate game window
    Sleep(200)

    ; Activate the game window by window title (hwnd activation is unreliable on the Linux port)
    try
        WinActivate(game)
    catch {
    }

    ; Additional delay to ensure window activation
    Sleep(300)

    ; Send the cheat code.
    ; On the Linux port, prefer the script-owned uinput keyboard/pointer:
    ; kernel-level injection needs no libei "remote interaction" consent and
    ; delivers Enter, so the full auto-paste (Enter/text/Enter) works.  The
    ; pointer is put back where it was when the cheat window opened because
    ; /give spawns at the pointer (same as the Windows MouseMove below).
    ; If /dev/uinput is not writable, fall back to XTEST text (console opened
    ; manually, user presses Enter to submit).
    ; Windows keeps the full auto-paste (Enter/text/Enter) flow.
    if IsWslPort {
        if PortUinputAvailable() {
            PortUinputEnter()        ; open/focus the game console
            Sleep(80)
            PortUinputTypeText(cheatCode)
            Sleep(80)
            PortRestorePointer(mouseX, mouseY)
            Sleep(50)
            PortUinputEnter()        ; submit
        } else {
            SendText(cheatCode)
            Sleep(300)
        }
    } else {
        SendInput(EnterKey)
        Sleep(50)
        SendText(cheatCode)
        Sleep(50)
        Sleep(300)
        MouseMove(mouseX, mouseY)
        Sleep(50)
        SendInput(EnterKey)
    }
    CloseGui()
}

PasteSelectedCode(*) {
    global TabCtrl, TreeView, TreeViewStateFile, LastPasteFire

    ; The port dispatches a list/tree double-click twice (widget button event
    ; plus GTK row-activated); swallow the duplicate.  Windows fires once, so
    ; this never triggers there.
    if IsWslPort {
        if A_TickCount - LastPasteFire < 350
            return
        LastPasteFire := A_TickCount
    }

    ; Save the tree state before pasting
    SaveTreeViewState(TreeView, TreeViewStateFile, true)

    ; List tabs paste their selected item
    if IsObject(TabCtrl) {
        if TabCtrl.Value = 2 {
            PasteRecent()
            return
        }
        if TabCtrl.Value = 3 {
            PasteFavorite()
            return
        }
        if TabCtrl.Value = 4 {
            PasteMeta()
            return
        }
    }

    ; Units tab pastes from the tree
    selectedItemId := TreeView.GetSelection()
    if !selectedItemId || !TreeView.GetParent(selectedItemId)
        return
    itemText := TreeView.GetText(selectedItemId)

    DoPaste(itemText, GetDisplayedCheatCode())
}

PasteMeta(*) {
    global MetaList, metaListData
    idx := MetaList.Value
    if !idx || idx > metaListData.Length
        return
    m := metaListData[idx]
    DoPaste(m.name, ApplyAmount(m.code))
}

PasteFavorite(*) {
    global FavList, favDisplay
    idx := FavList.Value
    if !idx || idx > favDisplay.Length
        return
    fav := favDisplay[idx]
    DoPaste(fav.name, ApplyAmount(fav.code))
}

CloseGui(*) {
    global gGui, TreeView, TreeViewStateFile, TabCtrl, AmountBox

    if IsWslPort
        SetTimer(PortUiWatch, 0)
    if IsObject(gGui) {
        if IsObject(TabCtrl) {
            SetSetting("LastTab", TabCtrl.Value)
            ; Remember the amount last used on the Units tab
            if TabCtrl.Value = 1 && AmountBox.Value != ""
                SetSetting("LastUnitsAmount", AmountBox.Value)
        }
        try SaveTreeViewState(TreeView, TreeViewStateFile, true)
        SaveWindowPos()
        gGui.Destroy()
        gGui := ""
    }
}
