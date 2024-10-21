#Requires AutoHotkey v2.0

; Ensure single instance
#SingleInstance Force

; Global variables
global gGui := ""
global mouseX := 0, mouseY := 0
global AmountBox := ""
global CheatCodesFile := A_ScriptDir "\bar_cheats.txt"
global LastModified := ""
global TreeView := ""
global TreeViewStateFile := A_ScriptDir "\bar_treeview_state.txt"
global ImageListID := ""

; Define the hotkey (Alt+C)
!c::ShowGui()

; Define hotkeys for when GUI is active
#HotIf WinActive("ahk_class AutoHotkeyGUI")
Enter::PasteSelectedCode
Escape::CloseGui()
#HotIf

LoadCheatCodes() {
    global CheatCodesFile, LastModified
    
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
        ; Write the default cheats to the file
        FileAppend(defaultCheats, CheatCodesFile)
        
        ; Set LastModified to the current time
        LastModified := FileGetTime(CheatCodesFile)
    } else {
        ; Update last modified time
        LastModified := FileGetTime(CheatCodesFile)
    }

    ; Read and parse file
    fileContent := FileRead(CheatCodesFile)
    return ParseCheatFile(fileContent)
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
    global gGui, AmountBox, TreeView, LastModified, ImageListID
    global mouseX, mouseY, CheatCodesFile, TreeViewStateFile
  
    ; Check if file has been modified
    if FileExist(CheatCodesFile) {
        currentModified := FileGetTime(CheatCodesFile)
        shouldReload := currentModified != LastModified
    } else {
        shouldReload := true
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
    
    ; Create new GUI
    gGui := Gui("+AlwaysOnTop +Owner")
    gGui.Title := "Total Annihilation Cheat Codes"
    gGui.SetFont("s10")
    
    ; Add instructions
    gGui.Add("Text", "x10 y10 w300", "Select a cheat code and press Enter or click Paste:")
    
    ; Create ImageList
    ImageListID := IL_Create(10)
    LoadImagesToImageList(ImageListID, "unit_images")
    
    ; Add TreeView with ImageList
    TreeView := gGui.Add("TreeView", "x10 y40 w300 h200 vSelectedCheat ImageList" . ImageListID)
    TreeView.OnEvent("DoubleClick", PasteSelectedCode)
    TreeView.OnEvent("ItemSelect", UpdateCheatAmount)
    
    ; Load cheats into TreeView
    cheats := LoadCheatCodes()
    PopulateTreeView(TreeView, cheats)

    ; Restore TreeView state
    RestoreTreeViewState(TreeView, TreeViewStateFile)

    ; Add text box and increment/decrement buttons for the cheat amount
    gGui.Add("Text", "x10 y250 w100", "Amount:")
    AmountBox := gGui.Add("Edit", "x120 y250 w50 vCheatAmount", "")
    IncBtn := gGui.Add("Button", "x180 y250 w30", "+")
    DecBtn := gGui.Add("Button", "x220 y250 w30", "-")
    
    ; Add Paste and Close buttons
    PasteBtn := gGui.Add("Button", "x10 y290 w140", "Paste Code (Enter)")
    CloseBtn := gGui.Add("Button", "x170 y290 w140", "Close (Esc)")
    
    ; Add Debug button
    ; DebugBtn := gGui.Add("Button", "x10 y330 w140", "Save Tree State (Debug)")
    ; DebugBtn.OnEvent("Click", SaveTreeViewStateDebug)
    
    ; Button handlers
    PasteBtn.OnEvent("Click", PasteSelectedCode)
    CloseBtn.OnEvent("Click", CloseGui)
    IncBtn.OnEvent("Click", IncrementAmount)
    DecBtn.OnEvent("Click", DecrementAmount)
    
    ; Handle GUI close event
    gGui.OnEvent("Close", CloseGui)
    
    ; Show and force activate the GUI
    gGui.Show()
    ForceActivateWindow(gGui)
}

LoadImagesToImageList(ImageListID, imageDir) {
    for file in Dir(imageDir "\*.png") {
        IL_Add(ImageListID, file.FullPath)
    }
}

PopulateTreeView(TreeView, cheats) {
    TreeView.Delete()
    itemMap := Map()  ; Store mapping of items to their command strings
    imageIndexMap := Map()  ; Store mapping of unit names to image indices
    
    ; Load images into ImageList and map unit names to image indices
    for file in File.Dir("unit_images\*.png") {
        unitName := StrReplace(file.Name, ".png", "")
        imageIndex := IL_Add(ImageListID, file.FullPath)
        imageIndexMap[unitName] := imageIndex
    }
    
    for category, cheatList in cheats {
        ; Add category with no icon
        parentId := TreeView.Add(category, 0, "")
        
        ; Verify that parentId is an integer
        if !IsInteger(parentId) {
            MsgBox "parentId is not an integer: " parentId
            Return
        }
        
        ; Add cheats under category with corresponding icon if available
        for cheat in cheatList {
            unitName := StrReplace(cheat.name, " ", "")
            imageIndex := imageIndexMap.Has(unitName) ? imageIndexMap[unitName] : 0
            childId := TreeView.Add(cheat.name, parentId, imageIndex)
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
    global TreeView, AmountBox
    
    ; Get the selected item's ID number
    selectedItemId := TreeView.GetSelection()
    
    ; Check if an item is selected
    if !selectedItemId {
        AmountBox.Value := ""
        return
    }
    
    ; Check if the selected item is a child item (has a parent)
    if !TreeView.GetParent(selectedItemId) {
        AmountBox.Value := ""
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
}

IncrementAmount(*) {
    global AmountBox
    
    amount := AmountBox.Value
    if amount != ""
        amount++
    AmountBox.Value := amount
}

DecrementAmount(*) {
    global AmountBox
    
    amount := AmountBox.Value
    if amount != ""
        amount--
    AmountBox.Value := amount
}

PasteSelectedCode(*) {
    global gGui, AmountBox, TreeView, TreeViewStateFile
    
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