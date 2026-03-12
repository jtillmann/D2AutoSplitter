#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines False
ProcessSetPriority "A"
SetWinDelay -1
SetControlDelay -1

#Include %A_ScriptDir%/Gdip_all_v2.ahk
#Include %A_ScriptDir%/Modules/Helpers.ahk
#Include %A_ScriptDir%/Modules/SplitManager.ahk
#Include %A_ScriptDir%/Modules/SettingsWindow.ahk

SetWorkingDir A_ScriptDir
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

global WinTitle := "LiveSplit"

WriteLog(text) {
    if (A_IsCompiled)
        return
    FileAppend(A_NowUTC ": " text "`n", "logfile.txt")
}

; --- Check folders and settings files ---
; In v2, functions like DirExist() and DirCreate() are used
if !DirExist(A_ScriptDir "\Dependencies") {
    DirCreate(A_ScriptDir "\Dependencies")
    FileAppend("", A_ScriptDir "\Dependencies\settings.txt")
}

if !DirExist(A_ScriptDir "\Split_Files") {
    DirCreate(A_ScriptDir "\Split_Files")
}

if !DirExist(A_ScriptDir "\Split_Images") {
    DirCreate(A_ScriptDir "\Split_Images")
    FileAppend("0x000000&0x000000&0|0|1|1", A_ScriptDir "\Split_Images\image_info.txt")
}

global settingsFile := A_ScriptDir "\Dependencies\settings.ini"
global legacySettingsFile := A_ScriptDir "\Dependencies\settings.txt"
global settings := Map()

; --- Migration from legacy txt to ini ---
if (FileExist(legacySettingsFile) && !FileExist(settingsFile)) {
    try {
        legacyContent := FileRead(legacySettingsFile)
        legacyArray := StrSplit(legacyContent, "&")

        ; Map legacy indices to named keys
        IniWrite((legacyArray.Has(1) ? legacyArray[1] : ""), settingsFile, "Hotkeys", "Start")
        IniWrite((legacyArray.Has(2) ? legacyArray[2] : ""), settingsFile, "Hotkeys", "Reset")
        IniWrite((legacyArray.Has(3) ? legacyArray[3] : ""), settingsFile, "Hotkeys", "Skip")
        IniWrite((legacyArray.Has(4) ? legacyArray[4] : ""), settingsFile, "Hotkeys", "Undo")
        IniWrite((legacyArray.Has(5) ? legacyArray[5] : ""), settingsFile, "Hotkeys", "Capture")
        IniWrite((legacyArray.Has(6) ? legacyArray[6] : ""), settingsFile, "Paths", "LastSplitFile")
        IniWrite((legacyArray.Has(7) ? legacyArray[7] : "0"), settingsFile, "Preferences", "WaitFirstInput")

        FileDelete(legacySettingsFile)
    }
}

; --- Load settings from INI ---
settings["StartHotkey"] := IniRead(settingsFile, "Hotkeys", "Start", "")
settings["ResetHotkey"] := IniRead(settingsFile, "Hotkeys", "Reset", "")
settings["SkipHotkey"] := IniRead(settingsFile, "Hotkeys", "Skip", "")
settings["UndoHotkey"] := IniRead(settingsFile, "Hotkeys", "Undo", "")
settings["CaptureHotkey"] := IniRead(settingsFile, "Hotkeys", "Capture", "")
settings["LastSplitFile"] := IniRead(settingsFile, "Paths", "LastSplitFile", "")
settings["WaitFirstInput"] := IniRead(settingsFile, "Preferences", "WaitFirstInput", "0")

global FirstInputKeys := [
    ["w", "W"],
    ["a", "A"],
    ["s", "S"],
    ["d", "D"],
    ["Space", "Space"],
    ["3", "Heavy Weapon (3)"],
    ["WheelDown", "Mouse Wheel Down"],
    ["WheelUp", "Mouse Wheel Up"],
    ["e", "Interact (e)"]
]

for item in FirstInputKeys {
    key := item[1]
    settings["FI_" key] := IniRead(settingsFile, "FirstInput", key, "1")
}

global SelectedFile := ""
global currentSplit := ""
global currentlyLoadedSplits := []
global currentlyLoadedSplitIndex := 999
global breakLoop := 0
global bossHpHelper := 0
global makeWhite := 0
global makeBlack := 0
global makeTotal := 0
global makex := 0
global makey := 0
global makew := 0
global makeh := 0
global waitingForNextSplit := 0
global timerText := 0
global nLoops := 0
global findFunc := ""
global threshold := 0
global doubleCheck := 0
global currentSplitImageInfo := ""
global breakLoopLF := 0
global PercCorrectForGui := 0
global WhiteCorrectForGui := 0
global BlackCorrectForGui := 0
global DPI_Ratio := A_ScreenDPI / 96
global StartOnFirstInput := 0
global isWaitingForFirstInput := false
global spinnerChars := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
global spinnerIndex := 1

; ===================================================
; Global GUI Objects (Preparation for v2 scope)
; ===================================================
global MainGui := ""
; ===================================================

; GDI+ Initialization (v2 syntax)
; We store the token globally so we can close it properly on exit.
global pToken := Gdip_Startup()

; Load image information
try {
    imageInfoString := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
} catch {
    imageInfoString := "0x000000&0x000000&0|0|1|1"
}

imageDataArray := StrSplit(imageInfoString, "&")
global HPBarDarkColor := imageDataArray[1]
global HPBarLightColor := imageDataArray[2]

; Boss Health Bar Colors (Requires function 'findAllColorsBetween')
global bossHealthBarHashTable := Map() ; In v2 we use Maps for HashTables
if (imageDataArray.Length >= 2) {
    bossHealthBarHashTable := findAllColorsBetween(imageDataArray[1], imageDataArray[2])
}

; Split Manager Index
global splitManagerIndex := 0
global isSplitManagerOpen := 0
; ===================================================

#Include %A_ScriptDir%/Modules/ImageMaker.ahk

; ===================================================
; GUI for the main Autosplitter
; ===================================================

; Set Tray Icon
if FileExist(A_ScriptDir "\31048.ico") {
    TraySetIcon(A_ScriptDir "\31048.ico")
}

; Create GUI object
MainGui := Gui("", "Destiny 2 AutoSplitter")
MainGui.OnEvent("Close", AutoSplitterGuiClose)
MainGui.BackColor := "222222"

; Background image (if present)
if FileExist(A_ScriptDir "\backgroundimage.png") {
    MainGui.Add("Picture", "x0 y0 w721 h520", A_ScriptDir "\backgroundimage.png")
}

MainGui.SetFont("s6 cWhite")
MainGui.Add("Text", "x10 y400 w135 h15 +0x200", "Made By A2TC - Improved By Scope")

MainGui.SetFont("s9", "Segoe UI")
MainGui.Add("GroupBox", "x480 y60 w230 h200")

; --- Hotkeys and assignments ---
tmpVar1 := settings["StartHotkey"]
if (tmpVar1 != "") {
    try Hotkey("$" tmpVar1, OnStartKeyPressed)
}

tmpVar2 := settings["ResetHotkey"]
if (tmpVar2 != "") {
    try Hotkey("$" tmpVar2, OnResetKeyPressed)
}

tmpVar3 := settings["SkipHotkey"]
if (tmpVar3 != "") {
    try Hotkey("$" tmpVar3, OnSkipKeyPress)
}

tmpVar4 := settings["UndoHotkey"]
if (tmpVar4 != "") {
    try Hotkey("$" tmpVar4, OnUndoKeyPressed)
}

tmpVar5 := settings["CaptureHotkey"]
if (tmpVar5 != "") {
    try Hotkey("$" tmpVar5, Capture)
}

; --- Buttons and event handlers ---
MainGui.Add("Button", "x10 y10 w120 h30", "Create New Splits").OnEvent("Click", SaveSplitFileEmpty)
MainGui.Add("Button", "x140 y10 w100 h30", "Open Splits").OnEvent("Click", LoadSplitsToUse)
global gbFileBox := MainGui.Add("GroupBox", "x250 y2 w350 h38", "")
gbFileBox.Visible := false
txtLoadedSplits := MainGui.Add("Text", "x260 y15 w185 h18 +0x200 +BackgroundTrans", "") ; vNameOfLoadedSplits
global btnUnload := MainGui.Add("Text", "x580 y15 w15 h15 +Center +BackgroundTrans", "×")
btnUnload.SetFont("s9 Bold", "Verdana")
btnUnload.OnEvent("Click", (*) => UnloadSplits())
btnUnload.Visible := false

btnEditSplits := MainGui.Add("Button", "x610 y10 w100 h30", "Edit Splits")
btnEditSplits.OnEvent("Click", OpenSplitManager)
btnEditSplits.Visible := false ; Replaces GuiControl, Hide

MainGui.Add("Button", "x490 y370 w210 h30", "Settings").OnEvent("Click", (*) => OpenSettingsWindow())
MainGui.Add("Button", "x490 y330 w210 h30", "Create Split Image").OnEvent("Click", OpenSplitImageMaker)

; --- Status and display ---
txtTimer := MainGui.Add("Text", "x10 y70 w300 h300 +0x200 +Center +Border", "") ; vtimerText
picCurrentSplit := MainGui.Add("Picture", "x10 y70 w300 h300 +Border", "") ; vCurrentSplitImage

btnStart := MainGui.Add("Button", "x490 y180 w210 h40 +Disabled", "Start")
btnStart.OnEvent("Click", OnStartButtonClick)
btnReset := MainGui.Add("Button", "x490 y130 w210 h40 +Disabled", "Reset")
btnReset.OnEvent("Click", OnResetButtonClick)
btnNext := MainGui.Add("Button", "x600 y80 w100 h40 +Disabled", "Next >")
btnNext.OnEvent("Click", OnSkipButtonClick)
btnPrev := MainGui.Add("Button", "x490 y80 w100 h40 +Disabled", "< Previous")
btnPrev.OnEvent("Click", OnUndoButtonClick)

chkVal := settings["WaitFirstInput"]
chkStartFirst := MainGui.Add("CheckBox", "x490 y227 w17 h24 Checked" chkVal, "") ; vStartOnFirstInput
chkStartFirst.OnEvent("Click", (*) => SaveSettings())
txtStartFirstTitle := MainGui.Add("Text", "x510 y230 w170 h20 +0x200", "Wait For First Input After Start")
global txtWaitingFirstInput := MainGui.Add("Text", "x490 y188 w210 h20 cWhite Center Hidden",
    "Waiting for First Input")
global txtSpinner := MainGui.Add("Text", "x665 y188 w25 h20 cWhite Hidden", "")

MainGui.SetFont("s7 cCCCCCC", "Segoe UI")
MainGui.Add("Text", "x325 y70 w150 h15", "Previous Split")
global txtCurrTitle := MainGui.Add("Text", "x325 y130 w150 h15", "Current Split")
MainGui.Add("Text", "x325 y170 w150 h15", "Current Image")
MainGui.Add("Text", "x325 y235 w150 h15", "Next Split")

MainGui.SetFont("s9 cFFFFFF", "Segoe UI")
txtPrev := MainGui.Add("Text", "x325 y85 w150 h25", "") ; vPrev
txtCurr := MainGui.Add("Text", "x325 y145 w150 h25", "") ; vCurr
txtImageName := MainGui.Add("Text", "x325 y185 w150 h25", "") ; vsplitImageNameForGui
txtNext := MainGui.Add("Text", "x325 y250 w150 h25", "") ; vNext

MainGui.SetFont("s7 cCCCCCC", "Segoe UI")
txtLoopCount := MainGui.Add("Text", "x10 y375 w25 h20 +0x200 +Right", "0") ; vloopCount
MainGui.Add("Text", "x40 y375 w30 h20 +0x200", "FPS")

txtMatch := MainGui.Add("Text", "x70 y375 w25 h20 +0x200 +Right", "0") ; vpCorrectForGui
MainGui.Add("Text", "x97 y375 w40 h20 +0x200", "% Match")

txtWhite := MainGui.Add("Text", "x150 y375 w25 h20 +0x200 +Right", "0") ; vwCorrectForGui
MainGui.Add("Text", "x177 y375 w40 h20 +0x200", "% White")

txtBlack := MainGui.Add("Text", "x230 y375 w25 h20 +0x200 +Right", "0") ; vbCorrectForGui
MainGui.Add("Text", "x257 y375 w70 h20 +0x200", "% Black")

MainGui.Show("w720 h420")
btnStart.Focus()

; --- Auto-load last split file ---
if (settings["LastSplitFile"] != "" && FileExist(settings["LastSplitFile"])) {
    LoadSplitsFile(settings["LastSplitFile"])
}

; Hotkeys for game inputs (w, a, s, d etc.)
; These call the function 'OnFirstInputKeyPressed'
for item in FirstInputKeys {
    key := item[1]
    if (settings["FI_" key] == "1") {
        try Hotkey("~$" . key, (*) => OnFirstInputKeyPressed())
        try Hotkey("~+$" . key, (*) => OnFirstInputKeyPressed()) ; Also for Shift+Key
    }
}

; ===================================================
; Save settings
; ===================================================

SaveSettings() {
    global settings, chkStartFirst, settingsFile, FirstInputKeys

    settings["WaitFirstInput"] := chkStartFirst.Value

    IniWrite(settings["StartHotkey"], settingsFile, "Hotkeys", "Start")
    IniWrite(settings["ResetHotkey"], settingsFile, "Hotkeys", "Reset")
    IniWrite(settings["SkipHotkey"], settingsFile, "Hotkeys", "Skip")
    IniWrite(settings["UndoHotkey"], settingsFile, "Hotkeys", "Undo")
    IniWrite(settings["CaptureHotkey"], settingsFile, "Hotkeys", "Capture")
    IniWrite(settings["LastSplitFile"], settingsFile, "Paths", "LastSplitFile")
    IniWrite(settings["WaitFirstInput"], settingsFile, "Preferences", "WaitFirstInput")

    for item in FirstInputKeys {
        key := item[1]
        IniWrite(settings["FI_" key], settingsFile, "FirstInput", key)
    }
}

; ===================================================
; Main logic of the AutoSplitter
; ===================================================
Start(*) {
    global currentlyLoadedSplits, currentlyLoadedSplitIndex, breakLoop, nLoops
    global StartOnFirstInput, imageDataArray

    if (currentlyLoadedSplits.Length == 0 || currentlyLoadedSplits[1] == "") {
        MsgBox("Please load a split file first!")
        return
    }

    currentlyLoadedSplitIndex := 1
    GUIupdate()

    ; Hide/show controls
    btnStart.Visible := false
    btnReset.Enabled := true
    btnReset.Focus()
    btnNext.Enabled := true
    btnPrev.Enabled := true

    chkStartFirst.Visible := false
    txtStartFirstTitle.Visible := false
    txtWaitingFirstInput.Visible := false
    txtSpinner.Visible := false
    SetTimer(updateSpinner, 0)

    breakLoop := 0
    nLoops := 0

    ; Start timer (v2 uses function references)
    SetTimer(countLoops, 1000)

    ; Deactivate hotkey during run
    if (settings["StartHotkey"] != "") {
        try Hotkey("$" settings["StartHotkey"], "Off")
    }

    loop {
        WriteLog("Start loop ")
        txtTimer.Value := ""
        previousSplitWasBossDeath := 0

        currentSplitData := StrSplit(currentlyLoadedSplits[currentlyLoadedSplitIndex], ",")

        if (currentlyLoadedSplitIndex > 1) {
            prevData := StrSplit(currentlyLoadedSplits[currentlyLoadedSplitIndex - 1], ",")
            if (prevData.Has(2) && prevData[2] == "Boss Death")
                previousSplitWasBossDeath := 1
        }

        currentSplitImageName := currentSplitData[2]

        imgFilePath := A_ScriptDir "\Split_Images\" currentSplitImageName ".png"

        if FileExist(imgFilePath) {
            hBmp := LoadPixelatedImage(imgFilePath, 300, 300)

            if (hBmp) {
                picCurrentSplit.Value := "HBITMAP:*" hBmp
                picCurrentSplit.Move(, , 300, 300)
                picCurrentSplit.Visible := true
            }
        } else {
            picCurrentSplit.Visible := false
        }

        txtImageName.Value := currentSplitImageName

        ; 2. FIX: Use global variable imageDataArray so boss functions find coordinates!
        imageInfoContent := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
        imageDataArray := StrSplit(imageInfoContent, "&")

        activeImageInfo := ""
        for i, infoLine in imageDataArray {
            tempInfo := StrSplit(infoLine, ",")
            if (tempInfo[1] == currentSplitImageName) {
                activeImageInfo := tempInfo
                break
            }
        }

        if (currentSplitImageName == "None") {
            MsgBox("No image selected for split " currentlyLoadedSplitIndex ".")
            OnResetButtonClick()
            return
        }

        ; Determine search function
        local funcToUse := "findNormal"
        local pixelArray := []

        if (currentSplitImageName == "Boss Death") {
            funcToUse := "findBossDeath"
        } else if (currentSplitImageName == "Boss Healthbar") {
            funcToUse := "findBossThere"
        } else {
            pixelString := makePixelArrayString(currentSplitImageName)
            pixelArray := StrSplit(pixelString, ",")
        }

        ; Start search
        lookingFor(funcToUse, currentSplitData[4], previousSplitWasBossDeath, activeImageInfo, pixelArray)

        if (currentlyLoadedSplitIndex > currentlyLoadedSplits.Length || currentlyLoadedSplitIndex < 1) {
            break
        }
    }

    if (settings["StartHotkey"] != "") {
        try Hotkey("$" settings["StartHotkey"], "On")
    }

    OnResetButtonClick()
}

OnFirstInputKeyPressed(*) {
    global currentlyLoadedSplitIndex, settings, isWaitingForFirstInput

    ; Query active window (v2 syntax)
    activeWindow := WinGetTitle("A")

    WriteLog("OnFirstInputKeyPressed " currentlyLoadedSplitIndex " " isWaitingForFirstInput " " activeWindow)

    if (isWaitingForFirstInput && currentlyLoadedSplitIndex == 999 && activeWindow == "Destiny 2") {
        WriteLog("OnFirstInputKeyPressed! Starting...")

        startKey := settings["StartHotkey"]
        if (startKey != "") {
            Send("{" startKey "}")
        }

        ; In v2 we replace 'GoSub StartAutoSplitter' with a simple function call
        Start()
    }
}

OnStartButtonClick(*) {
    global isWaitingForFirstInput, chkStartFirst, btnStart, txtWaitingFirstInput, btnReset

    ; If we are already waiting, nothing happens on re-click
    if (isWaitingForFirstInput)
        return

    ; If checkbox is set, we go into "Waiting Mode"
    isWaitingForFirstInput := true
    if (chkStartFirst.Value == 1) {

        ; Toggle GUI
        btnStart.Visible := false
        btnReset.Enabled := true
        btnReset.Focus()
        chkStartFirst.Visible := false
        txtStartFirstTitle.Visible := false
        txtWaitingFirstInput.Visible := true
        txtSpinner.Visible := true
        SetTimer(updateSpinner, 100)

        return ; IMPORTANT: We abort here! The real start hasn't happened yet.
    }

    ; If checkbox is NOT set, start normally immediately:
    Start()
}

OnStartKeyPressed(*) {
    global settings, chkStartFirst
    startKey := settings["StartHotkey"]

    WriteLog("OnStartKeyPressed " startKey)

    if (chkStartFirst.Value == 1) {
        OnStartButtonClick()
        return ; This prevents the key press from reaching other apps, LiveSplit in particular
    }

    if (startKey != "") {
        Send("{" startKey "}")
    }
    Start()
}

OnResetKeyPressed(*) {
    global settings
    resetBtnStr := settings["ResetHotkey"]

    if (resetBtnStr != "") {
        Send("{" resetBtnStr "}")
    }

    btnStart.Text := "Start"
    Reset()
}

OnResetButtonClick(*) {
    Reset()
}

OnSkipKeyPress(*) {
    global settings
    skipBtnStr := settings["SkipHotkey"]

    if (skipBtnStr != "") {
        Send("{" skipBtnStr "}")
    }

    SkipSplit()
}

OnSkipButtonClick(*) {
    SkipSplit()
}

OnUndoKeyPressed(*) {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex, settings
    undoBtnStr := settings["UndoHotkey"]

    if (undoBtnStr != "") {
        Send("{" undoBtnStr "}")
    }

    UndoSplit()
}

OnUndoButtonClick(*) {
    UndoSplit()
}

Reset() {
    global isWaitingForFirstInput, btnStart, chkStartFirst, txtWaitingFirstInput

    ; If we were in waiting mode, abort immediately and reset GUI
    if (isWaitingForFirstInput) {
        isWaitingForFirstInput := false
        txtWaitingFirstInput.Visible := false
        txtSpinner.Visible := false
        SetTimer(updateSpinner, 0)
        btnStart.Visible := true
        btnStart.Enabled := true
        btnStart.Focus()
        chkStartFirst.Visible := true
        txtStartFirstTitle.Visible := true
    }

    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex, bossHpHelper
    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex := 999
    bossHpHelper := 0

    btnStart.Visible := true
    btnStart.Enabled := true
    btnStart.Focus()
    btnReset.Enabled := false
    btnNext.Enabled := false
    btnPrev.Enabled := false

    GUIupdate()

    txtImageName.Value := ""
    picCurrentSplit.Visible := false
    txtTimer.Value := ""

    chkStartFirst.Visible := true
    txtStartFirstTitle.Visible := true
    txtWaitingFirstInput.Visible := false
    txtSpinner.Visible := false
    SetTimer(updateSpinner, 0)

    updateCorrectStats()
}

SkipSplit() {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex
    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex += 1
    GUIupdate()
}

UndoSplit() {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex
    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex -= 1
    GUIupdate()
}

lookingFor(funcName, thresh, isDoubleCheck, imgInfo, pArray) {
    global breakLoop, breakLoopLF, findFunc, threshold, doubleCheck, currentSplitImageInfo, currentSplitPixelArray

    breakLoop := 0
    breakLoopLF := 0
    Sleep(500)

    findFunc := funcName
    threshold := thresh
    doubleCheck := isDoubleCheck
    currentSplitImageInfo := imgInfo
    currentSplitPixelArray := pArray

    GUIupdate()

    SetTimer(doLoop, 10)
    SetTimer(updateCorrectStats, 50)

    loop {
        if (breakLoopLF)
            break
        Sleep(10)
    }
}

updateSpinner() {
    global spinnerIndex, spinnerChars, txtSpinner
    txtSpinner.Value := spinnerChars[spinnerIndex]
    spinnerIndex += 1
    if (spinnerIndex > spinnerChars.Length)
        spinnerIndex := 1
}

countLoops() {
    global nLoops
    txtLoopCount.Value := nLoops
    nLoops := 0
}

updateCorrectStats() {
    global PercCorrectForGui, WhiteCorrectForGui, BlackCorrectForGui
    txtMatch.Value := PercCorrectForGui
    txtWhite.Value := WhiteCorrectForGui
    txtBlack.Value := BlackCorrectForGui
    PercCorrectForGui := 0
    WhiteCorrectForGui := 0
    BlackCorrectForGui := 0
}

doLoop() {
    global breakLoop, breakLoopLF, bossHpHelper, findFunc, threshold, doubleCheck
    global currentSplitImageInfo

    if (breakLoop) {
        breakLoopLF := 1
        breakLoop := 1
        SetTimer(doLoop, 0) ; 0 stoppt den Timer in v2
        SetTimer(updateCorrectStats, 0)
        updateCorrectStats()
        return
    }

    ; Dynamic function call in v2
    ; We use %findFunc% as a function object or call it by name
    try {
        pCorrect := %findFunc%(currentSplitImageInfo)
    } catch {
        return ; In case the function is not yet defined
    }

    if (pCorrect >= threshold) {
        breakLoopLF := 1
        breakLoop := 1
        SetTimer(doLoop, 0)
        SetTimer(updateCorrectStats, 0)
        updateCorrectStats()
        handleSplit(pCorrect)
    }

    if (doubleCheck) {
        findBossThere(1)
        if (bossHpHelper >= 60) {
            breakLoopLF := 1
            bossHpHelper := 0
            breakLoop := 1
            SetTimer(doLoop, 0)
            SetTimer(updateCorrectStats, 0)
            OnUndoKeyPressed() ; Function call instead of GoTo
        }
    }

    global nLoops += 1
}

handleSplit(pCorrect) {
    global currentlyLoadedSplitIndex, waitingForNextSplit, timerText, breakLoop
    global currentlyLoadedSplits, settings

    ; Get current data
    currentData := StrSplit(currentlyLoadedSplits[currentlyLoadedSplitIndex], ",")

    ; If not a dummy split (Index 3 is 0), send split key
    if (currentData.Has(3) && currentData[3] == "0") {
        startKey := settings["StartHotkey"]
        if (startKey != "")
            Send("{" startKey "}")
    }

    ; Calculate delay (Index 5 is delay in seconds)
    timerText := (currentData.Has(5) ? currentData[5] : 0) * 1000

    if (currentData.Has(2) && currentData[2] == "Boss Death")
        timerText := 0

    currentlyLoadedSplitIndex += 1
    waitingForNextSplit := 1
    breakLoop := 0

    SetTimer(waitForNextSplit, 100)

    ; Wait for timer expiration
    loop {
        if (!waitingForNextSplit)
            break
        Sleep(10)
    }
    SetTimer(waitForNextSplit, 0)
}

waitForNextSplit() {
    global timerText, waitingForNextSplit, breakLoop

    if (breakLoop) {
        timerText := 0
    }

    timerText -= 100
    timeLeft := Round((timerText / 1000), 1)
    txtTimer.Value := (timeLeft > 0) ? timeLeft : ""

    if (timerText <= 0)
        waitingForNextSplit := 0
}

SaveSplitFileEmpty(*) {
    global SelectedFile

    ; Disable main window while dialog is open
    MainGui.Opt("+Disabled")

    ; Use a loop instead of the old "Goto, inputtingSplitFileName"
    loop {
        ib := InputBox("What would you like to name your Splits?", "Create New Splits")

        ; If user clicks "Cancel" or window closes
        if (ib.Result == "Cancel" || ib.Result == "Timeout") {
            break
        }

        tempSplitFileName := ib.Value ".txt"
        targetFile := A_WorkingDir "\Split_Files\" tempSplitFileName

        ; Check if file already exists
        if FileExist(targetFile) {
            ; MsgBox in v2 returns the pressed button as a string directly
            if (MsgBox("A split file with this name already exists.`nWould you like to overwrite it?", "Warning",
                "YesNo") == "No") {
                continue ; Starts loop from the beginning (new input)
            }
        }

        ; Create file and fill with default values
        stringToSaveToFile := "None,None,0,0.9,7"
        try FileDelete(targetFile)
        FileAppend(stringToSaveToFile, targetFile)

        ; Load the new file directly
        LoadSplitsFile(targetFile)
        break ; End loop because we were successful
    }

    ; Unlock main window again
    MainGui.Opt("-Disabled")
    MainGui.Show()
}

LoadSplitsToUse(*) {
    global SelectedFile
    MainGui.Opt("+Disabled") ; Lock window

    selFile := FileSelect(3, A_WorkingDir "\Split_Files\", "Open a split file", "Text Documents (*.txt; *.doc)")

    if (selFile != "") {
        LoadSplitsFile(selFile)
    }

    MainGui.Opt("-Disabled")
    MainGui.Show()
}

LoadSplitsFile(path) {
    global currentlyLoadedSplits, SelectedFile
    try {
        splitFileDataString := FileRead(path)
        currentlyLoadedSplits := StrSplit(splitFileDataString, "&")
        SelectedFile := path

        ; Persist last used split file
        settings["LastSplitFile"] := path
        SaveSettings()

        ; Update GUI
        splitName := RegExReplace(path, ".*\\") ; Extracts filename
        txtLoadedSplits.Value := splitName
        btnEditSplits.Visible := true
        btnStart.Enabled := true

        gbFileBox.Visible := true
        btnUnload.Visible := true
    } catch {
        MsgBox("Error loading file.")
    }
}

UnloadSplits(*) {
    global currentlyLoadedSplits, SelectedFile, settings
    global txtLoadedSplits, btnEditSplits, btnStart, btnReset, btnNext, btnPrev
    global gbFileBox, btnUnload
    global txtPrev, txtCurr, txtNext, txtImageName, txtTimer, picCurrentSplit

    currentlyLoadedSplits := []
    SelectedFile := ""
    txtLoadedSplits.Value := ""

    ; Hide UI elements
    gbFileBox.Visible := false
    btnUnload.Visible := false
    btnEditSplits.Visible := false

    ; Disable control buttons
    btnStart.Enabled := false
    btnReset.Enabled := false
    btnNext.Enabled := false
    btnPrev.Enabled := false

    ; Clear persistent setting
    settings["LastSplitFile"] := ""
    SaveSettings()

    ; Reset display fields
    txtPrev.Value := ""
    txtCurr.Value := ""
    txtNext.Value := ""
    txtImageName.Value := ""
    txtTimer.Value := ""
    picCurrentSplit.Visible := false

    GUIupdate()
}

; ===================================================
; Timer Funktionen
; ===================================================

; ===================================================
; GUI Updates & Split Control
; ===================================================

GUIupdate() {
    global currentlyLoadedSplits, currentlyLoadedSplitIndex

    ; Safety checks to avoid out-of-bounds errors
    hPrev := (currentlyLoadedSplitIndex > 1 && currentlyLoadedSplits.Has(currentlyLoadedSplitIndex - 1)) ? StrSplit(
        currentlyLoadedSplits[currentlyLoadedSplitIndex - 1], ",")[1] : ""
    hCurr := (currentlyLoadedSplits.Has(currentlyLoadedSplitIndex)) ? StrSplit(currentlyLoadedSplits[
        currentlyLoadedSplitIndex], ",")[1] : ""
    hNext := (currentlyLoadedSplits.Has(currentlyLoadedSplitIndex + 1)) ? StrSplit(currentlyLoadedSplits[
        currentlyLoadedSplitIndex + 1], ",")[1] : ""

    ; Add split number info
    if (hCurr != "") {
        totalSplits := currentlyLoadedSplits.Length
        txtCurrTitle.Value := "Current Split (" currentlyLoadedSplitIndex " / " totalSplits ")"
    } else {
        txtCurrTitle.Value := "Current Split"
    }

    ; Update objects
    txtPrev.Value := hPrev
    txtCurr.Value := hCurr
    txtNext.Value := hNext

    WriteLog("GUIupdate prev:" hPrev " curr:" hCurr " next:" hNext)
}

AutoSplitterGuiClose(*) {
    global pToken
    Gdip_Shutdown(pToken)
    ExitApp()
}

; ===================================================
; General Hotkeys
; ===================================================

~^F7:: {
    global WinTitle, isTransparent
    if (!IsSet(isTransparent))
        isTransparent := false

    if (isTransparent) {
        isTransparent := false
        WinSetExStyle("-0x20", WinTitle)
        WinSetTransColor("Off", WinTitle)
    } else {
        isTransparent := true
        WinSetExStyle("+0x20", WinTitle)
        WinSetTransColor("0x000000", WinTitle)
    }
}

^F4:: Reload()