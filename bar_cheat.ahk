#Requires AutoHotkey v2.0

; Ensure single instance
#SingleInstance Force

; Global variables
global gGui := ""
global mouseX := 0, mouseY := 0
global AmountBox := ""
global CheatCodesFile := A_ScriptDir "\bar_cheats.txt"
global LastModified := ""
global RecentCheatsFile := A_ScriptDir "\bar_cheats_recent.txt"
global LastModifiedRecent := ""
global TreeView := ""
global TreeViewStateFile := A_ScriptDir "\bar_treeview_state.txt"
global ImageViewer := ""
global CheatCodeDisplay := ""

; Define the hotkey (Alt+C)
!c::ShowGui()

; Define hotkeys for when GUI is active
#HotIf WinActive("ahk_class AutoHotkeyGUI")
Enter::PasteSelectedCode
Escape::CloseGui()
#HotIf

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
    global gGui, AmountBox, TreeView, LastModified, LastModifiedRecent, ImageViewer, CheatCodeDisplay
    global mouseX, mouseY, CheatCodesFile, RecentCheatsFile, TreeViewStateFile
  
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
    
    ; Add TreeView
    TreeView := gGui.Add("TreeView", "x10 y40 w400 h200 vSelectedCheat")
    TreeView.OnEvent("DoubleClick", PasteSelectedCode)
    TreeView.OnEvent("ItemSelect", UpdateCheatAmount)
    
    ; Load cheats into TreeView
    cheats := LoadCheatCodes()
    PopulateTreeView(TreeView, cheats)

    ; Restore TreeView state
    RestoreTreeViewState(TreeView, TreeViewStateFile)

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
        }
    }

    ; Add text box and increment/decrement buttons for the cheat amount
    gGui.Add("Text", "x10 y250 w100", "Amount:")
    AmountBox := gGui.Add("Edit", "x120 y250 w50 vCheatAmount", "")
    IncBtn := gGui.Add("Button", "x180 y250 w30", "+")
    DecBtn := gGui.Add("Button", "x220 y250 w30", "-")
    
    ; Add buttons to set specific amounts
    Btn1 := gGui.Add("Button", "x260 y250 w30", "1")
    Btn2 := gGui.Add("Button", "x300 y250 w30", "2")
    Btn5 := gGui.Add("Button", "x340 y250 w30", "5")
    Btn10 := gGui.Add("Button", "x380 y250 w30", "10")
    
    ; Add Paste and Close buttons
    PasteBtn := gGui.Add("Button", "x10 y290 w190", "Paste Code (Enter)")
    CloseBtn := gGui.Add("Button", "x210 y290 w190", "Close (Esc)")
    
    ; Add image viewer with fixed size and centered
    ImageViewer := gGui.Add("Picture", "x72 y330 w256 h256 +Center")
    
    ; Add cheat code display
    CheatCodeDisplay := gGui.Add("Text", "x10 y600 w400", "")

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
}

PopulateTreeView(TreeView, cheats) {
    TreeView.Delete()
    itemMap := Map()  ; Store mapping of items to their command strings
    
    for category, cheatList in cheats {
        ; Add category
        parentId := TreeView.Add(category, 0, "")
        
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

UpdateCheatAmount(*) {
    global TreeView, AmountBox, ImageViewer, CheatCodeDisplay
    
    ; Get the selected item's ID number
    selectedItemId := TreeView.GetSelection()
    
    ; Check if an item is selected
    if !selectedItemId {
        AmountBox.Value := ""
        ImageViewer.Value := ""
        CheatCodeDisplay.Value := ""
        return
    }
    
    ; Check if the selected item is a child item (has a parent)
    if !TreeView.GetParent(selectedItemId) {
        AmountBox.Value := ""
        ImageViewer.Value := ""
        CheatCodeDisplay.Value := ""
        return
    }
    
    ; Get the item's text and associated cheat code
    itemText := TreeView.GetText(selectedItemId)
    itemMap := TreeView.itemMap
    cheatCode := itemMap[selectedItemId]
    
    ; Extract the number from the cheat code if it starts with /give and has a number
    if InStr(cheatCode, "/give") && RegExMatch(cheatCode, " (\d+) ") {
        amount := RegExReplace(cheatCode, ".*? (\d+) .*", "$1")
        ; Update the text box with the extracted amount
        AmountBox.Value := amount
    } else {
        AmountBox.Value := ""
    }
    
    ; Clear the ImageViewer before loading a new image
    ImageViewer.Value := ""
    
    ; Extract the unit name from the cheat code and load the image if it exists
    match := RegExMatch(cheatCode, "/give \d+ (\w+) \d+", &unitName)
    if match {
        imageName := unitName[1] ".png"
        imagePath := A_ScriptDir "\unit_images\" imageName
        if FileExist(imagePath) {
            ImageViewer.Value := imagePath
        } else {
            ImageViewer.Value := ""
        }
    } else {
        ImageViewer.Value := ""
    }
    
    ; Update the cheat code display
    CheatCodeDisplay.Value := cheatCode
}

IncrementAmount(*) {
    global AmountBox, CheatCodeDisplay, TreeView
    
    ; Check if an item is selected and is a child node
    selectedItemId := TreeView.GetSelection()
    if !selectedItemId || !TreeView.GetParent(selectedItemId) {
        ; MsgBox "Please select a valid cheat code."
        return
    }
    
    amount := AmountBox.Value
    if amount != ""
        amount++
    AmountBox.Value := amount
    
    ; Update the cheat code display with the new amount
    UpdateCheatCodeDisplay()
}

DecrementAmount(*) {
    global AmountBox, CheatCodeDisplay, TreeView
    
    ; Check if an item is selected and is a child node
    selectedItemId := TreeView.GetSelection()
    if !selectedItemId || !TreeView.GetParent(selectedItemId) {
        ; MsgBox "Please select a valid cheat code."
        return
    }
    
    amount := AmountBox.Value
    if amount != "" && amount > 1
        amount--
    AmountBox.Value := amount
    
    ; Update the cheat code display with the new amount
    UpdateCheatCodeDisplay()
}

SetAmount(amount) {
    global AmountBox, CheatCodeDisplay, TreeView
    
    ; Check if an item is selected and is a child node
    selectedItemId := TreeView.GetSelection()
    if !selectedItemId || !TreeView.GetParent(selectedItemId) {
        ; MsgBox "Please select a valid cheat code."
        return
    }
    
    AmountBox.Value := amount
    
    ; Update the cheat code display with the new amount
    UpdateCheatCodeDisplay()
}

UpdateCheatCodeDisplay() {
    global TreeView, AmountBox, CheatCodeDisplay
    
    ; Get the selected item's ID number
    selectedItemId := TreeView.GetSelection()
    
    ; Check if an item is selected
    if !selectedItemId {
        CheatCodeDisplay.Value := ""
        return
    }
    
    ; Get the item's text and associated cheat code
    itemMap := TreeView.itemMap
    cheatCode := itemMap[selectedItemId]
    
    ; Get the edited amount from the text box if the command is /give and has a number
    if InStr(cheatCode, "/give") && RegExMatch(cheatCode, " (\d+) ") {
        amount := AmountBox.Value
        cheatCode := RegExReplace(cheatCode, " (\d+) ", " " amount " ")
    }
    
    ; Update the cheat code display
    CheatCodeDisplay.Value := cheatCode
}

PasteSelectedCode(*) {
    global gGui, AmountBox, TreeView, TreeViewStateFile, mouseX, mouseY
    
    ; Save TreeView state before hiding the GUI
    SaveTreeViewState(TreeView, TreeViewStateFile)
    
    ; Get the selected item's ID number
    selectedItemId := TreeView.GetSelection()
    
    ; Check if an item is selected
    if !selectedItemId {
        return
    }
    
    ; Check if the selected item is a child item (has a parent)
    if !TreeView.GetParent(selectedItemId) {
        return
    }
    
    ; Get the item's text and associated cheat code
    itemText := TreeView.GetText(selectedItemId)
    itemMap := TreeView.itemMap
    cheatCode := itemMap[selectedItemId]
    
    ; Get the edited amount from the text box if the command is /give and has a number
    if InStr(cheatCode, "/give") && RegExMatch(cheatCode, " (\d+) ") {
        amount := AmountBox.Value
        cheatCode := RegExReplace(cheatCode, " (\d+) ", " " amount " ")
    }
    
    ; Add to recent cheats
    AddToRecent(itemText, cheatCode)

    ; Store the game window title/class
    try {
        gameWin := WinGetTitle("A")  ; Get the title of the active window
    } catch {
        gameWin := "A"  ; Fallback to just using the active window
    }
    
    ; Hide GUI
    gGui.Hide()
    
    ; Wait a moment before trying to activate game window
    Sleep(200)
    
    ; Try different methods to activate the game window
    try {
        ; First try by stored title
        if gameWin != "A"
            WinActivate(gameWin)
        
        ; If that didn't work, try getting the last active window
        if !WinActive(gameWin)
            WinActivate("A")
    } catch {
        ; If all else fails, just try to send the keys to the active window
    }
    
    ; Additional delay to ensure window activation
    Sleep(300)
    
    ; Send Enter key before the cheat code
    SendInput("{Enter}")
    Sleep(50)

    ; Send each character with a delay
    ; MsgBox cheatCode
    for char in StrSplit(cheatCode) {
        SendInput(char)
        Sleep(60)
    }
    
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