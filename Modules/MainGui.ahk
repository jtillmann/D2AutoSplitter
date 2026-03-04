#Requires AutoHotkey v2.0

class MainGui {
    Gui := unset

    ; Control References (populated by layout engine)
    ctrlHk1 := unset
    ctrlHk2 := unset
    ctrlHk3 := unset
    ctrlHk4 := unset
    ctrlSplitFile := unset
    ctrlEditSplitsBtn := unset
    ctrlTimerText := unset
    ctrlCurrImg := unset
    ctrlStartBtn := unset
    ctrlWaitInput := unset
    ctrlWaitInputTitle := unset
    ctrlPrev := unset
    ctrlCurr := unset
    ctrlSplitImgName := unset
    ctrlNext := unset
    ctrlLoopCount := unset
    ctrlPMatch := unset
    ctrlPWhite := unset
    ctrlPBlack := unset

    __New() {
        this.Gui := Gui("-Resize", "Destiny 2 AutoSplitter")
        this.Gui.SetFont("s9", "Segoe UI")
        this.Gui.OnEvent("Close", this.OnClose.Bind(this))

        ; Build GUI from declarative layout
        for item in Layouts.Main {
            text := item.HasProp("Text") ? item.Text : ""
            if (item.Type == "Picture" && !InStr(text, "\")) {
                text := A_ScriptDir "\" text
            }

            ctrl := this.Gui.Add(item.Type, item.Opt, text)

            if item.HasProp("Ref")
                this.%item.Ref% := ctrl

            if item.HasProp("Event")
                ctrl.OnEvent(ctrl.Type == "Edit" || ctrl.Type == "Hotkey" ? "Change" : "Click",
                    this.%item.Event%.Bind(this))

            if item.HasProp("Font")
                ctrl.SetFont(item.Font)
        }

        ; Initial setup for hotkey controls
        global EngineMgr
        this.ctrlHk1.Value := EngineMgr.hkSettings.Length >= 1 ? EngineMgr.hkSettings[1] : ""
        this.ctrlHk2.Value := EngineMgr.hkSettings.Length >= 2 ? EngineMgr.hkSettings[2] : ""
        this.ctrlHk3.Value := EngineMgr.hkSettings.Length >= 3 ? EngineMgr.hkSettings[3] : ""
        this.ctrlHk4.Value := EngineMgr.hkSettings.Length >= 4 ? EngineMgr.hkSettings[4] : ""
    }

    Show() => this.Gui.Show()

    OnClose(*) {
        global pToken
        if IsSet(pToken)
            Gdip_Shutdown(pToken)
        ExitApp()
    }

    SetHotkeys(*) {
        global EngineMgr, ImgMaker

        h1 := this.ctrlHk1.Value
        h2 := this.ctrlHk2.Value
        h3 := this.ctrlHk3.Value
        h4 := this.ctrlHk4.Value
        ch := ImgMaker.ctrlHkCapture.Value

        if (h1 != "") {
            if (EngineMgr.hkSettings.Length >= 1 && EngineMgr.hkSettings[1] != "")
                try Hotkey(EngineMgr.hkSettings[1], "Off")
            EngineMgr.hkSettings[1] := h1
            EngineMgr.splitBtn := h1
            try Hotkey("$" h1, EngineMgr.StartKeyPressed.Bind(EngineMgr))
        }
        if (h2 != "") {
            if (EngineMgr.hkSettings.Length >= 2 && EngineMgr.hkSettings[2] != "")
                try Hotkey(EngineMgr.hkSettings[2], "Off")
            EngineMgr.hkSettings[2] := h2
            EngineMgr.resetBtn := h2
            try Hotkey("$" h2, EngineMgr.ResetAutoSplitter.Bind(EngineMgr))
        }
        if (h3 != "") {
            if (EngineMgr.hkSettings.Length >= 3 && EngineMgr.hkSettings[3] != "")
                try Hotkey(EngineMgr.hkSettings[3], "Off")
            EngineMgr.hkSettings[3] := h3
            EngineMgr.skipBtn := h3
            try Hotkey("$" h3, EngineMgr.SkipOnlyAutoSplitter.Bind(EngineMgr))
        }
        if (h4 != "") {
            if (EngineMgr.hkSettings.Length >= 4 && EngineMgr.hkSettings[4] != "")
                try Hotkey(EngineMgr.hkSettings[4], "Off")
            EngineMgr.hkSettings[4] := h4
            EngineMgr.undoBtn := h4
            try Hotkey("$" h4, EngineMgr.UndoOnlyAutoSplitter.Bind(EngineMgr))
        }
        if (ch != "") {
            if (EngineMgr.hkSettings.Length >= 5 && EngineMgr.hkSettings[5] != "")
                try Hotkey(EngineMgr.hkSettings[5], "Off")
            EngineMgr.hkSettings[5] := ch
            try Hotkey("$" ch, ImgMaker.Capture.Bind(ImgMaker))
        }

        hkStr := h1 "&" h2 "&" h3 "&" h4 "&" ch
        if FileExist(A_ScriptDir "\Dependencies\settings.txt")
            FileDelete A_ScriptDir "\Dependencies\settings.txt"
        FileAppend hkStr, A_ScriptDir "\Dependencies\settings.txt"

        MsgBox "Hotkeys updated"
    }

    OnStartAutoSplitter(*) {
        global EngineMgr
        EngineMgr.waitInput := this.ctrlWaitInput.Value
        EngineMgr.StartAutoSplitter()
    }

    OnStopEngine(*) => EngineMgr.ResetAutoSplitter()
    OnSkipSplit(*) => EngineMgr.SkipOnlyAutoSplitter()
    OnUndoSplit(*) => EngineMgr.UndoOnlyAutoSplitter()
    OnEditSplits(*) {
        global SplitMgr
        SplitMgr.Open()
    }
    OnCreateSplitImage(*) {
        global ImgMaker
        ImgMaker.Open()
    }

    OnSaveSplitFileEmpty(*) {
        global EngineMgr, SplitMgr
        this.Gui.Opt("+Disabled")

        loop {
            ib := InputBox("What would you like to name your Splits?", "New Splits")
            if (ib.Result == "Cancel")
                break

            fileName := ib.Value ".txt"
            EngineMgr.selectedFile := A_WorkingDir "\Split_Files\" fileName
            if (FileExist(EngineMgr.selectedFile)) {
                if (MsgBox("A split file with this name already exists.`nWould you like to overwrite it?", "Overwrite?",
                    "YesNo") == "No")
                    continue
            }
            content := "None,None,0,0.9,7"
            if FileExist(EngineMgr.selectedFile)
                FileDelete EngineMgr.selectedFile
            FileAppend content, EngineMgr.selectedFile
            SplitMgr.LoadFile(EngineMgr.selectedFile)
            break
        }
        this.Gui.Opt("-Disabled")
        this.Gui.Show()
    }

    OnLoadSplitsToUse(*) {
        global EngineMgr, SplitMgr
        this.Gui.Opt("+Disabled")
        selFile := FileSelect(3, A_WorkingDir "\Split_Files\", "Open a file", "Text Documents (*.txt; *.doc)")
        if (selFile != "") {
            EngineMgr.selectedFile := selFile
            SplitMgr.LoadFile(selFile)
        }

        this.Gui.Opt("-Disabled")
        this.Gui.Show()
    }

    CheckForDeletedImages() {
        infoStr := ""
        try infoStr := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
        if (infoStr == "") {
            return
        }
        infoArr := StrSplit(infoStr, "&")

        newArr := []
        loop infoArr.Length {
            row := infoArr[A_Index]
            if (A_Index <= 3) {
                newArr.Push(row)
            } else {
                rowArr := StrSplit(row, ",")
                if (rowArr.Length >= 1) {
                    name := rowArr[1]
                    if FileExist(A_ScriptDir "\Split_Images\" name ".png") {
                        newArr.Push(row)
                    }
                }
            }
        }

        newStr := ""
        for idx, val in newArr {
            newStr .= (idx == 1 ? "" : "&") val
        }

        if FileExist(A_ScriptDir "\Split_Images\image_info.txt")
            FileDelete A_ScriptDir "\Split_Images\image_info.txt"
        FileAppend newStr, A_ScriptDir "\Split_Images\image_info.txt"

        global EngineMgr
        EngineMgr.InitializeCache()
    }

    UpdateGui() {
        global EngineMgr
        splits := EngineMgr.loadedSplits
        idx := EngineMgr.splitIndex

        prev := "", curr := "", next := ""

        if (idx > 1 && idx - 1 <= splits.Length) {
            row := StrSplit(splits[idx - 1], ",")
            if (row.Length >= 1)
                prev := row[1]
        }

        if (idx >= 1 && idx <= splits.Length) {
            row := StrSplit(splits[idx], ",")
            if (row.Length >= 1)
                curr := row[1]
        }

        if (idx + 1 >= 1 && idx + 1 <= splits.Length) {
            row := StrSplit(splits[idx + 1], ",")
            if (row.Length >= 1)
                next := row[1]
        }

        this.ctrlPrev.Value := prev
        this.ctrlCurr.Value := curr
        this.ctrlNext.Value := next
    }
}
