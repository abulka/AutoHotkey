#Requires AutoHotkey v2.0

; Easy to make GUIs
MyGui := Gui()
MyGui.Add("Text",, "Enter your name")
MyGui.Add("Edit", "w150 vName")
MyGui.Add("Button",, "OK").OnEvent("Click", SayHello)
MyGui.Show()
Return

SayHello(*)
{
    Saved := MyGui.Submit()
    MsgBox "Hello " Saved.Name
    ExitApp
}