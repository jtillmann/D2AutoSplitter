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
    ; FileAppend(A_NowUTC ": " text "`n", "logfile.txt")
}

; --- Ordner und Einstellungsdateien prüfen ---
; In v2 werden Funktionen wie DirExist() und DirCreate() verwendet
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

; --- Hotkeys laden ---
global hotkeySettingsString := ""
global hotKeySettingsArray := []

try {
    hotkeySettingsString := FileRead(A_ScriptDir "\Dependencies\settings.txt")
} catch {
    hotkeySettingsString := ""
}

hotKeySettingsArray := StrSplit(hotkeySettingsString, "&")

; Dynamische Variablen-Zuweisung (Hotkey1, Hotkey2...) muss in v2
; über ein Array oder eine Map gelöst werden, da dynamische Variablennamen
; wie 'Hotkey%A_Index%' nicht mehr existieren.
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

; ===================================================
; Globale GUI-Objekte (Vorbereitung für v2 Scope)
; ===================================================
global MainGui := ""
global ImageMakerGui := ""
global HPbarGui := ""
global ScreenshotGui := ""
; ===================================================
; Globale Deklarationen für Split Image Maker
; ===================================================
global realImage := A_ScriptDir "\Dependencies\real_image.png"
global BnWImage := A_ScriptDir "\Dependencies\BnW.png"
global scshot := A_ScriptDir "\Dependencies\fullScreenshot.png"
global tmpImage := A_ScriptDir "\Dependencies\tmp.png"

; GDI+ Initialisierung (v2 Syntax)
; Wir speichern das Token global, damit wir es beim Beenden sauber schließen können.
global pToken := Gdip_Startup()

; Initiales Erstellen von Dummy-Bildern
; In v2 sind Funktionen wie Gdip_BitmapFromScreen Ausdrücke
pBitmap := Gdip_BitmapFromScreen("0|0|1|1")
Gdip_SaveBitmapToFile(pBitmap, realImage)
Gdip_SaveBitmapToFile(pBitmap, BnWImage)
Gdip_DisposeImage(pBitmap)

global x1 := 0, y1 := 0, x2 := 0, y2 := 0
global w := 0, h := 0, total := 0
global imageCoords := "0|0|1|1"

; Bild-Informationen laden
try {
    imageInfoString := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
} catch {
    imageInfoString := "0x000000&0x000000&0|0|1|1"
}

imageDataArray := StrSplit(imageInfoString, "&")
global HPBarDarkColor := imageDataArray[1]
global HPBarLightColor := imageDataArray[2]

; Boss Health Bar Colors (Erfordert die Funktion 'findAllColorsBetween')
global bossHealthBarHashTable := Map() ; In v2 nutzen wir Maps für HashTables
if (imageDataArray.Length >= 2) {
    bossHealthBarHashTable := findAllColorsBetween(imageDataArray[1], imageDataArray[2])
}

; Split Manager Index
global splitManagerIndex := 0
global isSplitManagerOpen := 0
; ===================================================

; ===================================================
; GUI für den Haupt-Autosplitter
; ===================================================

; Tray Icon setzen
if FileExist(A_ScriptDir "\31048.ico") {
    TraySetIcon(A_ScriptDir "\31048.ico")
}

; GUI Objekt erstellen
MainGui := Gui("", "Destiny 2 AutoSplitter")
MainGui.OnEvent("Close", AutoSplitterGuiClose)
MainGui.BackColor := "222222"

; Hintergrundbild (falls vorhanden)
if FileExist(A_ScriptDir "\backgroundimage.png") {
    MainGui.Add("Picture", "x0 y0 w721 h520", A_ScriptDir "\backgroundimage.png")
}

MainGui.SetFont("s6 cWhite")
MainGui.Add("Text", "x8 y432 w125 h15 +0x200", "Made By A2TC - Improved By Scope")

MainGui.SetFont("s9", "Segoe UI")
MainGui.Add("GroupBox", "x480 y60 w230 h200")
MainGui.Add("GroupBox", "x480 y270 w230 h170", "Hotkeys")

; --- Hotkeys und Zuweisungen ---
; In v2 speichern wir die Control-Objekte in Variablen, um später darauf zuzugreifen
tmpVar1 := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""
if (tmpVar1 != "") {
    try Hotkey("$" tmpVar1, BtnStartClick)
}
hkControl1 := MainGui.Add("Hotkey", "x570 y290 w130 h21 vHotKey1", tmpVar1)

tmpVar2 := (hotKeySettingsArray.Has(2)) ? hotKeySettingsArray[2] : ""
if (tmpVar2 != "") {
    try Hotkey("$" tmpVar2, ResetAutoSplitter)
}
hkControl2 := MainGui.Add("Hotkey", "x570 y320 w130 h21 vHotKey2", tmpVar2)

tmpVar3 := (hotKeySettingsArray.Has(3)) ? hotKeySettingsArray[3] : ""
if (tmpVar3 != "") {
    try Hotkey("$" tmpVar3, SkipSplit)
}
hkControl3 := MainGui.Add("Hotkey", "x570 y380 w130 h21 vHotKey3", tmpVar3)

tmpVar4 := (hotKeySettingsArray.Has(4)) ? hotKeySettingsArray[4] : ""
if (tmpVar4 != "") {
    try Hotkey("$" tmpVar4, UndoSplit)
}
hkControl4 := MainGui.Add("Hotkey", "x570 y350 w130 h21 vHotKey4", tmpVar4)

; --- Buttons und Event-Handler ---
MainGui.Add("Button", "x10 y10 w120 h30", "Create New Splits").OnEvent("Click", SaveSplitFileEmpty)
MainGui.Add("Button", "x140 y10 w100 h30", "Open Splits").OnEvent("Click", LoadSplitsToUse)
txtLoadedSplits := MainGui.Add("Text", "x250 y12 w150 h23 +0x200", "") ; vNameOfLoadedSplits

btnEditSplits := MainGui.Add("Button", "x450 y10 w100 h30", "Edit Splits")
btnEditSplits.OnEvent("Click", OpenSplitManager)
btnEditSplits.Visible := false ; Ersetzt GuiControl, Hide

MainGui.Add("Button", "x560 y10 w150 h30", "Create Split Image").OnEvent("Click", OpenSplitImageMaker)

; --- Status und Anzeige ---
txtTimer := MainGui.Add("Text", "x10 y70 w300 h300 +0x200 +Center +Border", "") ; vtimerText
picCurrentSplit := MainGui.Add("Picture", "x10 y70 w300 h300 +Border", "") ; vCurrentSplitImage

MainGui.Add("Text", "x490 y290 w60 h20 +0x200", "Start/Split")
MainGui.Add("Text", "x490 y320 w60 h20 +0x200", "Reset")
MainGui.Add("Text", "x490 y350 w60 h20 +0x200", "Skip Split")
MainGui.Add("Text", "x490 y380 w60 h20 +0x200", "Undo Split")
MainGui.Add("Button", "x640 y410 w60 h20", "Set").OnEvent("Click", Sethotkeys)

btnStart := MainGui.Add("Button", "x490 y180 w210 h40", "Start")
btnStart.OnEvent("Click", BtnStartClick)

btnReset := MainGui.Add("Button", "x490 y130 w210 h40", "Reset")
btnReset.OnEvent("Click", StopOnlyAutoSplitter)
MainGui.Add("Button", "x600 y80 w100 h40", "Next >").OnEvent("Click", SkipOnlyAutoSplitter)
MainGui.Add("Button", "x490 y80 w100 h40", "< Previous").OnEvent("Click", UndoOnlyAutoSplitter)

chkStartFirst := MainGui.Add("CheckBox", "x490 y227 w17 h24", "") ; vStartOnFirstInput
txtStartFirstTitle := MainGui.Add("Text", "x510 y230 w150 h20 +0x200", "Start waits for First Input")
global txtWaitingFirstInput := MainGui.Add("Text", "x10 y55 w300 h20 cRed Hidden", "Waiting for First Input...")

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
; GUI für Split Image Maker
; ===================================================
global ImageMakerGui := Gui("", "Split Image Maker")
ImageMakerGui.OnEvent("Close", (*) => ImageMakerGui.Hide())

ImageMakerGui.Add("GroupBox", "x12 y-1 w140 h540", "Settings")

; Buttons für Screenshot-Funktionen
btnCapture := ImageMakerGui.Add("Button", "x22 y15 w120 h50", "Freeze Screen")
btnCapture.OnEvent("Click", Capture)
btnUncapture := ImageMakerGui.Add("Button", "x22 y15 w120 h50 +Hidden", "Unfreeze Screen")
btnUncapture.OnEvent("Click", Uncapture)

; Hotkey Steuerung
tmpVarHK5 := (hotKeySettingsArray.Length >= 5) ? hotKeySettingsArray[5] : ""
if (tmpVarHK5 != "") {
    try Hotkey("$" tmpVarHK5, Capture)
}
hkCapture := ImageMakerGui.Add("Hotkey", "x27 y70 w110 h20", tmpVarHK5)
ImageMakerGui.Add("Button", "x52 y92 w60 h23", "Set").OnEvent("Click", Sethotkeys)

ImageMakerGui.Add("Button", "x22 y115 w120 h50", "Select Area").OnEvent("Click", Picture)
ImageMakerGui.Add("Button", "x22 y165 w120 h50", "Save Current Image").OnEvent("Click", Save)
ImageMakerGui.Add("Button", "x22 y480 w120 h50", "Open Boss HP Bar Color Finder").OnEvent("Click", OpenHPFinder)

; --- Koordinaten Anpassung (Top, Bottom, Left, Right) ---
; Hilfsfunktion zur Vermeidung des "global" Fehlers
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

    ; Aktualisiere die Text-Anzeigen in der GUI
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

; Bildanzeigen
ImageMakerGui.Add("GroupBox", "x162 y-1 w530 h510", "Black and White Pixels")
ImageMakerGui.Add("GroupBox", "x702 y-1 w530 h510", "Actual Image")
picReal := ImageMakerGui.Add("Picture", "x712 y19 w510 h480", realImage)
picBnW := ImageMakerGui.Add("Picture", "x172 y19 w510 h480", BnWImage)

txtPW := ImageMakerGui.Add("Text", "x360 y520 w50 h20", "0")
txtTP := ImageMakerGui.Add("Text", "x580 y520 w150 h20", "0")

; ===================================================
; GUI für Boss HP Bar Color Finder
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
; Auswahl-Rechteck GUIs
; ===================================================
global RectGuis := []
loop 4 {
    G := Gui("-Caption +ToolWindow +AlwaysOnTop")
    G.BackColor := "Red"
    RectGuis.Push(G)
}

; ===================================================
; Haupt-GUI anzeigen & Hotkeys
; ===================================================
MainGui.Show("w720 h450")

; Hotkeys für Spiel-Inputs (w, a, s, d etc.)
; Diese rufen die Funktion 'InputKeyPressed' auf
MovementKeys := ["w", "a", "s", "d", "Space", "3", "WheelDown", "WheelUp", "e"]
for key in MovementKeys {
    Hotkey("~$" . key, (*) => InputKeyPressed())
    Hotkey("~+$" . key, (*) => InputKeyPressed()) ; Auch für Shift+Taste
}

; ===================================================
; Hotkey-Einstellungen speichern und setzen
; ===================================================

Sethotkeys(*) {
    global hotKeySettingsArray, hotkeySettingsString

    ; Werte aus den GUI-Objekten auslesen (v2 nutzt .Value)
    newHKs := [hkControl1.Value, hkControl2.Value, hkControl3.Value, hkControl4.Value, hkCapture.Value]

    loop newHKs.Length {
        idx := A_Index
        newKey := newHKs[idx]
        oldKey := (hotKeySettingsArray.Has(idx)) ? hotKeySettingsArray[idx] : ""

        if (newKey != "") {
            ; Alten Hotkey deaktivieren, falls vorhanden
            if (oldKey != "") {
                try Hotkey("$" oldKey, "Off")
            }

            ; Neuen Hotkey setzen
            hotKeySettingsArray[idx] := newKey

            ; Funktion zuweisen basierend auf Index
            callback := (idx = 1) ? StartKeyPressed :
                (idx = 2) ? ResetAutoSplitter :
                    (idx = 3) ? SkipSplit :
                        (idx = 4) ? UndoSplit : Capture

            try Hotkey("$" newKey, callback)
        }
    }

    ; String für Datei zusammensetzen
    hotkeySettingsString := ""
    for k, v in hotKeySettingsArray {
        hotkeySettingsString .= (k = 1 ? "" : "&") . v
    }

    try FileDelete(A_ScriptDir "\Dependencies\settings.txt")
    FileAppend(hotkeySettingsString, A_ScriptDir "\Dependencies\settings.txt")
}

SaveSplitFileEmpty(*) {
    global SelectedFile

    ; Hauptfenster sperren, während das Dialogfenster offen ist
    MainGui.Opt("+Disabled")

    ; Wir nutzen einen Loop anstelle des alten "Goto, inputtingSplitFileName"
    loop {
        ib := InputBox("What would you like to name your Splits?", "Create New Splits")

        ; Wenn der User auf "Abbrechen" klickt oder das Fenster schließt
        if (ib.Result == "Cancel" || ib.Result == "Timeout") {
            break
        }

        tempSplitFileName := ib.Value ".txt"
        targetFile := A_WorkingDir "\Split_Files\" tempSplitFileName

        ; Prüfen, ob die Datei schon existiert
        if FileExist(targetFile) {
            ; MsgBox gibt in v2 direkt den gedrückten Button als String zurück
            if (MsgBox("A split file with this name already exists.`nWould you like to overwrite it?", "Warning",
                "YesNo") == "No") {
                continue ; Startet den Loop von vorne (neue Eingabe)
            }
        }

        ; Datei anlegen und mit Standardwerten füllen
        stringToSaveToFile := "None,None,0,0.9,7"
        try FileDelete(targetFile)
        FileAppend(stringToSaveToFile, targetFile)

        ; Die neue Datei direkt laden
        LoadSplitsFile(targetFile)
        break ; Schleife beenden, da wir erfolgreich waren
    }

    ; Hauptfenster wieder entsperren
    MainGui.Opt("-Disabled")
    MainGui.Show()
}

; ===================================================
; Split-Dateien laden und speichern
; ===================================================

; ===================================================
; Split Manager öffnen & Bilder prüfen
; ===================================================

OpenSplitManager(*) {
    global SplitManagerGui, MainGui, lvSplits, ddlSplitImage, SelectedFile
    ; ==========================================================
    ; NEU: Den aktuellen Run sofort stoppen und zurücksetzen!
    ; (Falls deine Funktion z.B. BtnResetClick heißt, ändere das hier)
    ; ==========================================================
    try StopOnlyAutoSplitter()

    MainGui.Opt("+Disabled")

    ; 1. Dropdown-Liste mit frischen Bildern füllen
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

    ; Altes Dropdown leeren und mit der neuen Liste füllen
    ddlSplitImage.Delete()
    ddlSplitImage.Add(frischeBilder)

    ; 2. Das ListView (die Tabelle) leeren und mit den Splits füllen
    lvSplits.Delete()

    if (SelectedFile != "" && FileExist(SelectedFile)) {
        splitText := FileRead(SelectedFile)
        loop parse, splitText, "&" {
            if (A_LoopField == "")
                continue

            zeilenDaten := StrSplit(A_LoopField, ",")
            ; Wenn die Zeile gültig ist (Name, Bild, Dummy, Thresh, Delay)
            if (zeilenDaten.Length >= 5) {
                lvSplits.Add("", zeilenDaten[1], zeilenDaten[2], zeilenDaten[3], zeilenDaten[4], zeilenDaten[5])
            }
        }
    }
    ; NEU: Sicherstellen, dass die Felder eingeklappt sind und das Fenster schrumpft
    ToggleEditArea(false)

    ; GUI anzeigen
    SplitManagerGui.Show()
}

; ===================================================
; Split Manager: UI Toggle Hilfsfunktion
; ===================================================
ToggleEditArea(show, mode := "") {
    global splitEditMode := mode

    ; 1. Eingabefelder ein- oder ausblenden
    lblSplitName.Visible := show, edSplitName.Visible := show
    lblSplitImage.Visible := show, ddlSplitImage.Visible := show
    chkSplitDummy.Visible := show, lblSplitThresh.Visible := show
    edSplitThresh.Visible := show, lblSplitDelay.Visible := show, edSplitDelay.Visible := show

    ; 2. Save und Cancel sind IMMER da, wenn die Felder sichtbar sind
    btnSaveEdit.Visible := show
    btnCancelEdit.Visible := show

    ; 3. Edit-Buttons (Save As New, Delete, Up, Down) nur im "Edit"-Modus zeigen
    showEditButtons := (show && mode == "Edit")
    btnSaveAsNew.Visible := showEditButtons
    btnDeleteEdit.Visible := showEditButtons
    btnUpEdit.Visible := showEditButtons
    btnDownEdit.Visible := showEditButtons

    ; 4. Wenn wir ausblenden oder einen NEUEN Split anlegen, Felder leeren
    if (!show || mode == "Add") {
        edSplitName.Value := ""
        try ddlSplitImage.Choose("None")
        chkSplitDummy.Value := 0
        edSplitThresh.Value := "0.95"
        edSplitDelay.Value := "0"

        ; Auswahl im ListView aufheben
        if (mode != "Edit")
            lvSplits.Modify(0, "-Select -Focus")
    }

    SplitManagerGui.Show("AutoSize")
}
; ===================================================
; Split Manager: ListView Button-Events
; ===================================================

; Klick auf eine Zeile in der Liste

; Klick auf "Add New Split" (Hauptmenü)

; Klick auf "Save"

; Klick auf "Save As New"

; Klick auf "Delete"

; ===================================================
; Split Image Maker öffnen
; ===================================================

OpenSplitImageMaker(*) {
    global ImageMakerGui, MainGui, ScreenshotGui

    ; Hauptfenster sperren, damit man nicht parallel darin klicken kann
    MainGui.Opt("+Disabled")

    ; Image Maker GUI zentriert und in der richtigen Größe anzeigen
    ImageMakerGui.Show("Center h550 w1244")

    ; Das Skript pausiert hier, bis das Fenster "Split Image Maker" geschlossen wird
    WinWaitClose("Split Image Maker")

    ; Hauptfenster wieder freigeben
    MainGui.Opt("-Disabled")

    ; Falls die Screenshot-Oberfläche noch existiert/offen ist, abbrechen (verstecken)
    if (Type(ScreenshotGui) == "Gui") {
        ScreenshotGui.Hide()
    }

    ; Hauptfenster wieder in den Vordergrund holen
    MainGui.Show()
}

checkForDeletedImages() {
    try {
        imageInfoString := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
    } catch {
        return
    }

    imageDataArray := StrSplit(imageInfoString, "&")
    newInfoString := ""

    i := 1
    ; While-Schleife ist sicherer, da wir Elemente aus dem Array löschen könnten
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
                ; Wenn das Bild physisch gelöscht wurde, aus dem Array entfernen
                imageDataArray.RemoveAt(i)
                continue ; Wir erhöhen 'i' nicht, da das nächste Element nachgerückt ist
            } else {
                newInfoString .= "&" existingImageData
            }
        }
        i++
    }

    ; Aktualisierte Liste speichern
    try FileDelete(A_ScriptDir "\Split_Images\image_info.txt")
    FileAppend(newInfoString, A_ScriptDir "\Split_Images\image_info.txt")
}

LoadSplitsToUse(*) {
    global SelectedFile
    MainGui.Opt("+Disabled") ; Fenster sperren

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

        ; GUI aktualisieren
        splitName := RegExReplace(path, ".*\\") ; Extrahiert Dateinamen
        txtLoadedSplits.Value := splitName
        btnEditSplits.Visible := true
    } catch {
        MsgBox("Fehler beim Laden der Datei.")
    }
}

; ===================================================
; Split Manager: ListView Button-Events
; ===================================================

BtnAddSplitToList(*) {
    global edSplitName, ddlSplitImage, chkSplitDummy, edSplitThresh, edSplitDelay, lvSplits

    name := edSplitName.Value
    if (name == "") {
        MsgBox("Bitte gib dem Split einen Namen!")
        return
    }

    image := ddlSplitImage.Text
    dummy := chkSplitDummy.Value ? "1" : "0"
    thresh := edSplitThresh.Value
    delay := edSplitDelay.Value

    ; Einfach ans Ende der Liste anhängen
    lvSplits.Add("", name, image, dummy, thresh, delay)

    ; Textfeld für den Namen leeren, damit man schnell den nächsten eintragen kann
    edSplitName.Value := ""
}

BtnUpdateSplitInList(*) {
    global edSplitName, ddlSplitImage, chkSplitDummy, edSplitThresh, edSplitDelay, lvSplits

    row := lvSplits.GetNext(0) ; Ausgewählte Zeile finden
    if (row == 0) {
        MsgBox("Bitte wähle zuerst einen Split in der Liste aus, den du aktualisieren möchtest.")
        return
    }

    name := edSplitName.Value
    image := ddlSplitImage.Text
    dummy := chkSplitDummy.Value ? "1" : "0"
    thresh := edSplitThresh.Value
    delay := edSplitDelay.Value

    ; Die ausgewählte Zeile mit den neuen Werten überschreiben
    lvSplits.Modify(row, "", name, image, dummy, thresh, delay)
}

BtnRemoveSplitFromList(*) {
    global lvSplits

    row := lvSplits.GetNext(0)
    if (row == 0) {
        return
    }

    ; Zeile einfach löschen - AHK rückt den Rest automatisch auf!
    lvSplits.Delete(row)
}

BtnMoveSplitUp(*) {
    global lvSplits

    row := lvSplits.GetNext(0)
    ; Wenn nichts ausgewählt ist oder wir schon ganz oben sind, mach nichts
    if (row <= 1)
        return

    ; Daten der aktuellen Zeile holen
    c1 := lvSplits.GetText(row, 1), c2 := lvSplits.GetText(row, 2)
    c3 := lvSplits.GetText(row, 3), c4 := lvSplits.GetText(row, 4)
    c5 := lvSplits.GetText(row, 5)

    ; Daten der Zeile darüber holen
    p1 := lvSplits.GetText(row - 1, 1), p2 := lvSplits.GetText(row - 1, 2)
    p3 := lvSplits.GetText(row - 1, 3), p4 := lvSplits.GetText(row - 1, 4)
    p5 := lvSplits.GetText(row - 1, 5)

    ; Werte tauschen
    lvSplits.Modify(row - 1, "", c1, c2, c3, c4, c5)
    lvSplits.Modify(row, "", p1, p2, p3, p4, p5)

    ; Die Markierung mit nach oben nehmen
    lvSplits.Modify(row - 1, "Select Focus")
    lvSplits.Modify(row, "-Select -Focus")
}

BtnMoveSplitDown(*) {
    global lvSplits

    row := lvSplits.GetNext(0)
    ; Wenn nichts ausgewählt ist oder wir schon ganz unten sind
    if (row == 0 || row == lvSplits.GetCount())
        return

    ; Daten der aktuellen Zeile
    c1 := lvSplits.GetText(row, 1), c2 := lvSplits.GetText(row, 2)
    c3 := lvSplits.GetText(row, 3), c4 := lvSplits.GetText(row, 4)
    c5 := lvSplits.GetText(row, 5)

    ; Daten der Zeile darunter
    n1 := lvSplits.GetText(row + 1, 1), n2 := lvSplits.GetText(row + 1, 2)
    n3 := lvSplits.GetText(row + 1, 3), n4 := lvSplits.GetText(row + 1, 4)
    n5 := lvSplits.GetText(row + 1, 5)

    ; Werte tauschen
    lvSplits.Modify(row + 1, "", c1, c2, c3, c4, c5)
    lvSplits.Modify(row, "", n1, n2, n3, n4, n5)

    ; Markierung mit nach unten nehmen
    lvSplits.Modify(row + 1, "Select Focus")
    lvSplits.Modify(row, "-Select -Focus")
}

; ===================================================
; Speichern und Schließen
; ===================================================

; ===================================================
; Haupt-Logik des AutoSplitters
; ===================================================
BtnStartClick(*) {
    global isWaitingForFirstInput, chkStartFirst, btnStart, txtWaitingFirstInput, btnReset

    ; Wenn wir bereits warten, passiert beim erneuten Klicken nichts
    if (isWaitingForFirstInput)
        return

    ; Wenn das Häkchen gesetzt ist, gehen wir in den "Warte-Modus"
    isWaitingForFirstInput := true
    if (chkStartFirst.Value == 1) {

        btnReset.focus()

        ; GUI umschalten
        btnStart.Visible := false
        chkStartFirst.Visible := false
        txtWaitingFirstInput.Visible := true

        return ; WICHTIG: Hier brechen wir ab! Der echte Start passiert noch nicht.
    }

    ; Wenn das Häkchen NICHT gesetzt ist, sofort ganz normal starten:
    ExecuteActualStart()
}

ExecuteActualStart(*) {
    global currentlyLoadedSplits, currentlyLoadedSplitIndex, breakLoop, nLoops
    global splitButton, StartOnFirstInput

    if (currentlyLoadedSplits.Length == 0 || currentlyLoadedSplits[1] == "") {
        MsgBox("Bitte zuerst eine Split-Datei laden!")
        return
    }

    currentlyLoadedSplitIndex := 1
    GUIupdate()

    ; Controls verstecken/zeigen
    chkStartFirst.Visible := false
    txtStartFirstTitle.Visible := false

    breakLoop := 0
    nLoops := 0

    ; Timer starten (v2 nutzt Funktionsreferenzen)
    SetTimer(countLoops, 1000)

    ; Hotkey während des Laufs deaktivieren
    if (hotKeySettingsArray.Has(1) && hotKeySettingsArray[1] != "") {
        try Hotkey("$" hotKeySettingsArray[1], "Off")
    }

    ; ... (Anfang von StartAutoSplitter bleibt gleich) ...
    ; Füge imageDataArray ganz oben bei den globals der Funktion hinzu!
    global currentlyLoadedSplits, currentlyLoadedSplitIndex, breakLoop, nLoops
    global splitButton, StartOnFirstInput, imageDataArray

    ; ...

    loop {
        if (breakLoop)
            break

        txtTimer.Value := ""
        previousSplitWasBossDeath := 0

        currentSplitData := StrSplit(currentlyLoadedSplits[currentlyLoadedSplitIndex], ",")

        if (currentlyLoadedSplitIndex > 1) {
            prevData := StrSplit(currentlyLoadedSplits[currentlyLoadedSplitIndex - 1], ",")
            if (prevData.Has(2) && prevData[2] == "Boss Death")
                previousSplitWasBossDeath := 1
        }

        currentSplitImageName := currentSplitData[2]

        ; 1. FIX: Bildvorschau aktualisieren
        imgFilePath := A_ScriptDir "\Split_Images\" currentSplitImageName ".png"

        if FileExist(imgFilePath) {
            ; a) Bild ganz normal laden (OHNE den *w *h String)
            picCurrentSplit.Value := imgFilePath

            ; b) Das Control sofort auf die Original-Werte festnageln
            ; (Ersetze 200 und 150 hier wieder durch deine echten Werte aus Abschnitt 5!)
            picCurrentSplit.Move(, , 300, 300)

            ; c) Wieder sichtbar machen (falls es vorher durch Boss Death versteckt war)
            picCurrentSplit.Visible := true
        } else {
            ; Bei Boss Death etc. unsichtbar machen
            picCurrentSplit.Visible := false
        }
        txtImageName.Value := currentSplitImageName

        ; 2. FIX: Globale Variable imageDataArray nutzen, damit die Boss-Funktionen die Koordinaten finden!
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
            MsgBox("Kein Bild für Split " currentlyLoadedSplitIndex " ausgewählt.")
            StopOnlyAutoSplitter()
            return
        }

        ; Suchfunktion bestimmen
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

        ; Suche starten
        lookingFor(funcToUse, currentSplitData[4], previousSplitWasBossDeath, activeImageInfo, pixelArray)

        if (currentlyLoadedSplitIndex > currentlyLoadedSplits.Length || currentlyLoadedSplitIndex < 1)
            break
    }

    if (hotKeySettingsArray.Has(1) && hotKeySettingsArray[1] != "") {
        try Hotkey("$" hotKeySettingsArray[1], "On")
    }
    StopOnlyAutoSplitter()
}

; ===================================================
; Hotkey-Eingabe Reaktionen
; ===================================================
HandleFirstInput() {
    global isWaitingForFirstInput, btnStart, chkStartFirst, txtWaitingFirstInput

    ; Reagiert NUR, wenn wir vorher auf "Start" gedrückt haben und die Checkbox an war
    if (isWaitingForFirstInput) {
        isWaitingForFirstInput := false ; Sofort beenden, damit es nicht doppelt auslöst

        ; GUI wieder in den Normalzustand versetzen
        txtWaitingFirstInput.Visible := false
        btnStart.Visible := true
        chkStartFirst.Visible := true

        ; Jetzt den eigentlichen Startbefehl ausführen!
        ExecuteActualStart()
    }
}

InputKeyPressed(*) {
    global currentlyLoadedSplitIndex, hotKeySettingsArray, isWaitingForFirstInput

    ; Das aktive Fenster abfragen (v2 Syntax)
    activeWindow := WinGetTitle("A")

    WriteLog("InputKeyPressed " currentlyLoadedSplitIndex " " isWaitingForFirstInput " " activeWindow)

    if (isWaitingForFirstInput && currentlyLoadedSplitIndex == 999 && activeWindow == "Destiny 2") {
        WriteLog("InputKeyPressed! Starting...")

        splitKey := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""
        if (splitKey != "") {
            Send("{" splitKey "}")
        }

        ; In v2 ersetzen wir 'GoSub StartAutoSplitter' durch einen simplen Funktionsaufruf
        ExecuteActualStart()
    }
}

StartKeyPressed(*) {
    global hotKeySettingsArray
    splitKey := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""

    WriteLog("StartKeyPressed " splitKey)

    if (splitKey != "") {
        Send("{" splitKey "}")
    }
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

; ===================================================
; Timer Funktionen
; ===================================================

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

    ; Dynamischer Funktionsaufruf in v2
    ; Wir nutzen %findFunc% als Funktionsobjekt oder rufen es per Name auf
    try {
        pCorrect := %findFunc%(currentSplitImageInfo)
    } catch {
        return ; Falls die Funktion noch nicht definiert ist
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
            UndoSplit() ; Funktionsaufruf statt GoTo
        }
    }

    global nLoops += 1
}

; ===================================================
; Split-Verarbeitung
; ===================================================

handleSplit(pCorrect) {
    global currentlyLoadedSplitIndex, waitingForNextSplit, timerText, breakLoop
    global currentlyLoadedSplits, hotKeySettingsArray

    ; Aktuelle Daten holen
    currentData := StrSplit(currentlyLoadedSplits[currentlyLoadedSplitIndex], ",")

    ; Wenn kein Dummy-Split (Index 3 ist 0), dann Split-Taste senden
    if (currentData.Has(3) && currentData[3] == "0") {
        splitKey := (hotKeySettingsArray.Has(1)) ? hotKeySettingsArray[1] : ""
        if (splitKey != "")
            Send("{" splitKey "}")
    }

    ; Delay berechnen (Index 5 ist Delay in Sekunden)
    timerText := (currentData.Has(5) ? currentData[5] : 0) * 1000

    if (currentData.Has(2) && currentData[2] == "Boss Death")
        timerText := 0

    currentlyLoadedSplitIndex += 1
    waitingForNextSplit := 1
    breakLoop := 0

    SetTimer(waitForNextSplit, 100)

    ; Warten auf Timer-Ablauf
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

; ===================================================
; GUI Updates & Split-Steuerung
; ===================================================

GUIupdate() {
    global currentlyLoadedSplits, currentlyLoadedSplitIndex

    ; Sicherheitsabfragen, um Out-of-Bounds Fehler zu vermeiden
    hPrev := (currentlyLoadedSplitIndex > 1 && currentlyLoadedSplits.Has(currentlyLoadedSplitIndex - 1)) ? StrSplit(
        currentlyLoadedSplits[currentlyLoadedSplitIndex - 1], ",")[1] : ""
    hCurr := (currentlyLoadedSplits.Has(currentlyLoadedSplitIndex)) ? StrSplit(currentlyLoadedSplits[
        currentlyLoadedSplitIndex], ",")[1] : ""
    hNext := (currentlyLoadedSplits.Has(currentlyLoadedSplitIndex + 1)) ? StrSplit(currentlyLoadedSplits[
        currentlyLoadedSplitIndex + 1], ",")[1] : ""

    ; Objekte aktualisieren
    txtPrev.Value := hPrev
    txtCurr.Value := hCurr
    txtNext.Value := hNext
}

ResetAutoSplitter(*) {
    global hotKeySettingsArray
    resetBtnStr := (hotKeySettingsArray.Has(2)) ? hotKeySettingsArray[2] : ""

    if (resetBtnStr != "") {
        Send("{" resetBtnStr "}")
    }

    btnStart.Text := "Start"
    StopOnlyAutoSplitter()
}

StopOnlyAutoSplitter(*) {
    global isWaitingForFirstInput, btnStart, chkStartFirst, txtWaitingFirstInput

    ; Falls wir im Warte-Modus waren, diesen sofort abbrechen und GUI zurücksetzen
    if (isWaitingForFirstInput) {
        isWaitingForFirstInput := false
        txtWaitingFirstInput.Visible := false
        btnStart.Visible := true
        chkStartFirst.Visible := true
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

    updateCorrectStats()
}

SkipSplit(*) {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex, hotKeySettingsArray
    skipBtnStr := (hotKeySettingsArray.Has(3)) ? hotKeySettingsArray[3] : ""

    if (skipBtnStr != "") {
        Send("{" skipBtnStr "}")
    }

    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex += 1
    GUIupdate()
}

SkipOnlyAutoSplitter(*) {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex
    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex += 1
    GUIupdate()
}

UndoSplit(*) {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex, hotKeySettingsArray
    undoBtnStr := (hotKeySettingsArray.Has(4)) ? hotKeySettingsArray[4] : ""

    if (undoBtnStr != "") {
        Send("{" undoBtnStr "}")
    }

    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex -= 1
    GUIupdate()
}

UndoOnlyAutoSplitter(*) {
    global breakLoop, breakLoopLF, currentlyLoadedSplitIndex
    breakLoop := 1
    breakLoopLF := 1
    currentlyLoadedSplitIndex -= 1
    GUIupdate()
}

; ===================================================
; Image Maker: Farben & Koordinaten setzen
; ===================================================

SetDarkColor(*) {
    global HPBarDarkColor, tmpImage, pToken
    KeyWait("LButton", "D")
    MouseGetPos(&X, &Y)
    HPBarDarkColor := PixelGetColor(X, Y) ; In v2 ist das Standardformat RGB

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
; Screenshot & Auswahl-Rechteck
; ===================================================

Capture(*) {
    global scshot, ScreenshotGui
    pBitmap := Gdip_BitmapFromScreen("0|0|" A_ScreenWidth "|" A_ScreenHeight)
    Gdip_SaveBitmapToFile(pBitmap, scshot)
    Gdip_DisposeImage(pBitmap)

    ; Erstelle eine temporäre GUI für den Screenshot
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
    LetUserSelectRect(&x1, &y1, &x2, &y2) ; Parameter-Übergabe mit & (Referenz)
    setImages(x1, y1, x2, y2)
}

LetUserSelectRect(&outX1, &outY1, &outX2, &outY2) {
    local xorigin, yorigin

    lusr_return(*) {
        ; Dummy-Funktion, um den Klick abzufangen
    }

    ; Die verschachtelte Timer-Funktion in v2 greift auf die lokalen Variablen zu!
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
; Bildverarbeitung (Schwarz/Weiß)
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

    ; Bilder neu laden (indem man den Wert erneut zuweist)
    picReal.Value := realImage
    picBnW.Value := BnWImage

    pWhite := (nBlack + nWhite > 0) ? Round(((nWhite / (nBlack + nWhite)) * 100), 2) : 0
    txtPW.Value := pWhite "%"
    txtTP.Value := totalPixels
}

; ===================================================
; Farb-Utilities
; ===================================================

OpenHPFinder(*) {
    ImageMakerGui.Opt("+Disabled")
    HPbarGui.Show()
    SetTimer(colorUndermouse, 10)

    ; Warten bis Fenster geschlossen wird
    WinWaitClose("Boss HP Bar Color Finder")

    SetTimer(colorUndermouse, 0)
    ToolTip() ; Versteckt den ToolTip
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

    ; Prüfen, ob überhaupt Koordinaten gezogen wurden
    if (imageCoords == "0|0|1|1" || imageCoords == "") {
        MsgBox("Es wurde kein Bild ausgewählt.")
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

    ; 1. Das temporäre Bild in den Split_Images Ordner kopieren (1 = überschreiben erlauben)
    targetImagePath := A_ScriptDir "\Split_Images\" tempImageName ".png"
    try FileCopy(realImage, targetImagePath, 1)

    ; 2. image_info.txt auslesen
    infoFilePath := A_ScriptDir "\Split_Images\image_info.txt"
    imageInfoString := ""
    try imageInfoString := FileRead(infoFilePath)

    imageDataArray := StrSplit(imageInfoString, "&")
    newInfoString := ""
    imageExists := false

    ; Die neue Datenzeile: Name, Koordinaten, Gesamtpixelzahl (aus dem GUI-Element txtTP)
    newLine := tempImageName "," imageCoords "," txtTP.Value

    ; 3. Überprüfen, ob das Bild schon in der Textdatei steht
    loop imageDataArray.Length {
        currentLine := imageDataArray[A_Index]
        if (currentLine == "")
            continue

        currentName := StrSplit(currentLine, ",")[1]

        ; Falls der Name schon existiert, ersetzen wir seine Zeile mit den neuen Werten
        if (currentName == tempImageName) {
            newInfoString .= (A_Index == 1 ? "" : "&") . newLine
            imageExists := true
        } else {
            ; Ansonsten behalten wir die alte Zeile
            newInfoString .= (A_Index == 1 ? "" : "&") . currentLine
        }
    }

    ; 4. Wenn der Name komplett neu ist, hängen wir ihn einfach ans Ende an
    if (!imageExists) {
        newInfoString .= (newInfoString == "" ? "" : "&") . newLine
    }

    ; 5. Textdatei aktualisieren
    try FileDelete(infoFilePath)
    FileAppend(newInfoString, infoFilePath)

    ;MsgBox("Das Bild '" tempImageName "' wurde erfolgreich gespeichert!", "Erfolg")

    ImageMakerGui.Opt("-Disabled")
    ImageMakerGui.Show()
}

AutoSplitterGuiClose(*) {
    global pToken
    Gdip_Shutdown(pToken)
    ExitApp()
}

; ===================================================
; Allgemeine Hotkeys
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