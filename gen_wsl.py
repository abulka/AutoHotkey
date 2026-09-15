#!/usr/bin/env python3
import os

HERE = os.path.dirname(os.path.realpath(__file__))
SRC = os.path.join(HERE, "bar_cheat.ahk")
OUT = os.path.join(HERE, "bar_cheat_wsl.ahk")

WRAPPER = """; === WSL GUI-INSPECT WRAPPER (diagnostic build; not part of the app) ===
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
SetTimer(OpenGuiForWsl, -1000)"""

def main():
    c = open(SRC).read()
    c = c.replace('#Requires AutoHotkey v2.0', '#Requires AutoHotkey v2.0\n#Warn All, Off', 1)
    old = """; Set up the configurable hotkey (default Alt+C, see bar_cheat.ini)
SetupHotkey()
"""
    assert old in c, "anchor block not found"
    c = c.replace(old, WRAPPER + "\n\n")
    open(OUT, "w").write(c)
    print("wrote", OUT)

if __name__ == "__main__":
    main()