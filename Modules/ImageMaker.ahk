#Requires AutoHotkey v2.0

; ===================================================
; Globale Deklarationen für Split Image Maker
; ===================================================
global realImage := A_ScriptDir "\Dependencies\real_image.png"
global BnWImage := A_ScriptDir "\Dependencies\BnW.png"
global scshot := A_ScriptDir "\Dependencies\fullScreenshot.png"
global tmpImage := A_ScriptDir "\Dependencies\tmp.png"

global x1 := 0, y1 := 0, x2 := 0, y2 := 0
global w := 0, h := 0, total := 0
global imageCoords := "0|0|1|1"

; ===================================================
; GUI Definitions for Split Image Maker
; ===================================================

; Create GUI object
global ImageMakerGui := Gui("+AlwaysOnTop", "Split Image Maker")
ImageMakerGui.OnEvent("Close", (*) => ImageMakerGui.Hide())

ImageMakerGui.Add("GroupBox", "x12 y-1 w140 h540", "Settings")

; Buttons for screenshot functions
global btnCapture := ImageMakerGui.Add("Button", "x22 y15 w120 h50", "Freeze Screen")
btnCapture.OnEvent("Click", Capture)
global btnUncapture := ImageMakerGui.Add("Button", "x22 y15 w120 h50 +Hidden", "Unfreeze Screen")
btnUncapture.OnEvent("Click", Uncapture)

; Hotkey control
tmpVarHK5 := (hotKeySettingsArray.Length >= 5) ? hotKeySettingsArray[5] : ""
if (tmpVarHK5 != "") {
    try Hotkey("$" tmpVarHK5, Capture)
}
global hkCapture := ImageMakerGui.Add("Hotkey", "x27 y70 w110 h20", tmpVarHK5)
ImageMakerGui.Add("Button", "x52 y92 w60 h23", "Set").OnEvent("Click", Sethotkeys)

ImageMakerGui.Add("Button", "x22 y115 w120 h50", "Select Area").OnEvent("Click", Picture)
ImageMakerGui.Add("Button", "x22 y165 w120 h50", "Save Current Image").OnEvent("Click", Save)
ImageMakerGui.Add("Button", "x22 y480 w120 h50", "Open Boss HP Bar Color Finder").OnEvent("Click", OpenHPFinder)

; --- Coordinate adjustment (Top, Bottom, Left, Right) ---
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
global txtTopNum := ImageMakerGui.Add("Text", "x63 y242 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y239 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("y1", -10))
ImageMakerGui.Add("Button", "x122 y239 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("y1", 10))
ImageMakerGui.Add("Button", "x42 y239 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("y1", -1))
ImageMakerGui.Add("Button", "x102 y239 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("y1", 1))

; Bottom
ImageMakerGui.Add("Text", "x70 y289 w80 h20", "Bottom")
global txtBotNum := ImageMakerGui.Add("Text", "x63 y312 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y309 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("y2", -10))
ImageMakerGui.Add("Button", "x122 y309 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("y2", 10))
ImageMakerGui.Add("Button", "x42 y309 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("y2", -1))
ImageMakerGui.Add("Button", "x102 y309 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("y2", 1))

; Left
ImageMakerGui.Add("Text", "x70 y359 w80 h20", "Left")
global txtLeftNum := ImageMakerGui.Add("Text", "x63 y382 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y379 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("x1", -10))
ImageMakerGui.Add("Button", "x122 y379 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("x1", 10))
ImageMakerGui.Add("Button", "x42 y379 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("x1", -1))
ImageMakerGui.Add("Button", "x102 y379 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("x1", 1))

; Right
ImageMakerGui.Add("Text", "x67 y429 w80 h20", "Right")
global txtRightNum := ImageMakerGui.Add("Text", "x63 y452 w38 h15 +Border +Center", "0")
ImageMakerGui.Add("Button", "x21 y449 w21 h20", "-10").OnEvent("Click", AdjustCoord.Bind("x2", -10))
ImageMakerGui.Add("Button", "x122 y449 w24 h20", "+10").OnEvent("Click", AdjustCoord.Bind("x2", 10))
ImageMakerGui.Add("Button", "x42 y449 w20 h20", "-1").OnEvent("Click", AdjustCoord.Bind("x2", -1))
ImageMakerGui.Add("Button", "x102 y449 w20 h20", "+1").OnEvent("Click", AdjustCoord.Bind("x2", 1))

; Image displays
ImageMakerGui.Add("GroupBox", "x162 y-1 w530 h510", "Black and White Pixels")
ImageMakerGui.Add("GroupBox", "x702 y-1 w530 h510", "Actual Image")
global picReal := ImageMakerGui.Add("Picture", "x712 y19 w510 h480", realImage)
global picBnW := ImageMakerGui.Add("Picture", "x172 y19 w510 h480", BnWImage)

global txtPW := ImageMakerGui.Add("Text", "x360 y520 w50 h20", "0")
global txtTP := ImageMakerGui.Add("Text", "x580 y520 w150 h20", "0")

; ===================================================
; GUI for Boss HP Bar Color Finder
; ===================================================
global HPbarGui := Gui("+AlwaysOnTop", "Boss HP Bar Color Finder")
HPbarGui.OnEvent("Close", (*) => HPbarGui.Hide())

HPbarGui.Add("Button", "x8 y8 w57 h128", "Save Colors").OnEvent("Click", SaveHPBarColors)
HPbarGui.Add("Button", "x8 y146 w57 h56", "Set Bar Location").OnEvent("Click", SetBarLocation)
HPbarGui.Add("Button", "x72 y168 w149 h46", "Find Dark Color").OnEvent("Click", SetDarkColor)
HPbarGui.Add("Button", "x224 y168 w149 h46", "Find Light Color").OnEvent("Click", SetLightColor)

global picDarkHP := HPbarGui.Add("Picture", "x72 y8 w149 h129", tmpImage)
global picLightHP := HPbarGui.Add("Picture", "x224 y8 w149 h129", tmpImage)

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
; Logic Functions for Split Image Maker
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
    if (IsSet(ScreenshotGui) && Type(ScreenshotGui) == "Gui") {
        ScreenshotGui.Hide()
    }

    ; Bring main window to foreground again
    MainGui.Show()
}

SetDarkColor(*) {
    global HPBarDarkColor, tmpImage, pToken, picDarkHP
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
    global HPBarLightColor, tmpImage, pToken, picLightHP
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

Capture(*) {
    global scshot, ScreenshotGui, btnCapture, btnUncapture, ImageMakerGui

    ; Virtual screen stats to cover all monitors (76=X, 77=Y, 78=Width, 79=Height)
    vX := SysGet(76), vY := SysGet(77), vW := SysGet(78), vH := SysGet(79)

    ; Capture the whole virtual screen
    pBitmap := Gdip_BitmapFromScreen(vX "|" vY "|" vW "|" vH)
    Gdip_SaveBitmapToFile(pBitmap, scshot)
    Gdip_DisposeImage(pBitmap)

    try ScreenshotGui.Destroy()

    ; ScreenshotGui should NOT be AlwaysOnTop, but ImageMakerGui IS.
    ; This ensures ImageMakerGui stays in front of the frozen capture.
    ScreenshotGui := Gui("-Caption -DPIScale")
    ScreenshotGui.MarginX := 0
    ScreenshotGui.MarginY := 0
    ScreenshotGui.Add("Picture", "x0 y0 w" vW " h" vH, scshot)

    ; Show with NA (No Activate) to prevent focus theft
    ScreenshotGui.Show("x" vX " y" vY " w" vW " h" vH " NA")

    btnCapture.Visible := false
    btnUncapture.Visible := true

    ; Ensure ImageMakerGui is brought to front
    ImageMakerGui.Show()
}

Uncapture(*) {
    global ScreenshotGui, btnUncapture, btnCapture
    try ScreenshotGui.Destroy()
    btnUncapture.Visible := false
    btnCapture.Visible := true
}

Picture(*) {
    global x1, y1, x2, y2
    LetUserSelectRect(&x1, &y1, &x2, &y2) ; Parameter passing with & (reference)
    setImages(x1, y1, x2, y2)
}

LetUserSelectRect(&outX1, &outY1, &outX2, &outY2) {
    ; 1. Warten, bis der Klick auf den "Select"-Button wirklich beendet ist
    KeyWait("LButton")

    ; ==========================================================
    ; DER FIX: Ein unsichtbares "Schutzschild"-GUI über alle Monitore legen
    ; ==========================================================
    ShieldGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    ShieldGui.BackColor := "White"

    ; Transparenz auf 1 setzen.
    ; (1 ist quasi unsichtbar, aber Windows blockiert den Klick für die Fenster dahinter!)
    WinSetTransparent(1, ShieldGui.Hwnd)

    ; Das Schild über den gesamten virtuellen Desktop spannen
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    ShieldGui.Show("x" vx " y" vy " w" vw " h" vh " NA")

    CoordMode("Mouse", "Screen")
    local xorigin, yorigin

    lusr_update() {
        local x, y
        MouseGetPos(&x, &y)

        ; Min und Max sortieren die Koordinaten automatisch richtig,
        ; egal in welche Richtung du die Maus ziehst!
        outX1 := Min(x, xorigin)
        outX2 := Max(x, xorigin)
        outY1 := Min(y, yorigin)
        outY2 := Max(y, yorigin)

        updateRect(outX1, outY1, outX2, outY2)
    }

    ; 2. Warten, bis du auf das unsichtbare Schild klickst
    KeyWait("LButton", "D")
    MouseGetPos(&xorigin, &yorigin)

    ; Timer startet das Zeichnen des roten Rahmens
    SetTimer(lusr_update, 10)

    ; 3. Warten, bis du die Maus loslässt
    KeyWait("LButton")

    ; Timer beenden und das unsichtbare Schild zerstören
    SetTimer(lusr_update, 0)
    ShieldGui.Destroy()
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

setImages(rx1, ry1, rx2, ry2) {
    global imageCoords, realImage, BnWImage, txtPW, txtTP
    global txtTopNum, txtBotNum, txtLeftNum, txtRightNum
    global picReal, picBnW

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

OpenHPFinder(*) {
    ImageMakerGui.Opt("+Disabled -AlwaysOnTop")
    HPbarGui.Show()
    SetTimer(colorUndermouse, 10)

    ; Wait until window is closed
    WinWaitClose("Boss HP Bar Color Finder")

    SetTimer(colorUndermouse, 0)
    ToolTip() ; Hides the ToolTip
    ImageMakerGui.Opt("-Disabled +AlwaysOnTop")
    ImageMakerGui.Show()
}

colorUndermouse() {
    MouseGetPos(&VarX, &VarY)
    mouseColor := PixelGetColor(VarX, VarY)
    ToolTip(mouseColor)
}

Save(*) {
    global imageCoords, realImage, txtTP, ImageMakerGui
    ImageMakerGui.Opt("+Disabled -AlwaysOnTop")

    ; Check if coordinates were even selected
    if (imageCoords == "0|0|1|1" || imageCoords == "") {
        MsgBox("No image has been selected.")
        ImageMakerGui.Opt("-Disabled +AlwaysOnTop")
        ImageMakerGui.Show()
        return
    }

    loop {
        ib := InputBox("What would you like to name this image?", "Save Image")

        if (ib.Result == "Cancel" || ib.Result == "Timeout" || ib.Value == "") {
            ImageMakerGui.Opt("-Disabled +AlwaysOnTop")
            ImageMakerGui.Show()
            return
        }
        tempImageName := ib.Value

        ; Check if image name already exists in image_info.txt
        infoFilePath := A_ScriptDir "\Split_Images\image_info.txt"
        imageInfoString := ""
        try imageInfoString := FileRead(infoFilePath)

        imageExists := false
        imageDataArray := StrSplit(imageInfoString, "&")
        for line in imageDataArray {
            if (line != "" && StrSplit(line, ",")[1] == tempImageName) {
                imageExists := true
                break
            }
        }

        if (imageExists) {
            ; temporarily disable AlwaysOnTop for MsgBox as well
            ImageMakerGui.Opt("-AlwaysOnTop")
            result := MsgBox("An image with the name '" tempImageName "' already exists. Do you want to overwrite it?",
                "Name Already Taken", "YesNo Icon!")
            ImageMakerGui.Opt("+AlwaysOnTop")

            if (result == "No")
                continue ; Ask for name again
        }
        break ; Name is new or user confirmed overwrite
    }

    ; 1. Copy temporary image to Split_Images folder (1 = allow overwrite)
    targetImagePath := A_ScriptDir "\Split_Images\" tempImageName ".png"
    try FileCopy(realImage, targetImagePath, 1)

    ; 2. Update image_info.txt (Re-read to ensure we have the latest state)
    try imageInfoString := FileRead(infoFilePath)
    imageDataArray := StrSplit(imageInfoString, "&")
    newInfoString := ""
    imageExistsInFile := false ; Track if we actually find it during the line-by-line rebuild

    ; The new data line: Name, coordinates, total pixel count (from GUI element txtTP)
    newLine := tempImageName "," imageCoords "," txtTP.Value

    ; 3. Rebuild the info string
    loop imageDataArray.Length {
        currentLine := imageDataArray[A_Index]
        if (currentLine == "")
            continue

        currentName := StrSplit(currentLine, ",")[1]

        ; If name matches, replace its line with new values
        if (currentName == tempImageName) {
            newInfoString .= (newInfoString == "" ? "" : "&") . newLine
            imageExistsInFile := true
        } else {
            ; Otherwise keep old line
            newInfoString .= (newInfoString == "" ? "" : "&") . currentLine
        }
    }

    ; 4. If name was not found during rebuild, append to end
    if (!imageExistsInFile) {
        newInfoString .= (newInfoString == "" ? "" : "&") . newLine
    }

    ; 5. Update text file
    try FileDelete(infoFilePath)
    FileAppend(newInfoString, infoFilePath)

    ImageMakerGui.Opt("-Disabled +AlwaysOnTop")
    ImageMakerGui.Show()
}
