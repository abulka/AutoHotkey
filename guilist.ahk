#Requires AutoHotkey v2.0

; Create the main GUI
MyGui := Gui()
MyGui.Title := "Choose an Option"
MyGui.SetFont("s10")

; Add some padding and a header
MyGui.Add("Text", "x10 y10 w300", "Please select one of the following options:")

; Add radio buttons for options
Option1 := MyGui.Add("Radio", "x20 y40 vSelectedOption", "Option 1: Send an email")
Option2 := MyGui.Add("Radio", "x20 y70", "Option 2: Create a new file")
Option3 := MyGui.Add("Radio", "x20 y100", "Option 3: Open calculator")
Option4 := MyGui.Add("Radio", "x20 y130", "Option 4: Show current time")
Option5 := MyGui.Add("Radio", "x20 y160", "Option 5: Clear clipboard")

; Add OK and Cancel buttons
MyGui.Add("Button", "x20 y200 w100", "OK").OnEvent("Click", ProcessChoice)
MyGui.Add("Button", "x140 y200 w100", "Cancel").OnEvent("Click", (*) => MyGui.Destroy())

; Show the GUI
MyGui.Show()

ProcessChoice(*) {
    saved := MyGui.Submit()  ; Save the current state of all controls
    
    ; Check which option was selected
    if saved.SelectedOption = 1
        RunAction("Opening email client...", "Run", "mailto:")
    else if saved.SelectedOption = 2
        ; RunAction("Creating new file...", "FileAppend", "", A_Desktop "\NewFile.txt")
        MsgBox "Hello "
    else if saved.SelectedOption = 3
        RunAction("Opening calculator...", "Run", "calc.exe")
    else if saved.SelectedOption = 4
        RunAction("Current time:", "MsgBox", FormatTime(, "yyyy-MM-dd HH:mm:ss"))
    else if saved.SelectedOption = 5
        RunAction("Clearing clipboard...", "A_Clipboard", "")
    else
        MsgBox("Please select an option first!")
    
    MyGui.Destroy()
}

RunAction(message, action, param := "") {
    ;MsgBox(message)
    if action = "Run"
        Run(param)
    else if action = "FileAppend"
        FileAppend(param[1], param[2])
    else if action = "MsgBox"
        MsgBox(param)
    else if action = "A_Clipboard"
        A_Clipboard := param
}