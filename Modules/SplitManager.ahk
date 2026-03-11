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

global lblSplitName := SplitManagerGui.Add("Text", "x10 y435 w100 Hidden", "Name:")
global edSplitName := SplitManagerGui.Add("Edit", "x10 y450 w120 Hidden", "")

global lblSplitImage := SplitManagerGui.Add("Text", "x140 y435 w100 Hidden", "Image:")
global ddlSplitImage := SplitManagerGui.Add("DropDownList", "x140 y450 w120 Choose1 Hidden", imgChoices)

global chkSplitDummy := SplitManagerGui.Add("CheckBox", "x275 y450 w60 Hidden", "Dummy")

global lblSplitThresh := SplitManagerGui.Add("Text", "x345 y435 w60 Hidden", "Threshold:")
global edSplitThresh := SplitManagerGui.Add("Edit", "x345 y450 w60 Hidden", "0.95")

global lblSplitDelay := SplitManagerGui.Add("Text", "x415 y435 w60 Hidden", "Delay:")
global edSplitDelay := SplitManagerGui.Add("Edit", "x415 y450 w60 Hidden", "0")

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

OpenSplitManager(*) {
    global SplitManagerGui, MainGui, lvSplits, ddlSplitImage, SelectedFile
    ; ==========================================================
    ; NEW: Stop and reset the current run immediately!
    ; (If your function is named BtnResetClick, for example, change it here)
    ; ==========================================================
    try OnResetButtonClick()

    CheckForDeletedImages()

    MainGui.Opt("+Disabled")

    ; 1. Fill dropdown list with fresh images
    frischeBilder := ["None", "Boss Death", "Boss Healthbar"]
    infoPfad := A_ScriptDir "\Split_Images\image_info.txt"

    if FileExist(infoPfad) {
        infoText := FileRead(infoPfad)
        loop parse, infoText, "&" {
            if (A_LoopField == "")
                continue
            bildName := StrSplit(A_LoopField, ",")[1]
            frischeBilder.Push(bildName)
        }
    }

    ; Clear old dropdown and fill with the new list
    ddlSplitImage.Delete()
    ddlSplitImage.Add(frischeBilder)

    ; 2. Clear the ListView (the table) and fill with splits
    lvSplits.Delete()

    if (SelectedFile != "" && FileExist(SelectedFile)) {
        splitText := FileRead(SelectedFile)
        loop parse, splitText, "&" {
            if (A_LoopField == "")
                continue

            zeilenDaten := StrSplit(A_LoopField, ",")
            ; If row is valid (Name, Image, Dummy, Thresh, Delay)
            if (zeilenDaten.Length >= 5) {
                lvSplits.Add("", zeilenDaten[1], zeilenDaten[2], zeilenDaten[3], zeilenDaten[4], zeilenDaten[5])
            }
        }
    }
    ; NEW: Ensure fields are collapsed and window shrinks
    ToggleEditArea(false)

    ; Show GUI
    SplitManagerGui.Show()
}

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

    if (SelectedFile != "") {
        try FileDelete(SelectedFile)
        FileAppend(outputString, SelectedFile)

        LoadSplitsFile(SelectedFile)
    }

    SplitManagerGui.Hide()
    SplitManagerGui.Opt("-Disabled")
    MainGui.Opt("-Disabled")
    MainGui.Show()
}

OnSaveSplitButtonClick(*) {
    name := edSplitName.Value
    if (name == "") {
        MsgBox("Please give the split a name!")
        return
    }

    image := ddlSplitImage.Text
    dummy := chkSplitDummy.Value ? "1" : "0"
    thresh := edSplitThresh.Value
    delay := edSplitDelay.Value

    if (splitEditMode == "Edit") {
        row := lvSplits.GetNext(0)
        if (row > 0)
            lvSplits.Modify(row, "", name, image, dummy, thresh, delay)
    } else if (splitEditMode == "Add") {
        lvSplits.Add("", name, image, dummy, thresh, delay)
    }

    ToggleEditArea(false)
}

OnSaveAsNewSplitButtonClick(*) {
    name := edSplitName.Value
    if (name == "") {
        MsgBox("Please give the split a name!")
        return
    }

    image := ddlSplitImage.Text
    dummy := chkSplitDummy.Value ? "1" : "0"
    thresh := edSplitThresh.Value
    delay := edSplitDelay.Value

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

    c1 := lvSplits.GetText(row, 1)
    c2 := lvSplits.GetText(row, 2)
    c3 := lvSplits.GetText(row, 3)
    c4 := lvSplits.GetText(row, 4)
    c5 := lvSplits.GetText(row, 5)

    p1 := lvSplits.GetText(row - 1, 1)
    p2 := lvSplits.GetText(row - 1, 2)
    p3 := lvSplits.GetText(row - 1, 3)
    p4 := lvSplits.GetText(row - 1, 4)
    p5 := lvSplits.GetText(row - 1, 5)

    lvSplits.Modify(row - 1, "", c1, c2, c3, c4, c5)
    lvSplits.Modify(row, "", p1, p2, p3, p4, p5)

    lvSplits.Modify(row - 1, "Select Focus")
    lvSplits.Modify(row, "-Select -Focus")
}

OnDownButtonClick(*) {
    row := lvSplits.GetNext(0)
    if (row == 0 || row == lvSplits.GetCount())
        return

    c1 := lvSplits.GetText(row, 1)
    c2 := lvSplits.GetText(row, 2)
    c3 := lvSplits.GetText(row, 3)
    c4 := lvSplits.GetText(row, 4)
    c5 := lvSplits.GetText(row, 5)

    n1 := lvSplits.GetText(row + 1, 1)
    n2 := lvSplits.GetText(row + 1, 2)
    n3 := lvSplits.GetText(row + 1, 3)
    n4 := lvSplits.GetText(row + 1, 4)
    n5 := lvSplits.GetText(row + 1, 5)

    lvSplits.Modify(row + 1, "", c1, c2, c3, c4, c5)
    lvSplits.Modify(row, "", n1, n2, n3, n4, n5)

    lvSplits.Modify(row + 1, "Select Focus")
    lvSplits.Modify(row, "-Select -Focus")
}

ToggleEditArea(show, mode := "") {
    global splitEditMode := mode

    ; 1. Show or hide input fields
    lblSplitName.Visible := show, edSplitName.Visible := show
    lblSplitImage.Visible := show, ddlSplitImage.Visible := show
    chkSplitDummy.Visible := show, lblSplitThresh.Visible := show
    edSplitThresh.Visible := show, lblSplitDelay.Visible := show, edSplitDelay.Visible := show

    ; 2. Save and Cancel are ALWAYS there when fields are visible
    btnSaveEdit.Visible := show
    btnCancelEdit.Visible := show

    ; 3. Show edit buttons (Save As New, Delete, Up, Down) only in "Edit" mode
    showEditButtons := (show && mode == "Edit")
    btnSaveAsNew.Visible := showEditButtons
    btnDeleteEdit.Visible := showEditButtons
    btnUpEdit.Visible := showEditButtons
    btnDownEdit.Visible := showEditButtons

    ; 4. If hiding or creating a NEW split, clear fields
    if (!show || mode == "Add") {
        edSplitName.Value := ""
        try ddlSplitImage.Choose("None")
        chkSplitDummy.Value := 0
        edSplitThresh.Value := "0.95"
        edSplitDelay.Value := "0"

        ; Clear selection in ListView
        if (mode != "Edit")
            lvSplits.Modify(0, "-Select -Focus")
    }

    SplitManagerGui.Show("AutoSize")
}

CheckForDeletedImages() {
    try {
        imageInfoString := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
    } catch {
        return
    }

    imageDataArray := StrSplit(imageInfoString, "&")
    newInfoString := ""

    i := 1
    ; While loop is safer as we might delete elements from the array
    while (i <= imageDataArray.Length) {
        existingImageData := imageDataArray[i]

        if (i == 1) {
            newInfoString := existingImageData
        } else if (i <= 3) {
            newInfoString .= "&" existingImageData
        } else {
            temporaryArray := StrSplit(existingImageData, ",")
            temporaryImageName := temporaryArray[1]
            temporaryFilePath := A_ScriptDir "\Split_Images\" temporaryImageName ".png"

            if (!FileExist(temporaryFilePath)) {
                ; If image was physically deleted, remove from array
                imageDataArray.RemoveAt(i)
                continue ; We don't increment 'i' as the next element has moved up
            } else {
                newInfoString .= "&" existingImageData
            }
        }
        i++
    }

    ; Save updated list
    try FileDelete(A_ScriptDir "\Split_Images\image_info.txt")
    FileAppend(newInfoString, A_ScriptDir "\Split_Images\image_info.txt")
}
