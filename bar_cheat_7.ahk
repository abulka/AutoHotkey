#Requires AutoHotkey v2.0

; Ensure single instance
#SingleInstance Force

; Global variables
global gGui := ""
global mouseX := 0, mouseY := 0
global AmountBox := ""  ; Declare AmountBox as a global variable
global CheatCodes := [
    "Constructors|/give 10 armck 0",
    "Construction Kbot|/give 10 armack 0",
    "Construction Turret|/give 1 armnanotc 0",
    "Tech 2 Lab|/give 1 armalab 0",
    "Tech 3 Lab|/give 1 armshltx 0",
    "Spider|/give 10 armsptk 0",
    "Titan (Bantha)|/give 10 armbanth 0",
    "Anti Missile (Ferret)|/give 1 armferret 0",
    "Flak|/give 1 armflak 0",
    "Advanced Radar|/give 1 armarad 0",
    "Shield|/give 1 armgate 0",
    "Big Bertha|/give 1 armbrtha 0"
]

; Define the hotkey (Alt+C)
!c::ShowGui()

; Define hotkeys for when GUI is active
#HotIf WinActive("ahk_class AutoHotkeyGUI")
Enter::PasteSelectedCode
Escape::CloseGui()
#HotIf

ShowGui() {
    global gGui, AmountBox
    global mouseX, mouseY
  
    ; Capture current mouse position
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)

    ; If GUI exists, show and activate it
    try {
        if IsObject(gGui) && WinExist("ahk_id " gGui.Hwnd) {
            ForceActivateWindow(gGui)
            return
        }
    }
    
    ; Create new GUI if it doesn't exist
    gGui := Gui("+AlwaysOnTop +Owner")  ; Added AlwaysOnTop and Owner
    gGui.Title := "Total Annihilation Cheat Codes"
    gGui.SetFont("s10")
    
    ; Add instructions
    gGui.Add("Text", "x10 y10 w300", "Select a cheat code and press Enter or click Paste:")
    
    ; Add ListBox with scrollbar
    ListBox := gGui.Add("ListBox", "x10 y40 w300 h200 vSelectedCheat", CheatCodes)
    ListBox.OnEvent("DoubleClick", PasteSelectedCode)
    ListBox.OnEvent("Change", UpdateCheatAmount)

    ; Add text box and increment/decrement buttons for the cheat amount
    gGui.Add("Text", "x10 y250 w100", "Amount:")
    AmountBox := gGui.Add("Edit", "x120 y250 w50 vCheatAmount", "")
    IncBtn := gGui.Add("Button", "x180 y250 w30", "+")
    DecBtn := gGui.Add("Button", "x220 y250 w30", "-")
    
    ; Add Paste and Close buttons
    PasteBtn := gGui.Add("Button", "x10 y290 w140", "Paste Code (Enter)")
    CloseBtn := gGui.Add("Button", "x170 y290 w140", "Close (Esc)")
    
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
    global gGui, AmountBox
    
    saved := gGui.Submit(false)
    if !saved.HasProp("SelectedCheat") || saved.SelectedCheat = ""
        return
    
    ; Extract the number from the selected cheat code
    selectedText := saved.SelectedCheat
    cheatCode := StrSplit(selectedText, "|")[2]
    amount := RegExReplace(cheatCode, ".*? (\d+) .*", "$1")
    
    ; Update the text box with the extracted amount
    AmountBox.Value := amount
}

IncrementAmount(*) {
    global AmountBox
    
    amount := AmountBox.Value
    amount++
    AmountBox.Value := amount
}

DecrementAmount(*) {
    global AmountBox
    
    amount := AmountBox.Value
    amount--
    AmountBox.Value := amount
}

PasteSelectedCode(*) {
    global gGui, AmountBox
    
    saved := gGui.Submit(false)
    if !saved.HasProp("SelectedCheat") || saved.SelectedCheat = ""
        return
    
    ; Extract the cheat code
    selectedText := saved.SelectedCheat
    cheatCode := StrSplit(selectedText, "|")[2]
    
    ; Get the edited amount from the text box
    amount := AmountBox.Value
    cheatCode := RegExReplace(cheatCode, " (\d+) ", " " amount " ")
    
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
    for char in StrSplit(cheatCode) {
        SendInput(char)
        Sleep(30)
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