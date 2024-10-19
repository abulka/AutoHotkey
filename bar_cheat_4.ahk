#Requires AutoHotkey v2.0

; Ensure single instance
#SingleInstance Force

; Global variable to track GUI and its contents
global gGui := ""
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
!n::Run "notepad"
!a::Run "calc.exe"

; Define hotkeys for when GUI is active
#HotIf WinActive("ahk_class AutoHotkeyGUI")
Enter::PasteSelectedCode
Escape::CloseGui()
#HotIf

ShowGui() {
    global gGui
    
    ; If GUI exists, show it
    try {
        if IsObject(gGui) && WinExist("ahk_id " gGui.Hwnd) {
            gGui.Show()
            WinActivate("ahk_id " gGui.Hwnd)
            return
        }
    }
    
    ; Create new GUI if it doesn't exist
    gGui := Gui()
    gGui.Title := "Total Annihilation Cheat Codes"
    gGui.SetFont("s10")
    
    ; Add instructions
    gGui.Add("Text", "x10 y10 w300", "Select a cheat code and press Enter or click Paste:")
    
    ; Add ListBox with scrollbar and double-click event
    ListBox := gGui.Add("ListBox", "x10 y40 w300 h200 vSelectedCheat", CheatCodes)
    ListBox.OnEvent("DoubleClick", PasteSelectedCode)
    
    ; Add Paste and Close buttons
    PasteBtn := gGui.Add("Button", "x10 y250 w140", "Paste Code (Enter)")
    CloseBtn := gGui.Add("Button", "x170 y250 w140", "Close (Esc)")
    
    ; Button handlers
    PasteBtn.OnEvent("Click", PasteSelectedCode)
    CloseBtn.OnEvent("Click", CloseGui)
    
    ; Handle GUI close event
    gGui.OnEvent("Close", CloseGui)
    
    ; Show the GUI
    gGui.Show()
}

PasteSelectedCode(*) {
    global gGui
    
    saved := gGui.Submit(false)  ; Save the current state without hiding the GUI
    if !saved.HasProp("SelectedCheat") || saved.SelectedCheat = ""
        return
    
    ; Extract the cheat code from the selected item
    selectedText := saved.SelectedCheat
    cheatCode := StrSplit(selectedText, "|")[2]
    
    ; Hide the GUI
    gGui.Hide()
    
    ; Wait before starting to type
    Sleep(200)
    
    ; Send Enter key before the cheat code
    SendInput("{Enter}")
    Sleep(50)
    
    ; Send each character with a delay
    for char in StrSplit(cheatCode) {
        SendInput(char)
        Sleep(30)  ; 30ms delay between each character
    }
    
    ; Wait a moment before sending Enter
    Sleep(50)
    SendInput("{Enter}")
    
    ; Close the GUI
    CloseGui()
}

CloseGui(*) {
    global gGui
    
    if IsObject(gGui) {
        gGui.Destroy()
        gGui := ""
    }
}