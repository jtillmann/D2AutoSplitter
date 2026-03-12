#Requires AutoHotkey v2.0

; ===================================================
; Settings Window Module
; ===================================================

global SettingsGui := ""
global hkCtrls := Map()
global fiCtrls := Map()

OpenSettingsWindow(*) {
    global SettingsGui, settings, FirstInputKeys, hkCtrls, fiCtrls

    ; Lock main window
    if (IsSet(MainGui))
        MainGui.Opt("+Disabled")

    SettingsGui := Gui("+AlwaysOnTop", "Settings")
    SettingsGui.OnEvent("Close", CloseSettingsWindow)

    SettingsGui.Add("GroupBox", "x10 y10 w230 h180", "Hotkeys")

    SettingsGui.Add("Text", "x20 y30 w80 h20 +0x200", "Start/Split")
    hkCtrls["Start"] := SettingsGui.Add("Hotkey", "x100 y30 w120 h21", settings["StartHotkey"])

    SettingsGui.Add("Text", "x20 y60 w80 h20 +0x200", "Reset")
    hkCtrls["Reset"] := SettingsGui.Add("Hotkey", "x100 y60 w120 h21", settings["ResetHotkey"])

    SettingsGui.Add("Text", "x20 y90 w80 h20 +0x200", "Undo Split")
    hkCtrls["Undo"] := SettingsGui.Add("Hotkey", "x100 y90 w120 h21", settings["UndoHotkey"])

    SettingsGui.Add("Text", "x20 y120 w80 h20 +0x200", "Skip Split")
    hkCtrls["Skip"] := SettingsGui.Add("Hotkey", "x100 y120 w120 h21", settings["SkipHotkey"])

    SettingsGui.Add("Text", "x20 y150 w80 h20 +0x200", "Capture")
    hkCtrls["Capture"] := SettingsGui.Add("Hotkey", "x100 y150 w120 h21", settings["CaptureHotkey"])

    SettingsGui.Add("GroupBox", "x250 y10 w310 h180", "First Input Keys")

    yPos := 30
    xPos := 260
    index := 1
    for item in FirstInputKeys {
        key := item[1]
        name := item[2]
        isChecked := (settings["FI_" key] == "1") ? "Checked" : ""
        fiCtrls[key] := SettingsGui.Add("CheckBox", "x" xPos " y" yPos " w140 h20 " isChecked, name)
        yPos += 22
        index++
        if (index == 6) {
            xPos += 150
            yPos := 30
        }
    }

    btnSave := SettingsGui.Add("Button", "x460 y200 w100 h30", "Save")
    btnSave.OnEvent("Click", SaveSettingsFromGUI)

    SettingsGui.Show("w570 h240")
}

CloseSettingsWindow(*) {
    global SettingsGui
    if (IsSet(MainGui)) {
        MainGui.Opt("-Disabled")
        MainGui.Show()
    }
    SettingsGui.Destroy()
}

SaveSettingsFromGUI(*) {
    global settings, FirstInputKeys, hkCtrls, fiCtrls, settingsFile

    ; 1. Read values from GUI AND Unregister old hotkeys
    ; For hotkeys
    newHKs := Map(
        "StartHotkey", hkCtrls["Start"].Value,
        "ResetHotkey", hkCtrls["Reset"].Value,
        "SkipHotkey", hkCtrls["Skip"].Value,
        "UndoHotkey", hkCtrls["Undo"].Value,
        "CaptureHotkey", hkCtrls["Capture"].Value
    )

    for key, newKey in newHKs {
        oldKey := settings[key]
        if (oldKey != "") {
            try Hotkey("$" oldKey, "Off")
        }
        settings[key] := newKey
        if (newKey != "") {
            callback := (key = "StartHotkey") ? OnStartKeyPressed :
                (key = "ResetHotkey") ? OnResetKeyPressed :
                    (key = "SkipHotkey") ? OnSkipKeyPress :
                        (key = "UndoHotkey") ? OnUndoKeyPressed : Capture
            try Hotkey("$" newKey, callback, "On")
        }
    }

    ; For First Input Keys
    for item in FirstInputKeys {
        key := item[1]
        oldFI := settings["FI_" key]
        newFI := fiCtrls[key].Value ? "1" : "0"

        ; Turn off old registration
        if (oldFI == "1") {
            try Hotkey("~$" . key, "Off")
            try Hotkey("~+$" . key, "Off")
        }

        settings["FI_" key] := newFI

        ; Turn on new registration
        if (newFI == "1") {
            try Hotkey("~$" . key, (*) => OnFirstInputKeyPressed(), "On")
            try Hotkey("~+$" . key, (*) => OnFirstInputKeyPressed(), "On")
        }
    }

    SaveSettings()
    CloseSettingsWindow()
}
