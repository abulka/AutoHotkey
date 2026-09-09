#Requires AutoHotkey v2.0

; Ensure single instance
#SingleInstance Force

; Match window titles by substring (needed for the title-based game fallback)
SetTitleMatchMode(2)

; Global variables
global gGui := ""
global mouseX := 0, mouseY := 0
global AmountBox := ""
global SearchBox := ""
global CheatCodesFile := A_ScriptDir "\bar_cheats.txt"
global LastModified := ""
global RecentCheatsFile := A_ScriptDir "\bar_cheats_recent.txt"
global LastModifiedRecent := ""
global TreeView := ""
global TreeViewStateFile := A_ScriptDir "\bar_treeview_state.txt"
global ImageViewer := ""
global CheatCodeDisplay := ""
global cheatsData := Map()
global ConfigFile := A_ScriptDir "\bar_cheat.ini"
global GameWinCriteria := ["ahk_exe spring.exe", "Beyond All Reason"]

; Returns the hwnd of the game window, or 0 if not found.
; Tries each criteria in GameWinCriteria in order.
FindGameWindow() {
    global GameWinCriteria
    for criteria in GameWinCriteria {
        hwnd := WinExist(criteria)
        if hwnd
            return hwnd
    }
    return 0
}

; Define hotkeys for when GUI is active
#HotIf WinActive("ahk_class AutoHotkeyGUI")
Enter::PasteSelectedCode
Escape::CloseGui()
#HotIf

; Set up the configurable hotkey (default Alt+C, see bar_cheat.ini)
SetupHotkey()

SetupHotkey() {
    global ConfigFile
    if !FileExist(ConfigFile)
        IniWrite("!c", ConfigFile, "Settings", "Hotkey")
    hk := IniRead(ConfigFile, "Settings", "Hotkey", "!c")
    ; Hotkey callbacks must accept the hotkey name parameter, hence the closure
    try {
        Hotkey(hk, (*) => ShowGui())
    } catch {
        ; Fall back to the default if the ini contains an invalid hotkey
        Hotkey("!c", (*) => ShowGui())
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

    ; Read and parse both files
    mainContent := FileRead(CheatCodesFile)
    recentContent := FileRead(RecentCheatsFile)
    
    ; Merge the contents
    mergedContent := recentContent "`n" mainContent
    
    return ParseCheatFile(mergedContent)
}

AddToRecent(cheatName, cheatCode) {
    global RecentCheatsFile
    
    ; Read existing recents
    recents := []
    if FileExist(RecentCheatsFile) {
        content := FileRead(RecentCheatsFile)
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if !line || line = "Recent"
                continue
            recents.Push(line)
        }
    }
    
    ; Remove existing entry if present
    newRecents := []
    newCheat := cheatName "|" cheatCode
    for recent in recents {
        if recent != newCheat
            newRecents.Push(recent)
    }
    
    ; Add new entry at the beginning
    newRecents.InsertAt(1, newCheat)
    
    ; Write back to file
    content := "Recent`n"
    for recent in newRecents {
        content .= recent "`n"
    }
    
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

ShowGui() {
    global gGui, AmountBox, SearchBox, TreeView, LastModified, LastModifiedRecent, ImageViewer, CheatCodeDisplay
    global mouseX, mouseY, CheatCodesFile, RecentCheatsFile, TreeViewStateFile, cheatsData
  
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
    
    ; Create new GUI with increased width
    gGui := Gui("+AlwaysOnTop +Owner")
    gGui.Title := "Total Annihilation Cheat Codes"
    gGui.SetFont("s10")
    
    ; Add instructions
    gGui.Add("Text", "x10 y10 w400", "Select a cheat code and press Enter or click Paste:")

    ; Add search box (filters the tree as you type)
    gGui.Add("Text", "x10 y32 w100", "Search:")
    SearchBox := gGui.Add("Edit", "x120 y30 w290", "")
    SearchBox.OnEvent("Change", FilterTreeView)

    ; Add TreeView
    TreeView := gGui.Add("TreeView", "x10 y55 w400 h200 vSelectedCheat")
    TreeView.OnEvent("DoubleClick", PasteSelectedCode)
    TreeView.OnEvent("ItemSelect", UpdateCheatAmount)

    ; Load cheats into TreeView
    cheats := LoadCheatCodes()
    cheatsData := cheats
    PopulateTreeView(TreeView, cheats)

    ; Restore TreeView state
    RestoreTreeViewState(TreeView, TreeViewStateFile)

    ; Add text box and increment/decrement buttons for the cheat amount
    gGui.Add("Text", "x10 y270 w100", "Amount:")
    AmountBox := gGui.Add("Edit", "x120 y270 w50 vCheatAmount", "")
    IncBtn := gGui.Add("Button", "x180 y270 w30", "+")
    DecBtn := gGui.Add("Button", "x220 y270 w30", "-")

    ; Add buttons to set specific amounts
    Btn1 := gGui.Add("Button", "x260 y270 w30", "1")
    Btn2 := gGui.Add("Button", "x300 y270 w30", "2")
    Btn5 := gGui.Add("Button", "x340 y270 w30", "5")
    Btn10 := gGui.Add("Button", "x380 y270 w30", "10")

    ; Add Paste and Close buttons
    PasteBtn := gGui.Add("Button", "x10 y310 w190", "Paste Code (Enter)")
    CloseBtn := gGui.Add("Button", "x210 y310 w190", "Close (Esc)")

    ; Add image viewer with fixed size and centered
    ImageViewer := gGui.Add("Picture", "x72 y350 w256 h256 +Center")

    ; Add cheat code display
    CheatCodeDisplay := gGui.Add("Text", "x10 y620 w400", "")

    ; Button handlers
    PasteBtn.OnEvent("Click", PasteSelectedCode)
    CloseBtn.OnEvent("Click", CloseGui)
    IncBtn.OnEvent("Click", IncrementAmount)
    DecBtn.OnEvent("Click", DecrementAmount)
    Btn1.OnEvent("Click", (*) => SetAmount(1))
    Btn2.OnEvent("Click", (*) => SetAmount(2))
    Btn5.OnEvent("Click", (*) => SetAmount(5))
    Btn10.OnEvent("Click", (*) => SetAmount(10))
    
    ; Handle GUI close event
    gGui.OnEvent("Close", CloseGui)
    
    ; Show and force activate the GUI
    gGui.Show()
    ForceActivateWindow(gGui)

    ; Set a timer to delay the selection and event trigger
    SetTimer(DelayedSelect, -100)    
}

DelayedSelect() {
    global TreeView

    ; Find the "Recent" category node
    recentNode := ""
    node := TreeView.GetChild(0)
    while node {
        if (TreeView.GetText(node) = "Recent") {
            recentNode := node
            break
        }
        node := TreeView.GetNext(node)
    }

    if recentNode {
        firstChild := TreeView.GetChild(recentNode)  ; Get first child of Recent category
        if firstChild {
            TreeView.Modify(firstChild, "Select")  ; Select the first child
            TreeView.Modify(recentNode, "Expand")  ; Expand the Recent category
            ; Trigger the click event
            UpdateCheatAmount(firstChild)
        }
    }
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

        ; Add cheats under category
        for cheat in cheatList {
            childId := TreeView.Add(cheat.name, parentId, 0)
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
    global SearchBox, TreeView, cheatsData, TreeViewStateFile

    searchText := SearchBox.Value
    if Trim(searchText) = "" {
        ; No search text: show everything and restore saved expand state
        PopulateTreeView(TreeView, cheatsData)
        RestoreTreeViewState(TreeView, TreeViewStateFile)
        return
    }

    ; Build a filtered map of categories to matching cheats
    filtered := Map()
    for category, cheatList in cheatsData {
        matched := []
        for cheat in cheatList {
            if MatchSearch(cheat.name, searchText)
                matched.Push(cheat)
        }
        if matched.Length
            filtered[category] := matched
    }

    PopulateTreeView(TreeView, filtered, true)

    ; Select the first match so Enter pastes it right away
    firstCategory := TreeView.GetChild(0)
    if firstCategory {
        firstMatch := TreeView.GetChild(firstCategory)
        if firstMatch {
            TreeView.Modify(firstMatch, "Select")
            UpdateCheatAmount(firstMatch)
        }
    }
}

SaveTreeViewState(TreeView, filePath) {
    state := ""
    itemId := 0  ; Start at the top of the tree
    Loop {
        itemId := TreeView.GetNext(itemId, "Full")
        if !itemId
            break
        if TreeView.Get(itemId, "Expand") {
            itemText := TreeView.GetText(itemId)
            state .= itemText "`n"
        }
    }
    ; MsgBox "Final TreeView State: " state  ; Debugging message box
    
    ; Use FileOpen to write to the file
    file := FileOpen(filePath, "w")
    if file {
        file.Write(state)
        file.Close()
    } else {
        MsgBox "Failed to open file: " filePath
    }
}

SaveTreeViewStateDebug(*) {
    global TreeView, TreeViewStateFile
    SaveTreeViewState(TreeView, TreeViewStateFile)
}

RestoreTreeViewState(TreeView, filePath) {
    if !FileExist(filePath)
        return
    
    state := FileRead(filePath, "UTF-8")
    expandedItems := StrSplit(state, "`n")
    
    itemId := 0  ; Start at the top of the tree
    Loop {
        itemId := TreeView.GetNext(itemId, "Full")
        if !itemId
            break
        itemText := TreeView.GetText(itemId)
        for expandedItem in expandedItems {
            if itemText = expandedItem {
                TreeView.Modify(itemId, "Expand")
                break
            }
        }
    }
}

ForceActivateWindow(gui) {
    ; Show the window if it's hidden
    gui.Show()
    
    ; Get the window handle
    hwnd := gui.Hwnd
    
    ; Force the window to be on top and active
    WinSetAlwaysOnTop(true, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)
    
    ; Additional forced focus after a small delay
    SetTimer(FocusWindow.Bind(hwnd), -50)
}

FocusWindow(hwnd) {
    WinActivate("ahk_id " hwnd)
}

; Returns the cheat code of the selected child item, or "" if nothing
; valid is selected (nothing selected, or a category node).
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
    global AmountBox, ImageViewer, CheatCodeDisplay
    AmountBox.Value := ""
    ImageViewer.Value := ""
    CheatCodeDisplay.Value := ""
}

UpdateCheatAmount(*) {
    global AmountBox, ImageViewer, CheatCodeDisplay

    cheatCode := GetSelectedCheatCode()
    if !cheatCode {
        ClearSelectionUI()
        return
    }

    ; Update the text box with the extracted amount
    AmountBox.Value := ExtractCheatAmount(cheatCode)

    ; Load the unit image if it exists
    ImageViewer.Value := ""
    if RegExMatch(cheatCode, "/give \d+ (\w+) \d+", &unitName) {
        imagePath := A_ScriptDir "\unit_images\" unitName[1] ".png"
        if FileExist(imagePath)
            ImageViewer.Value := imagePath
    }

    ; Update the cheat code display
    CheatCodeDisplay.Value := cheatCode
}

AdjustAmount(delta, min := 0) {
    global AmountBox

    if !GetSelectedCheatCode()
        return

    amount := AmountBox.Value
    if amount != "" {
        amount += delta
        if amount < min
            amount := min
    }
    AmountBox.Value := amount

    ; Update the cheat code display with the new amount
    UpdateCheatCodeDisplay()
}

IncrementAmount(*) {
    AdjustAmount(1)
}

DecrementAmount(*) {
    AdjustAmount(-1, 1)
}

SetAmount(amount) {
    global AmountBox

    if !GetSelectedCheatCode()
        return

    AmountBox.Value := amount

    ; Update the cheat code display with the new amount
    UpdateCheatCodeDisplay()
}

UpdateCheatCodeDisplay() {
    global AmountBox, CheatCodeDisplay

    cheatCode := GetSelectedCheatCode()
    if !cheatCode {
        CheatCodeDisplay.Value := ""
        return
    }

    ; Get the edited amount from the text box if the command is /give and has a number
    if InStr(cheatCode, "/give") && RegExMatch(cheatCode, " (\d+) ")
        cheatCode := ReplaceCheatAmount(cheatCode, AmountBox.Value)

    ; Update the cheat code display
    CheatCodeDisplay.Value := cheatCode
}

PasteSelectedCode(*) {
    global gGui, AmountBox, TreeView, TreeViewStateFile, mouseX, mouseY
    
    ; Save TreeView state before hiding the GUI
    SaveTreeViewState(TreeView, TreeViewStateFile)
    
    ; Get the selected item's text and cheat code ("" if nothing valid is selected)
    cheatCode := GetSelectedCheatCode()
    if !cheatCode
        return
    itemText := TreeView.GetText(TreeView.GetSelection())

    ; Get the edited amount from the text box if the command is /give and has a number
    if InStr(cheatCode, "/give") && RegExMatch(cheatCode, " (\d+) ")
        cheatCode := ReplaceCheatAmount(cheatCode, AmountBox.Value)
    
    ; Verify the game is running; only paste into Beyond All Reason
    gameHwnd := FindGameWindow()
    if !gameHwnd {
        TrayTip("Beyond All Reason window not found - cheat not pasted.", "BAR Cheat")
        CloseGui()
        return
    }

    ; Add to recent cheats
    AddToRecent(itemText, cheatCode)

    ; Hide GUI
    gGui.Hide()

    ; Wait a moment before trying to activate game window
    Sleep(200)

    ; Activate the game window
    WinActivate(gameHwnd)
    
    ; Additional delay to ensure window activation
    Sleep(300)
    
    ; Send Enter key before the cheat code
    SendInput("{Enter}")
    Sleep(50)

    ; Send the cheat code in one shot
    SendText(cheatCode)
    Sleep(50)
    
    ; Restore mouse position after delay
    Sleep(300)
    MouseMove(mouseX, mouseY)

    Sleep(50)
    SendInput("{Enter}")
    
    CloseGui()
}

CloseGui(*) {
    global gGui
    
    if IsObject(gGui) {
        gGui.Destroy()
        gGui := ""
    }
}