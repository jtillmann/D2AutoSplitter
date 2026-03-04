#Requires AutoHotkey v2.0

class SplitManager {
    Index := 0
    IsOpen := 0
    Gui := unset

    ; Control Arrays (populated by layout engine)
    ctrlNames := []
    ctrlImages := []
    ctrlDummies := []
    ctrlThresholds := []
    ctrlDelays := []

    __New() {
        this.Gui := Gui("", "Split Manager")
        this.Gui.SetFont("s9", "Segoe UI")

        ; 1. Add static header/footer controls
        for item in Layouts.SplitManager {
            ctrl := this.Gui.Add(item.Type, item.Opt, item.HasProp("Text") ? item.Text : "")
            if item.HasProp("Event")
                ctrl.OnEvent("Click", this.%item.Event%.Bind(this))
        }

        ; 2. Add dynamic rows using the template
        loop 50 {
            offset := A_Index * 30
            rowItems := Layouts.SplitManagerRow(A_Index, offset)
            for item in rowItems {
                ctrl := this.Gui.Add(item.Type, item.Opt, item.HasProp("Text") ? item.Text : "")

                ; For row controls, we store them in arrays
                if item.HasProp("Ref") {
                    this.%item.Ref%.Push(ctrl)
                }

                ctrl.Visible := false
            }
        }

        this.Add(1)
    }

    Open(*) {
        global EngineMgr, MainMgr, Autosplitter
        Autosplitter.Opt("+Disabled")
        this.Clear()

        MainMgr.CheckForDeletedImages()

        infoStr := ""
        try infoStr := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
        infoArr := StrSplit(infoStr, "&")

        choices := ["None", "Boss Healthbar", "Boss Death"]
        loop infoArr.Length - 3 {
            row := StrSplit(infoArr[A_Index + 3], ",")
            if (row.Length >= 1)
                choices.Push(row[1])
        }

        for ctrl in this.ctrlImages {
            ctrl.Delete()
            ctrl.Add(choices)
        }

        this.Gui.Show("Center")
        this.IsOpen := 1

        dataStr := ""
        if (EngineMgr.selectedFile != "")
            try dataStr := FileRead(EngineMgr.selectedFile)

        dataArr := StrSplit(dataStr, "&")
        for row in dataArr {
            if (row == "")
                continue
            rowArr := StrSplit(row, ",")
            if (rowArr.Length >= 5) {
                this.Add(this.Index, rowArr[1], rowArr[2], rowArr[3], rowArr[4],
                    rowArr[5])
            }
        }

        WinWaitClose("Split Manager")
        this.IsOpen := 0
        Autosplitter.Opt("-Disabled")
        Autosplitter.Show()
    }

    LoadFile(selFile) {
        global EngineMgr, MainMgr
        dataStr := ""
        if (selFile != "")
            try dataStr := FileRead(selFile)

        EngineMgr.loadedSplits := StrSplit(dataStr, "&")
        fileName := ""
        SplitPath(selFile, &fileName)

        MainMgr.ctrlEditSplitsBtn.Visible := true
        MainMgr.ctrlSplitFile.Value := fileName
    }

    SaveAndClose(*) {
        global EngineMgr, Autosplitter
        this.Gui.Opt("+Disabled")

        dataStr := ""
        loop this.Index {
            name := this.ctrlNames[A_Index].Value
            img := this.ctrlImages[A_Index].Value
            dummy := this.ctrlDummies[A_Index].Value
            thresh := this.ctrlThresholds[A_Index].Value
            delay := this.ctrlDelays[A_Index].Value

            row := name "," img "," dummy "," thresh "," delay
            if (A_Index > 1)
                dataStr .= "&" row
            else
                dataStr := row
        }

        if FileExist(EngineMgr.selectedFile)
            FileDelete EngineMgr.selectedFile
        FileAppend dataStr, EngineMgr.selectedFile
        this.LoadFile(EngineMgr.selectedFile)

        this.Gui.Hide()
        this.Gui.Opt("-Disabled")
        Autosplitter.Opt("-Disabled")
        Autosplitter.Show()
    }

    Clear() {
        loop this.Index {
            this.Remove(this.Index)
        }
        this.Add(1)
    }

    Remove(idx) {
        this.ctrlNames[this.Index].Visible := false
        this.ctrlImages[this.Index].Visible := false
        this.ctrlDummies[this.Index].Visible := false
        this.ctrlThresholds[this.Index].Visible := false
        this.ctrlDelays[this.Index].Visible := false

        diff := this.Index - idx
        loop diff {
            curr := idx + A_Index
            prev := idx + A_Index - 1

            this.ctrlNames[prev].Value := this.ctrlNames[curr].Value
            this.ctrlImages[prev].Value := this.ctrlImages[curr].Value
            this.ctrlDummies[prev].Value := this.ctrlDummies[curr].Value
            this.ctrlThresholds[prev].Value := this.ctrlThresholds[curr].Value
            this.ctrlDelays[prev].Value := this.ctrlDelays[curr].Value
        }

        this.ctrlNames[this.Index].Value := ""
        this.ctrlImages[this.Index].Value := "None"
        this.ctrlDummies[this.Index].Value := 0
        this.ctrlThresholds[this.Index].Value := "0.90"
        this.ctrlDelays[this.Index].Value := "7"

        this.Index -= 1
        this.UpdateGuiSize()
    }

    Add(idx, name := "", image := "None", dummy := 0, thresh := 0.90, delay := 7) {
        this.Index += 1

        this.ctrlNames[this.Index].Visible := true
        this.ctrlImages[this.Index].Visible := true
        this.ctrlDummies[this.Index].Visible := true
        this.ctrlThresholds[this.Index].Visible := true
        this.ctrlDelays[this.Index].Visible := true

        diff := this.Index - idx
        loop diff {
            curr := this.Index - A_Index + 1
            prev := this.Index - A_Index

            this.ctrlNames[curr].Value := this.ctrlNames[prev].Value
            this.ctrlImages[curr].Value := this.ctrlImages[prev].Value
            this.ctrlDummies[curr].Value := this.ctrlDummies[prev].Value
            this.ctrlThresholds[curr].Value := this.ctrlThresholds[prev].Value
            this.ctrlDelays[curr].Value := this.ctrlDelays[prev].Value
        }

        this.ctrlNames[idx].Value := name
        this.ctrlImages[idx].Value := image
        this.ctrlDummies[idx].Value := dummy
        this.ctrlThresholds[idx].Value := Round(thresh, 2)
        this.ctrlDelays[idx].Value := delay

        this.UpdateGuiSize()
    }

    UpdateGuiSize() {
        if (this.IsOpen) {
            offset := this.Index * 30
            if (this.Index > 5)
                this.Gui.Show("h" (90 + offset))
            else
                this.Gui.Show()
        }
    }

    OnRemoveButtonClick(*) {
        this.Gui.Opt("+Disabled")
        ib := InputBox("Which split would you like to remove`n(Leave the input blank to remove the final split)",
            "Remove Split")
        if (ib.Result == "OK") {
            val := ib.Value
            if (val != "" && IsNumber(val) && Integer(val) <= this.Index)
                this.Remove(Integer(val))
            else
                this.Remove(this.Index)
        }
        this.Gui.Opt("-Disabled")
        this.Gui.Show()
    }

    OnAddButtonClick(*) {
        this.Gui.Opt("+Disabled")
        ib := InputBox(
            "Where would you like to insert a new split`nSplits at or below that position will be shifted down`n(Leave the input blank to add one at the end)",
            "Add Split")
        if (ib.Result == "OK") {
            val := ib.Value
            if (val != "" && IsNumber(val) && Integer(val) <= this.Index)
                this.Add(Integer(val))
            else
                this.Add(this.Index + 1)
        }
        this.Gui.Opt("-Disabled")
        this.Gui.Show()
    }
}
