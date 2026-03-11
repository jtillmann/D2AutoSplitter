#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines False
ProcessSetPriority "A"
SetWinDelay -1
SetControlDelay -1

#Include %A_ScriptDir%/Gdip_all_v2.ahk
#Include %A_ScriptDir%/Modules/Helpers.ahk
#Include %A_ScriptDir%/Modules/SplitManager.ahk

SetWorkingDir A_ScriptDir
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

global WinTitle := "LiveSplit"

WriteLog(text) {
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

; --- Load Hotkeys ---
global hotkeySettingsString := ""
global hotKeySettingsArray := []

try {
    hotkeySettingsString := FileRead(A_ScriptDir "\Dependencies\settings.txt")
} catch {
    hotkeySettingsString := ""
}

hotKeySettingsArray := StrSplit(hotkeySettingsString, "&")

; Dynamic variable assignment (Hotkey1, Hotkey2...) must be handled in v2
; via an array or a map, as dynamic variable names
; like 'Hotkey%A_Index%' no longer exist.
global HotkeysV2 := []
loop 4 {
    if hotKeySettingsArray.Has(A_Index)
        HotkeysV2.Push(hotKeySettingsArray[A_Index])
    else
        HotkeysV2.Push("")
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
global ImageMakerGui := ""
global HPbarGui := ""
global ScreenshotGui := ""
; ===================================================
; Global declarations for Split Image Maker
; ===================================================
global realImage := A_ScriptDir "\Dependencies\real_image.png"
global BnWImage := A_ScriptDir "\Dependencies\BnW.png"
global scshot := A_ScriptDir "\Dependencies\fullScreenshot.png"
global tmpImage := A_ScriptDir "\Dependencies\tmp.png"

; GDI+ Initialization (v2 syntax)
; We store the token globally so we can close it properly on exit.
global pToken := Gdip_Startup()

; Initial creation of dummy images
; In v2, functions like Gdip_BitmapFromScreen are expressions
pBitmap := Gdip_BitmapFromScreen("0|0|1|1")
Gdip_SaveBitmapToFile(pBitmap, realImage)
Gdip_SaveBitmapToFile(pBitmap, BnWImage)
Gdip_DisposeImage(pBitmap)

global x1 := 0, y1 := 0, x2 := 0, y2 := 0
global w := 0, h := 0, total := 0
global imageCoords := "0|0|1|1"

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
MainGui.Add("Text", "x8 y432 w125 h15 +0x200", "Made By A2TC - Improved By Scope")

MainGui.SetFont("s9", "Segoe UI")
MainGui.Add("GroupBox", "x480 y60 w230 h200")
MainGui.Add("GroupBox", "x480 y270 w230 h170", "Hotkeys")

; --- Hotkeys and assignments ---
; In v2 we save the control objects in variables to access them later
tmpVar1 := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""
if (tmpVar1 != "") {
    try Hotkey("$" tmpVar1, OnStartButtonClick)
}
hkControl1 := MainGui.Add("Hotkey", "x570 y290 w130 h21 vHotKey1", tmpVar1)

tmpVar2 := (hotKeySettingsArray.Has(2)) ? hotKeySettingsArray[2] : ""
if (tmpVar2 != "") {
    try Hotkey("$" tmpVar2, OnResetKeyPressed)
}
hkControl2 := MainGui.Add("Hotkey", "x570 y320 w130 h21 vHotKey2", tmpVar2)

tmpVar3 := (hotKeySettingsArray.Has(3)) ? hotKeySettingsArray[3] : ""
if (tmpVar3 != "") {
    try Hotkey("$" tmpVar3, OnSkipKeyPress)
}
hkControl3 := MainGui.Add("Hotkey", "x570 y380 w130 h21 vHotKey3", tmpVar3)

tmpVar4 := (hotKeySettingsArray.Has(4)) ? hotKeySettingsArray[4] : ""
if (tmpVar4 != "") {
    try Hotkey("$" tmpVar4, OnUndoKeyPressed)
}
hkControl4 := MainGui.Add("Hotkey", "x570 y350 w130 h21 vHotKey4", tmpVar4)

; --- Buttons and event handlers ---
MainGui.Add("Button", "x10 y10 w120 h30", "Create New Splits").OnEvent("Click", SaveSplitFileEmpty)
MainGui.Add("Button", "x140 y10 w100 h30", "Open Splits").OnEvent("Click", LoadSplitsToUse)
txtLoadedSplits := MainGui.Add("Text", "x250 y12 w150 h23 +0x200", "") ; vNameOfLoadedSplits

btnEditSplits := MainGui.Add("Button", "x450 y10 w100 h30", "Edit Splits")
btnEditSplits.OnEvent("Click", OpenSplitManager)
btnEditSplits.Visible := false ; Replaces GuiControl, Hide

MainGui.Add("Button", "x560 y10 w150 h30", "Create Split Image").OnEvent("Click", OpenSplitImageMaker)

; --- Status and display ---
txtTimer := MainGui.Add("Text", "x10 y70 w300 h300 +0x200 +Center +Border", "") ; vtimerText
picCurrentSplit := MainGui.Add("Picture", "x10 y70 w300 h300 +Border", "") ; vCurrentSplitImage

MainGui.Add("Text", "x490 y290 w60 h20 +0x200", "Start/Split")
MainGui.Add("Text", "x490 y320 w60 h20 +0x200", "Reset")
MainGui.Add("Text", "x490 y380 w60 h20 +0x200", "Skip Split")
MainGui.Add("Text", "x490 y350 w60 h20 +0x200", "Undo Split")
MainGui.Add("Button", "x640 y410 w60 h20", "Set").OnEvent("Click", Sethotkeys)

btnStart := MainGui.Add("Button", "x490 y180 w210 h40", "Start")
btnStart.OnEvent("Click", OnStartButtonClick)

btnReset := MainGui.Add("Button", "x490 y130 w210 h40", "Reset")
btnReset.OnEvent("Click", OnResetButtonClick)
MainGui.Add("Button", "x600 y80 w100 h40", "Next >").OnEvent("Click", OnSkipButtonClick)
MainGui.Add("Button", "x490 y80 w100 h40", "< Previous").OnEvent("Click", OnUndoButtonClick)

chkStartFirst := MainGui.Add("CheckBox", "x490 y227 w17 h24", "") ; vStartOnFirstInput
txtStartFirstTitle := MainGui.Add("Text", "x510 y230 w150 h20 +0x200", "Start waits for First Input")
global txtWaitingFirstInput := MainGui.Add("Text", "x490 y188 w210 h20 cWhite Center Hidden",
    "Waiting for First Input")
global txtSpinner := MainGui.Add("Text", "x665 y188 w25 h20 cWhite Hidden", "")

MainGui.SetFont("s7 cCCCCCC", "Segoe UI")
MainGui.Add("Text", "x325 y70 w150 h15", "Previous Split")
MainGui.Add("Text", "x325 y130 w150 h15", "Current Split")
MainGui.Add("Text", "x325 y170 w150 h15", "Current Image")
MainGui.Add("Text", "x325 y235 w150 h15", "Next Split")

MainGui.SetFont("s9 cFFFFFF", "Segoe UI")
txtPrev := MainGui.Add("Text", "x325 y85 w150 h25", "") ; vPrev
txtCurr := MainGui.Add("Text", "x325 y145 w150 h25", "") ; vCurr
txtImageName := MainGui.Add("Text", "x325 y185 w150 h25", "") ; vsplitImageNameForGui
txtNext := MainGui.Add("Text", "x325 y250 w150 h25", "") ; vNext

MainGui.SetFont("s7 cCCCCCC", "Segoe UI")
txtLoopCount := MainGui.Add("Text", "x10 y380 w25 h20 +0x200 +Right", "0") ; vloopCount
MainGui.Add("Text", "x40 y380 w30 h20 +0x200", "FPS")

txtMatch := MainGui.Add("Text", "x70 y380 w25 h20 +0x200 +Right", "0") ; vpCorrectForGui
MainGui.Add("Text", "x97 y380 w40 h20 +0x200", "% Match")

txtWhite := MainGui.Add("Text", "x150 y380 w25 h20 +0x200 +Right", "0") ; vwCorrectForGui
MainGui.Add("Text", "x177 y380 w40 h20 +0x200", "% White")

txtBlack := MainGui.Add("Text", "x230 y380 w25 h20 +0x200 +Right", "0") ; vbCorrectForGui
MainGui.Add("Text", "x257 y380 w70 h20 +0x200", "% Black")

MainGui.Show("w720 h450")
btnStart.Focus()

; ===================================================
; GUI for Split Image Maker
; ===================================================
global ImageMakerGui := Gui("", "Split Image Maker")
ImageMakerGui.OnEvent("Close", (*) => ImageMakerGui.Hide())

ImageMakerGui.Add("GroupBox", "x12 y-1 w140 h540", "Settings")

; Buttons for screenshot functions
btnCapture := ImageMakerGui.Add("Button", "x22 y15 w120 h50", "Freeze Screen")
btnCapture.OnEvent("Click", Capture)
btnUncapture := ImageMakerGui.Add("Button", "x22 y15 w120 h50 +Hidden", "Unfreeze Screen")
btnUncapture.OnEvent("Click", Uncapture)

; Hotkey control
tmpVarHK5 := (hotKeySettingsArray.Length >= 5) ? hotKeySettingsArray[5] : ""
if (tmpVarHK5 != "") {
    try Hotkey("$" tmpVarHK5, Capture)
}
hkCapture := ImageMakerGui.Add("Hotkey", "x27 y70 w110 h20", tmpVarHK5)
ImageMakerGui.Add("Button", "x52 y92 w60 h23", "Set").OnEvent("Click", Sethotkeys)

ImageMakerGui.Add("Button", "x22 y115 w120 h50", "Select Area").OnEvent("Click", Picture)
ImageMakerGui.Add("Button", "x22 y165 w120 h50", "Save Current Image").OnEvent("Click", Save)
ImageMakerGui.Add("Button", "x22 y480 w120 h50", "Open Boss HP Bar Color Finder").OnEvent("Click", OpenHPFinder)

; --- Coordinate adjustment (Top, Bottom, Left, Right) ---
; Helper function to avoid the "global" error
AdjustCoord(coord, delta, *) {
    global x1, y1, x2, y2

    if (coord = "y1") {
        y1 += delta
    } else if (coord = "y2") {
        y2 += delta
    } else if (coord = "x1") {
        x1 += delta
    } else if (coord = "x2") {
        x2 += delta
    }

    ; Update the text displays in the GUI
    txtTopNum.Value := y1
    txtBotNum.Value := y2
    txtLeftNum.Value := x1
    txtRightNum.Value := x2

    updateRect(x1, y1, x2, y2)
    setImages(x1, y1, x2, y2)
}

; Top
ImageMakerGui.Add("Text", "x70 y219 w80 h20", "Top")
txtTopNum := ImageMakerGui.Add("Text", "x63 y242 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y239 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("y1", -10))
ImageMakerGui.Add("Button", "x122 y239 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("y1", 10))
ImageMakerGui.Add("Button", "x42 y239 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("y1", -1))
ImageMakerGui.Add("Button", "x102 y239 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("y1", 1))

; Bottom
ImageMakerGui.Add("Text", "x70 y289 w80 h20", "Bottom")
txtBotNum := ImageMakerGui.Add("Text", "x63 y312 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y309 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("y2", -10))
ImageMakerGui.Add("Button", "x122 y309 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("y2", 10))
ImageMakerGui.Add("Button", "x42 y309 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("y2", -1))
ImageMakerGui.Add("Button", "x102 y309 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("y2", 1))

; Left
ImageMakerGui.Add("Text", "x70 y359 w80 h20", "Left")
txtLeftNum := ImageMakerGui.Add("Text", "x63 y382 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y379 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("x1", -10))
ImageMakerGui.Add("Button", "x122 y379 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("x1", 10))
ImageMakerGui.Add("Button", "x42 y379 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("x1", -1))
ImageMakerGui.Add("Button", "x102 y379 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("x1", 1))

; Right
ImageMakerGui.Add("Text", "x67 y429 w80 h20", "Right")
txtRightNum := ImageMakerGui.Add("Text", "x63 y452 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y449 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("x2", -10))
ImageMakerGui.Add("Button", "x122 y449 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("x2", 10))
ImageMakerGui.Add("Button", "x42 y449 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("x2", -1))
ImageMakerGui.Add("Button", "x102 y449 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("x2", 1))

; Image displays
ImageMakerGui.Add("GroupBox", "x162 y-1 w530 h510", "Black and White Pixels")
ImageMakerGui.Add("GroupBox", "x702 y-1 w530 h510", "Actual Image")
picReal := ImageMakerGui.Add("Picture", "x712 y19 w510 h480", realImage)
picBnW := ImageMakerGui.Add("Picture", "x172 y19 w510 h480", BnWImage)

txtPW := ImageMakerGui.Add("Text", "x360 y520 w50 h20", "0")
txtTP := ImageMakerGui.Add("Text", "x580 y520 w150 h20", "0")

; ===================================================
; GUI for Boss HP Bar Color Finder
; ===================================================
global HPbarGui := Gui("+AlwaysOnTop", "Boss HP Bar Color Finder")
HPbarGui.OnEvent("Close", (*) => HPbarGui.Hide())

HPbarGui.Add("Button", "x8 y8 w57 h128", "Save Colors").OnEvent("Click", SaveHPBarColors)
HPbarGui.Add("Button", "x8 y146 w57 h56", "Set Bar Location").OnEvent("Click", SetBarLocation)
HPbarGui.Add("Button", "x72 y168 w149 h46", "Find Dark Color").OnEvent("Click", SetDarkColor)
HPbarGui.Add("Button", "x224 y168 w149 h46", "Find Light Color").OnEvent("Click", SetLightColor)

picDarkHP := HPbarGui.Add("Picture", "x72 y8 w149 h129", tmpImage)
picLightHP := HPbarGui.Add("Picture", "x224 y8 w149 h129", tmpImage)

; ===================================================
; Selection rectangle GUIs
; ===================================================
global RectGuis := []
loop 4 {
    G := Gui("-Caption +ToolWindow +AlwaysOnTop")
    G.BackColor := "Red"
    RectGuis.Push(G)
}

; ===================================================
; Show main GUI & Hotkeys
; ===================================================
MainGui.Show("w720 h450")

; Hotkeys for game inputs (w, a, s, d etc.)
; These call the function 'OnFirstInputKeyPressed'
MovementKeys := ["w", "a", "s", "d", "Space", "3", "WheelDown", "WheelUp", "e"]
for key in MovementKeys {
    Hotkey("~$" . key, (*) => OnFirstInputKeyPressed())
    Hotkey("~+$" . key, (*) => OnFirstInputKeyPressed()) ; Also for Shift+Key
}

; ===================================================
; Save and set hotkey settings
; ===================================================

Sethotkeys(*) {
    global hotKeySettingsArray, hotkeySettingsString

    ; Read values from GUI objects (v2 uses .Value)
    newHKs := [hkControl1.Value, hkControl2.Value, hkControl3.Value, hkControl4.Value, hkCapture.Value]

    loop newHKs.Length {
        idx := A_Index
        newKey := newHKs[idx]
        oldKey := (hotKeySettingsArray.Has(idx)) ? hotKeySettingsArray[idx] : ""

        if (newKey != "") {
            ; Deactivate old hotkey, if present
            if (oldKey != "") {
                try Hotkey("$" oldKey, "Off")
            }

            ; Set new hotkey
            hotKeySettingsArray[idx] := newKey

            ; Assign function based on index
            callback := (idx = 1) ? OnStartKeyPressed :
                (idx = 2) ? OnResetKeyPressed :
                    (idx = 3) ? OnSkipKeyPress :
                        (idx = 4) ? OnUndoKeyPressed : Capture

            try Hotkey("$" newKey, callback)
        }
    }

    ; Assemble string for file
    hotkeySettingsString := ""
    for k, v in hotKeySettingsArray {
        hotkeySettingsString .= (k = 1 ? "" : "&") . v
    }

    try FileDelete(A_ScriptDir "\Dependencies\settings.txt")
    FileAppend(hotkeySettingsString, A_ScriptDir "\Dependencies\settings.txt")
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
    if (hotKeySettingsArray.Has(1) && hotKeySettingsArray[1] != "") {
        try Hotkey("$" hotKeySettingsArray[1], "Off")
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

        ; 1. FIX: Update image preview
        imgFilePath := A_ScriptDir "\Split_Images\" currentSplitImageName ".png"

        if FileExist(imgFilePath) {
            ; a) Load image normally (WITHOUT the *w *h string)
            picCurrentSplit.Value := imgFilePath

            ; b) Lock the control to original values immediately
            ; (Replace 200 and 150 here again with your real values from section 5!)
            picCurrentSplit.Move(, , 300, 300)

            ; c) Make visible again (if it was previously hidden by Boss Death)
            picCurrentSplit.Visible := true
        } else {
            ; Hide for Boss Death etc.
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

    if (hotKeySettingsArray.Has(1) && hotKeySettingsArray[1] != "") {
        try Hotkey("$" hotKeySettingsArray[1], "On")
    }

    OnResetButtonClick()
}

OnFirstInputKeyPressed(*) {
    global currentlyLoadedSplitIndex, hotKeySettingsArray, isWaitingForFirstInput

    ; Query active window (v2 syntax)
    activeWindow := WinGetTitle("A")

    WriteLog("OnFirstInputKeyPressed " currentlyLoadedSplitIndex " " isWaitingForFirstInput " " activeWindow)

    if (isWaitingForFirstInput && currentlyLoadedSplitIndex == 999 && activeWindow == "Destiny 2") {
        WriteLog("OnFirstInputKeyPressed! Starting...")

        splitKey := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""
        if (splitKey != "") {
            Send("{" splitKey "}")
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

        btnReset.focus()

        ; Toggle GUI
        btnStart.Visible := false
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
    global hotKeySettingsArray
    splitKey := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""

    WriteLog("OnStartKeyPressed " splitKey)

    if (splitKey != "") {
        Send("{" splitKey "}")
    }
    Start()
}

OnResetKeyPressed(*) {
    global hotKeySettingsArray
    resetBtnStr := (hotKeySettingsArray.Has(2)) ? hotKeySettingsArray[2] : ""

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
    global hotKeySettingsArray
    skipBtnStr := (hotKeySettingsArray.Has(3)) ? hotKeySettingsArray[3] : ""

    if (skipBtnStr != "") {
        Send("{" skipBtnStr "}")
    }

    SkipSplit()
}

OnSkipButtonClick(*) {
    SkipSplit()
}

OnUndoKeyPressed(*) {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex, hotKeySettingsArray
    undoBtnStr := (hotKeySettingsArray.Has(4)) ? hotKeySettingsArray[4] : ""

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
        chkStartFirst.Visible := true
        txtStartFirstTitle.Visible := true
    }

    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex, bossHpHelper
    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex := 999
    bossHpHelper := 0

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
    global currentlyLoadedSplits, hotKeySettingsArray

    ; Get current data
    currentData := StrSplit(currentlyLoadedSplits[currentlyLoadedSplitIndex], ",")

    ; If not a dummy split (Index 3 is 0), send split key
    if (currentData.Has(3) && currentData[3] == "0") {
        splitKey := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""
        if (splitKey != "")
            Send("{" splitKey "}")
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

; ===================================================
; Open Split Image Maker
; ===================================================

OpenSplitImageMaker(*) {
    global ImageMakerGui, MainGui, ScreenshotGui

    ; Lock main window so user can't click in it in parallel
    MainGui.Opt("+Disabled")

    ; Show Image Maker GUI centered and at correct size
    ImageMakerGui.Show("Center h550 w1244")

    ; Script pauses here until "Split Image Maker" window is closed
    WinWaitClose("Split Image Maker")

    ; Re-enable main window
    MainGui.Opt("-Disabled")

    ; If screenshot interface still exists/open, cancel (hide)
    if (Type(ScreenshotGui) == "Gui") {
        ScreenshotGui.Hide()
    }

    ; Bring main window to foreground again
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

        ; Update GUI
        splitName := RegExReplace(path, ".*\\") ; Extracts filename
        txtLoadedSplits.Value := splitName
        btnEditSplits.Visible := true
    } catch {
        MsgBox("Error loading file.")
    }
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

    ; Update objects
    txtPrev.Value := hPrev
    txtCurr.Value := hCurr
    txtNext.Value := hNext

    WriteLog("GUIupdate prev:" hPrev " curr:" hCurr " next:" hNext)
}

; ===================================================
; Image Maker: Set colors & coordinates
; ===================================================

SetDarkColor(*) {
    global HPBarDarkColor, tmpImage, pToken
    KeyWait("LButton", "D")
    MouseGetPos(&X, &Y)
    HPBarDarkColor := PixelGetColor(X, Y) ; Standard format in v2 is RGB

    pGlobalBitmap := Gdip_CreateBitmap(149, 129)
    setBitmapColor(pGlobalBitmap, HPBarDarkColor)
    Gdip_SaveBitmapToFile(pGlobalBitmap, tmpImage)
    picDarkHP.Value := tmpImage
    Gdip_DisposeImage(pGlobalBitmap)
}

SetLightColor(*) {
    global HPBarLightColor, tmpImage, pToken
    KeyWait("LButton", "D")
    MouseGetPos(&X, &Y)
    HPBarLightColor := PixelGetColor(X, Y)

    pGlobalBitmap := Gdip_CreateBitmap(149, 129)
    setBitmapColor(pGlobalBitmap, HPBarLightColor)
    Gdip_SaveBitmapToFile(pGlobalBitmap, tmpImage)
    picLightHP.Value := tmpImage
    Gdip_DisposeImage(pGlobalBitmap)
}

SaveHPBarColors(*) {
    global HPBarDarkColor, HPBarLightColor, bossHealthBarHashTable
    imageInfoString := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
    imageDataArray := StrSplit(imageInfoString, "&")

    newInfoString := HPBarDarkColor "&" HPBarLightColor

    tempIndex := 3
    loop (imageDataArray.Length - 2) {
        newInfoString .= "&" imageDataArray[tempIndex]
        tempIndex++
    }

    try FileDelete(A_ScriptDir "\Split_Images\image_info.txt")
    FileAppend(newInfoString, A_ScriptDir "\Split_Images\image_info.txt")

    bossHealthBarHashTable := findAllColorsBetween(HPBarDarkColor, HPBarLightColor)
}

SetBarLocation(*) {
    global HPBarDarkColor, HPBarLightColor
    KeyWait("LButton", "D")
    MouseGetPos(&X, &Y)
    otherX := X + 40
    otherY := Y + 10
    updateRect(X, Y, otherX, otherY)

    imageInfoString := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
    imageDataArray := StrSplit(imageInfoString, "&")

    newInfoString := HPBarDarkColor "&" HPBarLightColor "&" X "|" Y "|40|10"
    tempIndex := 4
    loop (imageDataArray.Length - 3) {
        newInfoString .= "&" imageDataArray[tempIndex]
        tempIndex++
    }

    try FileDelete(A_ScriptDir "\Split_Images\image_info.txt")
    FileAppend(newInfoString, A_ScriptDir "\Split_Images\image_info.txt")
}

; ===================================================
; Screenshot & Selection rectangle
; ===================================================

Capture(*) {
    global scshot, ScreenshotGui
    pBitmap := Gdip_BitmapFromScreen("0|0|" A_ScreenWidth "|" A_ScreenHeight)
    Gdip_SaveBitmapToFile(pBitmap, scshot)
    Gdip_DisposeImage(pBitmap)

    ; Create a temporary GUI for the screenshot
    ScreenshotGui := Gui("-Caption +AlwaysOnTop")
    ScreenshotGui.MarginX := 0
    ScreenshotGui.MarginY := 0
    ScreenshotGui.Add("Picture", "x0 y0 w" A_ScreenWidth " h" A_ScreenHeight, scshot)
    ScreenshotGui.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)

    btnCapture.Visible := false
    btnUncapture.Visible := true
    ImageMakerGui.Show()
}

Uncapture(*) {
    global ScreenshotGui
    if IsSet(ScreenshotGui) {
        ScreenshotGui.Destroy()
    }
    btnUncapture.Visible := false
    btnCapture.Visible := true
}

Picture(*) {
    global x1, y1, x2, y2
    LetUserSelectRect(&x1, &y1, &x2, &y2) ; Parameter passing with & (reference)
    setImages(x1, y1, x2, y2)
}

LetUserSelectRect(&outX1, &outY1, &outX2, &outY2) {
    local xorigin, yorigin

    lusr_return(*) {
        ; Dummy function to catch the click
    }

    ; Nested timer function in v2 accesses local variables!
    lusr_update() {
        local x, y
        MouseGetPos(&x, &y)

        if (x < xorigin) {
            outX1 := x, outX2 := xorigin
        } else {
            outX2 := x, outX1 := xorigin
        }

        if (y < yorigin) {
            outY1 := y, outY2 := yorigin
        } else {
            outY2 := y, outY1 := yorigin
        }
        updateRect(outX1, outY1, outX2, outY2)
    }

    Hotkey("*LButton", lusr_return, "On")
    KeyWait("LButton", "D")
    MouseGetPos(&xorigin, &yorigin)

    SetTimer(lusr_update, 10)
    KeyWait("LButton")

    Hotkey("*LButton", "Off")
    SetTimer(lusr_update, 0)
}

updateRect(rx1, ry1, rx2, ry2, r := 2) {
    global RectGuis, DPI_Ratio
    rr := r * DPI_Ratio
    SetTimer(closeRect, 0)

    w1 := (rx2 - rx1 + 2 * rr) / DPI_Ratio
    w2 := r
    h1 := r
    h2 := (ry2 - ry1 + rr) / DPI_Ratio

    RectGuis[1].Show("NA X" (rx1 - rr) " Y" (ry1 - rr) " W" w1 " H" h1)
    RectGuis[2].Show("NA X" (rx1 - rr) " Y" ry2 " W" w1 " H" h1)
    RectGuis[3].Show("NA X" (rx1 - rr) " Y" (ry1 - rr) " W" w2 " H" h2)
    RectGuis[4].Show("NA X" rx2 " Y" (ry1 - rr) " W" w2 " H" h2)

    SetTimer(closeRect, 8000)
}

closeRect() {
    global RectGuis
    loop 4 {
        RectGuis[A_Index].Hide()
    }
    SetTimer(closeRect, 0)
}

; ===================================================
; Image processing (Black/White)
; ===================================================

setImages(rx1, ry1, rx2, ry2) {
    global imageCoords, realImage, BnWImage, txtPW, txtTP
    wStr := rx2 - rx1
    hStr := ry2 - ry1

    txtTopNum.Value := ry1
    txtBotNum.Value := ry2
    txtLeftNum.Value := rx1
    txtRightNum.Value := rx2

    imageCoords := rx1 "|" ry1 "|" wStr "|" hStr
    pBitmap1 := Gdip_BitmapFromScreen(imageCoords)
    pBitmap2 := Gdip_CreateBitmap(wStr, hStr)

    x := 0, y := 0
    nWhite := 0, nBlack := 0
    totalPixels := 0

    loop hStr {
        loop wStr {
            color := (Gdip_GetPixel(pBitmap1, x, y) & 0x00F0F0F0)
            if (color == 0xF0F0F0) {
                Gdip_SetPixel(pBitmap2, x, y, 0xFFFFFFFF)
                nWhite += 1
            } else {
                Gdip_SetPixel(pBitmap2, x, y, 0xFF000000)
                nBlack += 1
            }
            x += 1
            totalPixels += 1
        }
        x := 0
        y += 1
    }

    Gdip_SaveBitmapToFile(pBitmap1, realImage)
    Gdip_DisposeImage(pBitmap1)
    Gdip_SaveBitmapToFile(pBitmap2, BnWImage)
    Gdip_DisposeImage(pBitmap2)

    ; Reload images (by re-assigning the value)
    picReal.Value := realImage
    picBnW.Value := BnWImage

    pWhite := (nBlack + nWhite > 0) ? Round(((nWhite / (nBlack + nWhite)) * 100), 2) : 0
    txtPW.Value := pWhite "%"
    txtTP.Value := totalPixels
}

; ===================================================
; Color Utilities
; ===================================================

OpenHPFinder(*) {
    ImageMakerGui.Opt("+Disabled")
    HPbarGui.Show()
    SetTimer(colorUndermouse, 10)

    ; Wait until window is closed
    WinWaitClose("Boss HP Bar Color Finder")

    SetTimer(colorUndermouse, 0)
    ToolTip() ; Hides the ToolTip
    ImageMakerGui.Opt("-Disabled")
    ImageMakerGui.Show()
}

colorUndermouse() {
    MouseGetPos(&VarX, &VarY)
    mouseColor := PixelGetColor(VarX, VarY)
    ToolTip(mouseColor)
}

Save(*) {
    global imageCoords, realImage, txtTP
    ImageMakerGui.Opt("+Disabled")

    ; Check if coordinates were even selected
    if (imageCoords == "0|0|1|1" || imageCoords == "") {
        MsgBox("No image has been selected.")
        ImageMakerGui.Opt("-Disabled")
        ImageMakerGui.Show()
        return
    }

    ib := InputBox("What would you like to name this image?", "Save Image")

    if (ib.Result == "Cancel" || ib.Result == "Timeout" || ib.Value == "") {
        ImageMakerGui.Opt("-Disabled")
        ImageMakerGui.Show()
        return
    }
    tempImageName := ib.Value

    ; 1. Copy temporary image to Split_Images folder (1 = allow overwrite)
    targetImagePath := A_ScriptDir "\Split_Images\" tempImageName ".png"
    try FileCopy(realImage, targetImagePath, 1)

    ; 2. Read image_info.txt
    infoFilePath := A_ScriptDir "\Split_Images\image_info.txt"
    imageInfoString := ""
    try imageInfoString := FileRead(infoFilePath)

    imageDataArray := StrSplit(imageInfoString, "&")
    newInfoString := ""
    imageExists := false

    ; The new data line: Name, coordinates, total pixel count (from GUI element txtTP)
    newLine := tempImageName "," imageCoords "," txtTP.Value

    ; 3. Check if image is already in text file
    loop imageDataArray.Length {
        currentLine := imageDataArray[A_Index]
        if (currentLine == "")
            continue

        currentName := StrSplit(currentLine, ",")[1]

        ; If name already exists, replace its line with new values
        if (currentName == tempImageName) {
            newInfoString .= (A_Index == 1 ? "" : "&") . newLine
            imageExists := true
        } else {
            ; Otherwise keep old line
            newInfoString .= (A_Index == 1 ? "" : "&") . currentLine
        }
    }

    ; 4. If name is completely new, append to end
    if (!imageExists) {
        newInfoString .= (newInfoString == "" ? "" : "&") . newLine
    }

    ; 5. Update text file
    try FileDelete(infoFilePath)
    FileAppend(newInfoString, infoFilePath)

    ;MsgBox("The image '" tempImageName "' was successfully saved!", "Success")

    ImageMakerGui.Opt("-Disabled")
    ImageMakerGui.Show()
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