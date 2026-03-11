#Requires AutoHotkey v2.0

global imgChoices := ["None", "Boss Death", "Boss Healthbar"]

global SplitManagerGui := Gui("+AlwaysOnTop", "Split Manager")
SplitManagerGui.OnEvent("Close", OnCloseSplitManager)

global lvSplits := SplitManagerGui.Add("ListView", "x10 y10 w500 h375 -Multi +Grid", ["Split Name", "Image", "Dummy",
    "Threshold", "Delay"])
lvSplits.OnEvent("ItemSelect", OnSplitSelect)

lvSplits.ModifyCol(1, 160)
lvSplits.ModifyCol(2, 145)
lvSplits.ModifyCol(3, 50)
lvSplits.ModifyCol(4, 65)
lvSplits.ModifyCol(5, 60)

global splitEditMode := ""

SplitManagerGui.Add("Button", "x10 y395 w150 h30", "Add New Split").OnEvent("Click", OnAddButtonClick)
SplitManagerGui.Add("Button", "x360 y395 w150 h30", "Save && Close").OnEvent("Click", OnCloseSaveButtonClick)

; 4. Die Eingabefelder (Standardmäßig versteckt! Y-Achsen um +125 nach unten verschoben)
global lblSplitName := SplitManagerGui.Add("Text", "x10 y435 w100 Hidden", "Name:")
global edSplitName := SplitManagerGui.Add("Edit", "x10 y450 w120 Hidden", "")

global lblSplitImage := SplitManagerGui.Add("Text", "x140 y435 w100 Hidden", "Image:")
global ddlSplitImage := SplitManagerGui.Add("DropDownList", "x140 y450 w120 Choose1 Hidden", imgChoices)

global chkSplitDummy := SplitManagerGui.Add("CheckBox", "x275 y450 w60 Hidden", "Dummy")

global lblSplitThresh := SplitManagerGui.Add("Text", "x345 y435 w60 Hidden", "Threshold:")
global edSplitThresh := SplitManagerGui.Add("Edit", "x345 y450 w60 Hidden", "0.95")

global lblSplitDelay := SplitManagerGui.Add("Text", "x415 y435 w60 Hidden", "Delay:")
global edSplitDelay := SplitManagerGui.Add("Edit", "x415 y450 w60 Hidden", "0")

; 5. Die kontextbezogenen Aktions-Buttons (Versteckt! Y-Achse auf 490)
global btnSaveEdit := SplitManagerGui.Add("Button", "x10 y490 w60 h30 Hidden", "Save")
btnSaveEdit.OnEvent("Click", OnSaveSplitButtonClick)

global btnSaveAsNew := SplitManagerGui.Add("Button", "x75 y490 w90 h30 Hidden", "Save As New")
btnSaveAsNew.OnEvent("Click", OnSaveAsNewSplitButtonClick)

global btnDeleteEdit := SplitManagerGui.Add("Button", "x170 y490 w60 h30 Hidden", "Delete")
btnDeleteEdit.OnEvent("Click", OnDeleteSplitButtonClick)

global btnUpEdit := SplitManagerGui.Add("Button", "x235 y490 w40 h30 Hidden", "Up")
btnUpEdit.OnEvent("Click", OnUpButtonClick)

global btnDownEdit := SplitManagerGui.Add("Button", "x280 y490 w50 h30 Hidden", "Down")
btnDownEdit.OnEvent("Click", OnDownButtonClick)

global btnCancelEdit := SplitManagerGui.Add("Button", "x450 y490 w60 h30 Hidden", "Cancel")
btnCancelEdit.OnEvent("Click", OnCancelButtonClick)

OnCloseSplitManager(*) {
    global SplitManagerGui, MainGui

    SplitManagerGui.Hide()

    MainGui.Opt("-Disabled")
    MainGui.Show()
}

OnSplitSelect(GuiCtrlObj, Item, Selected) {
    if (!Selected)
        return

    edSplitName.Value := lvSplits.GetText(Item, 1)
    try ddlSplitImage.Choose(lvSplits.GetText(Item, 2))
    chkSplitDummy.Value := (lvSplits.GetText(Item, 3) == "1") ? 1 : 0
    edSplitThresh.Value := lvSplits.GetText(Item, 4)
    edSplitDelay.Value := lvSplits.GetText(Item, 5)

    ToggleEditArea(true, "Edit")
}

OnAddButtonClick(*) {
    ToggleEditArea(true, "Add")
}

OnCancelButtonClick(*) {
    ToggleEditArea(false)
}

OnCloseSaveButtonClick(*) {
    global SelectedFile, SplitManagerGui, MainGui, lvSplits

    SplitManagerGui.Opt("+Disabled")

    outputString := ""
    rowCount := lvSplits.GetCount()

    ; Das gesamte ListView Zeile für Zeile auslesen
    loop rowCount {
        row := A_Index
        name := lvSplits.GetText(row, 1)
        image := lvSplits.GetText(row, 2)
        dummy := lvSplits.GetText(row, 3)
        thresh := lvSplits.GetText(row, 4)
        delay := lvSplits.GetText(row, 5)

        line := name "," image "," dummy "," thresh "," delay
        outputString .= (A_Index == 1 ? "" : "&") . line
    }

    ; In die Datei schreiben, falls eine ausgewählt ist
    if (SelectedFile != "") {
        try FileDelete(SelectedFile)
        FileAppend(outputString, SelectedFile)

        ; Das Dropdown im Haupt-GUI mit den neuen Splits füttern
        LoadSplitsFile(SelectedFile)
    }

    ; Fenster schließen und Hauptmenü freigeben
    SplitManagerGui.Hide()
    SplitManagerGui.Opt("-Disabled")
    MainGui.Opt("-Disabled")
    MainGui.Show()
}

OnSaveSplitButtonClick(*) {
    name := edSplitName.Value
    if (name == "") {
        MsgBox("Bitte gib dem Split einen Namen!")
        return
    }

    image := ddlSplitImage.Text, dummy := chkSplitDummy.Value ? "1" : "0"
    thresh := edSplitThresh.Value, delay := edSplitDelay.Value

    if (splitEditMode == "Edit") {
        row := lvSplits.GetNext(0)
        if (row > 0)
            lvSplits.Modify(row, "", name, image, dummy, thresh, delay)
    } else if (splitEditMode == "Add") {
        lvSplits.Add("", name, image, dummy, thresh, delay)
    }

    ToggleEditArea(false) ; Versteckt alles nach dem Speichern
}

OnSaveAsNewSplitButtonClick(*) {
    name := edSplitName.Value
    if (name == "") {
        MsgBox("Bitte gib dem Split einen Namen!")
        return
    }

    image := ddlSplitImage.Text, dummy := chkSplitDummy.Value ? "1" : "0"
    thresh := edSplitThresh.Value, delay := edSplitDelay.Value

    row := lvSplits.GetNext(0)
    if (row > 0)
        lvSplits.Insert(row + 1, "", name, image, dummy, thresh, delay)

    ToggleEditArea(false)
}

OnDeleteSplitButtonClick(*) {
    row := lvSplits.GetNext(0)
    if (row > 0)
        lvSplits.Delete(row)

    ToggleEditArea(false)
}

OnUpButtonClick(*) {
    row := lvSplits.GetNext(0)
    if (row <= 1)
        return

    c1 := lvSplits.GetText(row, 1), c2 := lvSplits.GetText(row, 2), c3 := lvSplits.GetText(row, 3), c4 := lvSplits.GetText(
        row, 4), c5 := lvSplits.GetText(row, 5)
    p1 := lvSplits.GetText(row - 1, 1), p2 := lvSplits.GetText(row - 1, 2), p3 := lvSplits.GetText(row - 1, 3), p4 :=
    lvSplits.GetText(row - 1, 4), p5 := lvSplits.GetText(row - 1, 5)

    lvSplits.Modify(row - 1, "", c1, c2, c3, c4, c5)
    lvSplits.Modify(row, "", p1, p2, p3, p4, p5)

    lvSplits.Modify(row - 1, "Select Focus")
    lvSplits.Modify(row, "-Select -Focus")
}

OnDownButtonClick(*) {
    row := lvSplits.GetNext(0)
    if (row == 0 || row == lvSplits.GetCount())
        return

    c1 := lvSplits.GetText(row, 1), c2 := lvSplits.GetText(row, 2), c3 := lvSplits.GetText(row, 3), c4 := lvSplits.GetText(
        row, 4), c5 := lvSplits.GetText(row, 5)
    n1 := lvSplits.GetText(row + 1, 1), n2 := lvSplits.GetText(row + 1, 2), n3 := lvSplits.GetText(row + 1, 3), n4 :=
    lvSplits.GetText(row + 1, 4), n5 := lvSplits.GetText(row + 1, 5)

    lvSplits.Modify(row + 1, "", c1, c2, c3, c4, c5)
    lvSplits.Modify(row, "", n1, n2, n3, n4, n5)

    lvSplits.Modify(row + 1, "Select Focus")
    lvSplits.Modify(row, "-Select -Focus")
}
