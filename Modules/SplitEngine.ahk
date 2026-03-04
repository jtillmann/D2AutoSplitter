#Requires AutoHotkey v2.0

class SplitEngine {
    ; Core State
    selectedFile := ""
    currSplit := ""
    loadedSplits := []
    splitIndex := 999
    breakLoop := 0
    bossHpIdx := 0
    isWaiting := 0
    timerMs := 0
    nLoops := 0
    findMethod := ""
    matchThreshold := 0
    isDoubleCheck := 0
    splitImgInfo := ""
    isLoopEnded := 0
    percMatch := 0
    percWhite := 0
    percBlack := 0
    dpiRatio := A_ScreenDPI / 96
    waitInput := 0

    ; Performance Caches
    imgDataMap := Map()        ; name -> [name, coords, pixelArr]
    pixelCache := Map()        ; imageName -> pixelArr
    hpCoords := "0|0|1|1"      ; Cached Boss HP coordinates

    ; HP Bar Colors
    hpDarkColor := ""
    hpLightColor := ""
    bossHealthMap := Map()

    ; Settings & Hotkeys
    hkSettings := []
    splitBtn := ""
    resetBtn := ""
    skipBtn := ""
    undoBtn := ""

    __New() {
        this.InitializeSettings()
        this.InitializeCache()
    }

    InitializeSettings() {
        hkStr := ""
        if FileExist(A_ScriptDir "\Dependencies\settings.txt")
            hkStr := FileRead(A_ScriptDir "\Dependencies\settings.txt")
        this.hkSettings := StrSplit(hkStr, "&")

        while (this.hkSettings.Length < 5)
            this.hkSettings.Push("")

        this.splitBtn := this.hkSettings[1]
        this.resetBtn := this.hkSettings[2]
        this.skipBtn := this.hkSettings[3]
        this.undoBtn := this.hkSettings[4]
    }

    InitializeCache() {
        infoStr := ""
        try infoStr := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
        infoArr := StrSplit(infoStr, "&")

        ; Reset caches
        this.imgDataMap := Map()

        ; HP Bar Colors (Index 1 & 2)
        this.hpDarkColor := (infoArr.Length >= 1) ? infoArr[1] : ""
        this.hpLightColor := (infoArr.Length >= 2) ? infoArr[2] : ""
        if (this.hpDarkColor != "" && this.hpLightColor != "")
            this.bossHealthMap := FindAllColorsBetween(this.hpDarkColor, this.hpLightColor)

        ; HP Bar Coords (Index 3)
        this.hpCoords := (infoArr.Length >= 3) ? infoArr[3] : "0|0|1|1"

        ; Image Data (Index 4+)
        loop infoArr.Length - 3 {
            idx := A_Index + 3
            data := StrSplit(infoArr[idx], ",")
            if (data.Length >= 1) {
                this.imgDataMap[data[1]] := data
            }
        }
    }

    ; --- Engine Logic ---

    InputKeyPressed(*) {
        activeWin := WinGetTitle("A")
        if (this.waitInput && this.splitIndex == 999 && activeWin == "Destiny 2") {
            if (this.splitBtn != "")
                Send "{" this.splitBtn "}"
            this.StartAutoSplitter()
        }
    }

    StartKeyPressed(*) {
        if (this.splitBtn != "")
            Send "{" this.splitBtn "}"
    }

    StartAutoSplitter(*) {
        global MainMgr
        if (this.loadedSplits.Length < 1 || this.loadedSplits[1] == "") {
            MsgBox "Select a split file first please"
            return
        }

        ; Ensure cache is fresh before starting
        this.InitializeCache()
        this.pixelCache := Map() ; Reset pixel cache for the run

        this.splitIndex := 1
        MainMgr.UpdateGui()
        MainMgr.ctrlWaitInput.Visible := false
        MainMgr.ctrlWaitInputTitle.Visible := false

        this.breakLoop := 0
        this.nLoops := 0
        SetTimer this.CountLoops.Bind(this), 1000

        if (this.splitBtn != "") {
            try Hotkey(this.splitBtn, "Off")
        }

        loop {
            if this.breakLoop
                break

            MainMgr.ctrlTimerText.Value := ""
            prevWasBossDeath := 0
            this.currSplit := StrSplit(this.loadedSplits[this.splitIndex], ",")
            if (this.splitIndex > 1) {
                prevSplit := StrSplit(this.loadedSplits[this.splitIndex - 1], ",")
                if (prevSplit.Length >= 2 && prevSplit[2] == "Boss Death")
                    prevWasBossDeath := 1
            }
            currImgName := (this.currSplit.Length >= 2) ? this.currSplit[2] : ""

            ; Update UI Image
            MainMgr.ctrlCurrImg.Value := ""
            imgPath := A_ScriptDir "\Split_Images\" currImgName ".png"
            if FileExist(imgPath) {
                MainMgr.ctrlCurrImg.Value := imgPath
            }
            MainMgr.ctrlCurrImg.Move(10, 70, 300, 300)
            MainMgr.ctrlSplitImgName.Value := currImgName

            ; Get Image Metadata from Cache (No Disk I/O)
            if (!this.imgDataMap.Has(currImgName) && currImgName != "Boss Death" && currImgName != "Boss Healthbar") {
                if (currImgName == "None") {
                    MsgBox "no image selected for split " this.splitIndex
                    this.StopOnlyAutoSplitter()
                    return
                }
            }

            this.splitImgInfo := this.imgDataMap.Has(currImgName) ? this.imgDataMap[currImgName] : [currImgName,
                "0|0|1|1"]

            ; Determine find method
            if (currImgName == "Boss Death") {
                this.findMethod := "findBossDeath"
                this.splitImgInfo := ["Boss Death", this.hpCoords, []]
                MainMgr.ctrlCurrImg.Value := ""
            } else if (currImgName == "Boss Healthbar") {
                this.findMethod := "findBossThere"
                this.splitImgInfo := ["Boss Healthbar", this.hpCoords, []]
                MainMgr.ctrlCurrImg.Value := ""
            } else {
                this.findMethod := "findNormal"
                ; Lazy-load pixel array into memory cache (Only reads from disk ONCE per unique image per run)
                if (!this.pixelCache.Has(currImgName)) {
                    pixelStr := MakePixelArrayString(currImgName)
                    this.pixelCache[currImgName] := StrSplit(pixelStr, ",")
                }
                this.splitImgInfo[3] := this.pixelCache[currImgName]
            }

            this.LookingFor(this.findMethod, this.currSplit[4], prevWasBossDeath, this.splitImgInfo)

            if (this.splitIndex > this.loadedSplits.Length || this.splitIndex < 1) {
                break
            }
        }

        if (this.splitBtn != "") {
            try Hotkey(this.splitBtn, "On")
        }
        this.StopOnlyAutoSplitter()
    }

    DoLoop(*) {
        if (this.breakLoop) {
            this.isLoopEnded := 1
            SetTimer this.DoLoop.Bind(this), 0
            SetTimer this.UpdateStats.Bind(this), 0
            this.UpdateStats()
            return
        }

        res := { raw: 0, match: 0, white: 0, black: 0 }
        if (this.findMethod == "findNormal")
            res := this.FindNormal(this.splitImgInfo)
        else if (this.findMethod == "findBossDeath")
            res := { raw: this.FindBossDeath(this.splitImgInfo) }
        else if (this.findMethod == "findBossThere")
            res := { raw: this.FindBossThere(this.splitImgInfo) }

        if (res.raw >= this.matchThreshold) {
            this.isLoopEnded := 1
            this.breakLoop := 1
            SetTimer this.DoLoop.Bind(this), 0
            SetTimer this.UpdateStats.Bind(this), 0

            ; Update stats one last time with final result
            this.percMatch := res.match ?? 0
            this.percWhite := res.white ?? 0
            this.percBlack := res.black ?? 0
            this.UpdateStats()

            this.HandleSplit(res.raw)
        }

        if (this.isDoubleCheck) {
            rawThere := this.FindBossThere(1)
            if (this.bossHpIdx >= 60) {
                this.isLoopEnded := 1
                this.bossHpIdx := 0
                this.breakLoop := 1
                SetTimer this.DoLoop.Bind(this), 0
                SetTimer this.UpdateStats.Bind(this), 0
                this.UndoSplit()
            }
        }
        this.nLoops += 1
    }

    LookingFor(method, thresh, dCheck, info) {
        global MainMgr
        this.breakLoop := 0
        this.isLoopEnded := 0
        Sleep 500
        this.findMethod := method
        this.matchThreshold := thresh
        this.isDoubleCheck := dCheck
        this.splitImgInfo := info
        MainMgr.UpdateGui()

        boundLoop := this.DoLoop.Bind(this)
        boundStats := this.UpdateStats.Bind(this)

        SetTimer boundLoop, 10
        SetTimer boundStats, 50
        loop {
            if (this.isLoopEnded)
                break
            Sleep 10
        }
    }

    HandleSplit(pCorrect) {
        if (!(this.currSplit.Length >= 3 && this.currSplit[3])) {
            if (this.splitBtn != "")
                Send "{" this.splitBtn "}"
        }

        this.timerMs := (this.currSplit.Length >= 5 ? this.currSplit[5] : 0) * 1000
        if (this.currSplit.Length >= 2 && this.currSplit[2] == "Boss Death")
            this.timerMs := 0
        this.splitIndex += 1
        this.isWaiting := 1
        this.breakLoop := 0

        boundTimer := this.WaitForNextSplit.Bind(this)
        SetTimer boundTimer, 100
        loop {
            if (!this.isWaiting)
                break
            Sleep 10
        }
        SetTimer boundTimer, 0
    }

    WaitForNextSplit(*) {
        global MainMgr
        if (this.breakLoop) {
            this.timerMs := 0
        }
        this.timerMs -= 100
        timeLeft := Round((this.timerMs / 1000), 1)
        MainMgr.ctrlTimerText.Value := timeLeft
        if (this.timerMs <= 0)
            this.isWaiting := 0
    }

    FindNormal(info) {
        if (info.Length < 3)
            return { raw: 0, match: 0, white: 0, black: 0 }

        pBmp := Gdip_BitmapFromScreen(info[2])
        res := ColorCheck(pBmp, info[3])

        this.percMatch := res.match
        this.percWhite := res.white
        this.percBlack := res.black

        Gdip_DisposeImage(pBmp)
        return res
    }

    FindBossDeath(info) {
        pBmp := Gdip_BitmapFromScreen(this.hpCoords)
        isDead := BossHPCheck(pBmp, 40, 10, this.bossHealthMap)

        if (!isDead) {
            this.bossHpIdx := 0
        } else {
            this.bossHpIdx += 1
        }

        res := round((this.bossHpIdx / 4), 2)
        Gdip_DisposeImage(pBmp)
        return res
    }

    FindBossThere(oneDigit := 0) {
        pBmp := Gdip_BitmapFromScreen(this.hpCoords)
        isThere := BossHPShowingUp(pBmp, 40, 10, this.bossHealthMap)

        if (!isThere) {
            this.bossHpIdx := 0
        } else {
            this.bossHpIdx += 1
        }

        res := round((this.bossHpIdx / 6), 2)
        Gdip_DisposeImage(pBmp)
        return res
    }

    ResetAutoSplitter(*) {
        if (this.resetBtn != "") {
            Send "{" this.resetBtn "}"
        }
        global MainMgr
        MainMgr.ctrlStartBtn.Text := "Start"
        this.StopOnlyAutoSplitter()
    }

    StopOnlyAutoSplitter(*) {
        global MainMgr
        this.breakLoop := 1
        this.isLoopEnded := 1
        this.splitIndex := 999
        this.bossHpIdx := 0
        MainMgr.UpdateGui()
        MainMgr.ctrlSplitImgName.Value := ""
        MainMgr.ctrlCurrImg.Value := ""
        MainMgr.ctrlTimerText.Value := ""
        MainMgr.ctrlWaitInput.Visible := true
        MainMgr.ctrlWaitInputTitle.Visible := true

        this.UpdateStats()
    }

    SkipOnlyAutoSplitter(*) {
        this.breakLoop := 1
        this.isLoopEnded := 1
        this.splitIndex += 1
        global MainMgr
        MainMgr.UpdateGui()
    }

    UndoOnlyAutoSplitter(*) {
        this.breakLoop := 1
        this.isLoopEnded := 1
        this.splitIndex -= 1
        if (this.splitIndex < 1)
            this.splitIndex := 1
        global MainMgr
        MainMgr.UpdateGui()
    }

    CountLoops(*) {
        global MainMgr
        MainMgr.ctrlLoopCount.Value := this.nLoops
        this.nLoops := 0
    }

    UpdateStats(*) {
        global MainMgr
        MainMgr.ctrlPMatch.Value := this.percMatch
        MainMgr.ctrlPWhite.Value := this.percWhite
        MainMgr.ctrlPBlack.Value := this.percBlack
        this.percMatch := 0
        this.percWhite := 0
        this.percBlack := 0
    }
}
