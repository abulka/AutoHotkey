#Requires AutoHotkey v2.0

; Create the main GUI
MyGui := Gui()
MyGui.Title := "Total Annihilation Cheat Codes"
MyGui.SetFont("s10")

; Add instructions
MyGui.Add("Text", "x10 y10 w300", "Select a cheat code and press Enter or click Paste:")

; Create a ListBox with all cheat codes
CheatCodes := [
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

; Add ListBox with scrollbar
CheatList := MyGui.Add("ListBox", "x10 y40 w300 h200 vSelectedCheat", CheatCodes)

; Add Paste and Close buttons
PasteBtn := MyGui.Add("Button", "x10 y250 w140", "Paste Code (Enter)")
CloseBtn := MyGui.Add("Button", "x170 y250 w140", "Close (Esc)")

; Button and hotkey handlers
PasteBtn.OnEvent("Click", PasteCode)
CloseBtn.OnEvent("Click", (*) => MyGui.Destroy())

; Add hotkeys
HotIfWinActive("ahk_id " MyGui.Hwnd)
Hotkey("Enter", PasteCode)
Hotkey("Escape", (*) => MyGui.Destroy())

; Show the GUI
MyGui.Show()

PasteCode(*) {
    saved := MyGui.Submit(false)  ; Save the current state without hiding the GUI
    if !saved.HasProp("SelectedCheat") || saved.SelectedCheat = ""
        return
    
    ; Extract the cheat code from the selected item
    selectedText := saved.SelectedCheat
    cheatCode := StrSplit(selectedText, "|")[2]
    
    ; Hide the GUI
    MyGui.Hide()
    
    ; Wait before starting to type
    Sleep(200)
    
    ; Send each character with a delay
    for char in StrSplit(cheatCode) {
        SendInput(char)
        Sleep(30)  ; 30ms delay between each character
    }
    
    ; Wait a moment before sending Enter
    Sleep(50)
    SendInput("{Enter}")
    
    ; Destroy the GUI
    MyGui.Destroy()
}

; Function to handle window closing
OnMessage(0x112, WM_SYSCOMMAND)
WM_SYSCOMMAND(wParam, *) {
    if (wParam = 0xF060) {
        MyGui.Destroy()
    }
}