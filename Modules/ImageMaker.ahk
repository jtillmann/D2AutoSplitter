#Requires AutoHotkey v2.0

class ImageMaker {
    Gui := unset
    HPFinderGui := unset
    ScreenshotGui := unset

    x1 := 0, y1 := 0, x2 := 0, y2 := 0
    w := 0, h := 0, total := 0
    imgCoords := "0|0|1|1"

    ; Control References
    ctrlCapture := unset
    ctrlUncapture := unset
    ctrlHkCapture := unset
    ctrlTopNum := unset
    ctrlBotNum := unset
    ctrlLeftNum := unset
    ctrlRightNum := unset
    ctrlRealPic := unset
    ctrlBnWPic := unset
    ctrlPW := unset
    ctrlTP := unset

    ctrlDarkHPColor := unset
    ctrlLightHPColor := unset

    rectGuiArr := []

    __New() {
        this.Gui := Gui("", "Split Image Maker")
        this.Gui.SetFont("s9", "Segoe UI")

        ; Build Main Image Maker GUI
        for item in Layouts.ImageMaker {
            text := item.HasProp("Text") ? item.Text : ""
            if (item.Type == "Picture" && !InStr(text, "\")) {
                text := A_ScriptDir "\Dependencies\" text
            }

            ctrl := this.Gui.Add(item.Type, item.Opt, text)

            if item.HasProp("Ref")
                this.%item.Ref% := ctrl

            if item.HasProp("Event") {
                if item.HasProp("Args")
                    ctrl.OnEvent("Click", this.%item.Event%.Bind(this, item.Args*))
                else
                    ctrl.OnEvent("Click", this.%item.Event%.Bind(this))
            }

            if item.HasProp("Font")
                ctrl.SetFont(item.Font)
        }

        global EngineMgr
        hk := (EngineMgr.hkSettings.Length >= 5) ? EngineMgr.hkSettings[5] : ""
        if (hk != "") {
            try Hotkey("$" hk, this.Capture.Bind(this))
        }
        this.ctrlHkCapture.Value := hk

        loop 4 {
            guiObj := Gui("-Caption +AlwaysOnTop +ToolWindow")
            guiObj.BackColor := "Red"
            this.rectGuiArr.Push(guiObj)
        }

        this.InitializeHPFinder()
    }

    InitializeHPFinder() {
        this.HPFinderGui := Gui("+AlwaysOnTop", "HP Bar Color Finder")

        for item in Layouts.HPFinder {
            ctrl := this.HPFinderGui.Add(item.Type, item.Opt, item.HasProp("Text") ? item.Text : "")

            if item.HasProp("Ref")
                this.%item.Ref% := ctrl

            if item.HasProp("Event")
                ctrl.OnEvent("Click", this.%item.Event%.Bind(this))
        }

        global EngineMgr, tmpImage
        if (EngineMgr.hpDarkColor != "") {
            pBmp := Gdip_CreateBitmap(149, 129)
            Gdip_GraphicsClear(Gdip_GraphicsFromImage(pBmp), "0xff" SubStr(EngineMgr.hpDarkColor, 3))
            Gdip_SaveBitmapToFile(pBmp, tmpImage)
            this.ctrlDarkHPColor.Value := tmpImage
            Gdip_DisposeImage(pBmp)
        }

        if (EngineMgr.hpLightColor != "") {
            pBmp := Gdip_CreateBitmap(149, 129)
            Gdip_GraphicsClear(Gdip_GraphicsFromImage(pBmp), "0xff" SubStr(EngineMgr.hpLightColor, 3))
            Gdip_SaveBitmapToFile(pBmp, tmpImage)
            this.ctrlLightHPColor.Value := tmpImage
            Gdip_DisposeImage(pBmp)
        }
    }

    Open(*) {
        global Autosplitter
        Autosplitter.Opt("+Disabled")
        this.Gui.Show("Center")
        WinWaitClose("Split Image Maker")
        Autosplitter.Opt("-Disabled")
        if IsSet(this.ScreenshotGui)
            this.ScreenshotGui.Hide()
        Autosplitter.Show()
    }

    OnSetHotkeys(*) {
        global MainMgr
        MainMgr.SetHotkeys()
    }

    Capture(*) {
        global scshot
        temp := "0|0|" A_ScreenWidth "|" A_ScreenHeight
        pBitmap := Gdip_BitmapFromScreen(temp)
        Gdip_SaveBitmapToFile(pBitmap, scshot)
        Gdip_DisposeImage(pBitmap)

        if !IsSet(this.ScreenshotGui)
            this.ScreenshotGui := Gui("-Caption", "Screenshot GUI")
        this.ScreenshotGui.Add("Picture", "x0 y0", A_ScriptDir "\Dependencies\fullScreenshot.png")
        this.ScreenshotGui.Show("h" A_ScreenHeight " w" A_ScreenWidth " x0 y0")

        this.ctrlCapture.Visible := false
        this.ctrlUncapture.Visible := true
        this.Gui.Show()
    }

    Uncapture(*) {
        if IsSet(this.ScreenshotGui)
            this.ScreenshotGui.Hide()
        this.ctrlUncapture.Visible := false
        this.ctrlCapture.Visible := true
    }

    SelectArea(*) {
        this.LetUserSelectRect(&nx1, &ny1, &nx2, &ny2)
        this.x1 := nx1, this.y1 := ny1, this.x2 := nx2, this.y2 := ny2
        this.SetImages(this.x1, this.y1, this.x2, this.y2)
    }

    LetUserSelectRect(&X1, &Y1, &X2, &Y2) {
        static xorigin, yorigin, xlast, ylast, curX1, curY1, curX2, curY2
        lusr_return(*) => ""
        try Hotkey("*LButton", lusr_return, "On")
        KeyWait "LButton", "D"
        MouseGetPos(&xorigin, &yorigin)

        LusrUpdate(*) {
            MouseGetPos(&x, &y)
            if (x = xorigin && y = yorigin && !IsSet(xlast))
                return
            if (IsSet(xlast) && x = xlast && y = ylast)
                return
            if (x < xorigin) {
                curX1 := x, curX2 := xorigin
            } else {
                curX2 := x, curX1 := xorigin
            }
            if (y < yorigin) {
                curY1 := y, curY2 := yorigin
            } else {
                curY2 := y, curY1 := yorigin
            }
            this.UpdateRect(curX1, curY1, curX2, curY2)
            xlast := x, ylast := y
        }

        SetTimer LusrUpdate, 10
        KeyWait "LButton"
        try Hotkey("*LButton", "Off")
        SetTimer LusrUpdate, 0
        X1 := curX1, Y1 := curY1, X2 := curX2, Y2 := curY2
    }

    UpdateRect(x1, y1, x2, y2, r := 2) {
        global EngineMgr
        rr := r * EngineMgr.dpiRatio
        SetTimer this.CloseRect.Bind(this), 0

        this.rectGuiArr[1].Show("NA X" (x1 - rr) " Y" (y1 - rr) " W" ((x2 - x1 + 2 * rr) / EngineMgr.dpiRatio) " H" r)
        this.rectGuiArr[2].Show("NA X" (x1 - rr) " Y" y2 " W" ((x2 - x1 + 2 * rr) / EngineMgr.dpiRatio) " H" r)
        this.rectGuiArr[3].Show("NA X" (x1 - rr) " Y" (y1 - rr) " W" r " H" ((y2 - y1 + rr) / EngineMgr.dpiRatio))
        this.rectGuiArr[4].Show("NA X" x2 " Y" (y1 - rr) " W" r " H" ((y2 - y1 + rr) / EngineMgr.dpiRatio))

        SetTimer this.CloseRect.Bind(this), 8000
    }

    CloseRect(*) {
        for guiObj in this.rectGuiArr
            guiObj.Hide()
        SetTimer this.CloseRect.Bind(this), 0
    }

    Move(side, amount, *) {
        if (side == "Top")
            this.y1 += amount
        else if (side == "Bottom")
            this.y2 += amount
        else if (side == "Left")
            this.x1 += amount
        else if (side == "Right")
            this.x2 += amount

        this.UpdateRect(this.x1, this.y1, this.x2, this.y2)
        this.SetImages(this.x1, this.y1, this.x2, this.y2)
    }

    SetImages(x1, y1, x2, y2) {
        global realImage, BnWImage
        w := x2 - x1, h := y2 - y1, total := w * h
        this.imgCoords := x1 "|" y1 "|" w "|" h

        this.ctrlTopNum.Value := y1
        this.ctrlBotNum.Value := y2
        this.ctrlLeftNum.Value := x1
        this.ctrlRightNum.Value := x2

        pBitmap := Gdip_BitmapFromScreen(this.imgCoords)
        pBitmap1 := Gdip_CloneBitmapArea(pBitmap, 0, 0, w, h)
        pBitmap2 := Gdip_CloneBitmapArea(pBitmap, 0, 0, w, h)
        Gdip_DisposeImage(pBitmap)

        nWhite := 0, nBlack := 0
        loop h {
            cy := A_Index - 1
            loop w {
                cx := A_Index - 1
                color := Gdip_GetPixel(pBitmap1, cx, cy)
                if (Gdip_IsWhite(color)) {
                    Gdip_SetPixel(pBitmap2, cx, cy, 0xFFFFFFFF)
                    nWhite++
                } else {
                    Gdip_SetPixel(pBitmap2, cx, cy, 0xFF000000)
                    nBlack++
                }
            }
        }

        Gdip_SaveBitmapToFile(pBitmap1, realImage)
        Gdip_SaveBitmapToFile(pBitmap2, BnWImage)
        Gdip_DisposeImage(pBitmap1)
        Gdip_DisposeImage(pBitmap2)

        this.ctrlRealPic.Value := ""
        this.ctrlBnWPic.Value := ""
        this.ctrlRealPic.Value := A_ScriptDir "\Dependencies\real_image.png"
        this.ctrlBnWPic.Value := A_ScriptDir "\Dependencies\BnW.png"

        pWhite := Round(((nWhite / (nBlack + nWhite)) * 100), 2)
        this.ctrlPW.Value := pWhite "%"
        this.ctrlTP.Value := total
    }

    Save(*) {
        global EngineMgr
        this.Gui.Opt("+Disabled")
        loop {
            ib := InputBox("What would you like to name this image?", "Name Image")
            if (ib.Result == "Cancel")
                break

            name := ib.Value
            infoStr := ""
            try infoStr := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
            infoArr := StrSplit(infoStr, "&")

            found := false
            for i, row in infoArr {
                rowArr := StrSplit(row, ",")
                if (rowArr.Length >= 1 && rowArr[1] == name) {
                    if (MsgBox("An image with this name already exists.`nWould you like to overwrite it?", "Overwrite?",
                        "YesNo") == "No") {
                        found := true
                        break
                    } else {
                        infoArr.RemoveAt(i)
                        dark := (infoArr.Length >= 1) ? infoArr[1] : "0x000000"
                        light := (infoArr.Length >= 2) ? infoArr[2] : "0x000000"
                        infoStr := dark "&" light
                        loop (infoArr.Length - 2) {
                            if (A_Index + 2 <= infoArr.Length)
                                infoStr .= "&" infoArr[A_Index + 2]
                        }
                        found := false
                        break
                    }
                }
            }

            if (!found) {
                infoStr .= "&" name "," this.imgCoords
                if FileExist(A_ScriptDir "\Split_Images\image_info.txt")
                    FileDelete A_ScriptDir "\Split_Images\image_info.txt"
                FileAppend infoStr, A_ScriptDir "\Split_Images\image_info.txt"

                pBitmap := Gdip_CreateBitmapFromFile(A_ScriptDir "\Dependencies\real_image.png")
                path := A_ScriptDir "\Split_Images\" name ".png"
                Gdip_SaveBitmapToFile(pBitmap, path)
                Gdip_DisposeImage(pBitmap)

                EngineMgr.InitializeCache()
                break
            }
        }
        this.Gui.Opt("-Disabled")
        this.Gui.Show()
    }

    OpenHPFinder(*) {
        this.Gui.Opt("+Disabled")
        this.HPFinderGui.Show("Center")
        WinWaitClose("HP Bar Color Finder")
        this.Gui.Opt("-Disabled")
        this.Gui.Show()
    }

    SaveHPBarColors(*) {
        global EngineMgr
        this.HPFinderGui.Opt("+Disabled")
        infoStr := ""
        try infoStr := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
        infoArr := StrSplit(infoStr, "&")

        newStr := EngineMgr.hpDarkColor "&" EngineMgr.hpLightColor
        loop infoArr.Length - 2 {
            newStr .= "&" infoArr[A_Index + 2]
        }

        if FileExist(A_ScriptDir "\Split_Images\image_info.txt")
            FileDelete A_ScriptDir "\Split_Images\image_info.txt"
        FileAppend newStr, A_ScriptDir "\Split_Images\image_info.txt"

        EngineMgr.InitializeCache()

        this.HPFinderGui.Opt("-Disabled")
        this.HPFinderGui.Hide()
    }

    SetBarLocation(*) {
        global EngineMgr
        this.HPFinderGui.Opt("+Disabled")
        this.LetUserSelectRect(&bx1, &by1, &bx2, &by2)

        infoStr := ""
        try infoStr := FileRead(A_ScriptDir "\Split_Images\image_info.txt")
        infoArr := StrSplit(infoStr, "&")

        newInfo := (infoArr.Length >= 1 ? infoArr[1] : "") "&" (infoArr.Length >= 2 ? infoArr[2] : "") "&" bx1 "|" by1 "|" (
            bx2 - bx1) "|" (by2 - by1)
        loop (infoArr.Length - 3) {
            newInfo .= "&" infoArr[A_Index + 3]
        }

        if FileExist(A_ScriptDir "\Split_Images\image_info.txt")
            FileDelete A_ScriptDir "\Split_Images\image_info.txt"
        FileAppend newInfo, A_ScriptDir "\Split_Images\image_info.txt"

        EngineMgr.InitializeCache()

        this.HPFinderGui.Opt("-Disabled")
        this.HPFinderGui.Show()
    }

    SetDarkColor(*) {
        global EngineMgr, tmpImage
        this.HPFinderGui.Opt("+Disabled")
        KeyWait "LButton", "D"
        MouseGetPos &X, &Y
        EngineMgr.hpDarkColor := PixelGetColor(X, Y)

        pBmp := Gdip_CreateBitmap(149, 129)
        Gdip_GraphicsClear(Gdip_GraphicsFromImage(pBmp), "0xff" SubStr(EngineMgr.hpDarkColor, 3))
        Gdip_SaveBitmapToFile(pBmp, tmpImage)
        this.ctrlDarkHPColor.Value := ""
        this.ctrlDarkHPColor.Value := tmpImage
        Gdip_DisposeImage(pBmp)

        this.HPFinderGui.Opt("-Disabled")
        this.HPFinderGui.Show()
    }

    SetLightColor(*) {
        global EngineMgr, tmpImage
        this.HPFinderGui.Opt("+Disabled")
        KeyWait "LButton", "D"
        MouseGetPos &X, &Y
        EngineMgr.hpLightColor := PixelGetColor(X, Y)

        pBmp := Gdip_CreateBitmap(149, 129)
        Gdip_GraphicsClear(Gdip_GraphicsFromImage(pBmp), "0xff" SubStr(EngineMgr.hpLightColor, 3))
        Gdip_SaveBitmapToFile(pBmp, tmpImage)
        this.ctrlLightHPColor.Value := ""
        this.ctrlLightHPColor.Value := tmpImage
        Gdip_DisposeImage(pBmp)

        this.HPFinderGui.Opt("-Disabled")
        this.HPFinderGui.Show()
    }
}
