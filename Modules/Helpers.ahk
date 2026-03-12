#Requires AutoHotkey v2.0

findAllColorsBetween(darkColor, lightColor) {
    darkArray := convertToRGB(darkColor)
    lightArray := convertToRGB(lightColor)
    returnMap := Map() ; Map() replaces {}

    redDiff := lightArray[1] - darkArray[1] + 1
    greenDiff := lightArray[2] - darkArray[2] + 1
    blueDiff := lightArray[3] - darkArray[3] + 1

    loop redDiff {
        rOffset := A_Index - 1
        loop greenDiff {
            gOffset := A_Index - 1
            loop blueDiff {
                bOffset := A_Index - 1

                tempColorArray := [(darkArray[1] + rOffset), (darkArray[2] + gOffset), (darkArray[3] + bOffset)]
                tempColor := convertToHex(tempColorArray)
                returnMap[tempColor] := 1
            }
        }
    }
    return returnMap
}

convertToHex(arr) {
    ; v2 formatting
    return Format("0xFF{:02X}{:02X}{:02X}", arr[1], arr[2], arr[3])
}

convertToRGB(colorStr) {
    red := "0x" SubStr(colorStr, 3, 2)
    green := "0x" SubStr(colorStr, 5, 2)
    blue := "0x" SubStr(colorStr, 7, 2)

    return [Integer(red), Integer(green), Integer(blue)]
}

colorCheck(pBitmap, pixelArray) {
    global makeh, makew, makeBlack, makeWhite
    global PercCorrectForGui, WhiteCorrectForGui, BlackCorrectForGui

    bCorrect := 0
    wCorrect := 0
    nWrong := 0

    ; 1. Preparation for LockBits
    ; We create a buffer for the metadata of the image and variables for Stride (line width) and Scan0 (starting address)
    BitmapData := Buffer(32, 0)
    Stride := 0
    Scan0 := 0

    ; 2. Lock image in RAM (LockMode 1 = Read Only, Format 0x26200A = 32bpp ARGB)
    Gdip_LockBits(pBitmap, 0, 0, makew, makeh, &Stride, &Scan0, &BitmapData, 1, 0x26200A)

    index := 1

    ; 3. Read pixels directly from memory
    loop makeh {
        y := A_Index - 1
        loop makew {
            x := A_Index - 1

            ; Calculate exact memory address of this specific pixel:
            ; Starting address + (Y-coordinate * line width) + (X-coordinate * 4 bytes per pixel)
            pixelAddress := Scan0 + (y * Stride) + (x * 4)

            ; Read raw color value (UInt = 32-bit integer)
            rawColor := NumGet(pixelAddress, "UInt")

            ; Apply your masking (ignores alpha channel and slight color variations)
            color := (rawColor & 0x00F0F0F0)

            if (color == 0xF0F0F0) {
                if (pixelArray.Has(index) && pixelArray[index] == "1") {
                    wCorrect += 1
                } else {
                    nWrong += 1
                }
            } else {
                if (pixelArray.Has(index) && pixelArray[index] == "0") {
                    bCorrect += 1
                } else {
                    nWrong += 1
                }
            }
            index += 1
        }
    }

    ; 4. Unlock image in RAM again (IMPORTANT!)
    Gdip_UnlockBits(pBitmap, &BitmapData)

    ; --- Remaining calculation remains exactly the same ---
    bRatio := (makeBlack > 0) ? (bCorrect / makeBlack) : 1
    wRatio := (makeWhite > 0) ? (wCorrect / makeWhite) : 1

    pCorrect := Round(((bRatio + wRatio) / 2), 2)

    PercCorrectForGui := Round((pCorrect * 100), 0)
    WhiteCorrectForGui := (makeWhite > 0) ? Round((wCorrect / makeWhite * 100), 0) : 0
    BlackCorrectForGui := (makeBlack > 0) ? Round((bCorrect / makeBlack * 100), 0) : 0

    return pCorrect
}

setBitmapColor(bitmap, colorStr) {
    x := 0, y := 0
    Gdip_GetImageDimensions(bitmap, &bitmapWidth, &bitmapHeight)

    loop bitmapHeight {
        loop bitmapWidth {
            argbColor := "0xFF" SubStr(colorStr, 3)
            Gdip_SetPixel(bitmap, x, y, argbColor)
            x += 1
        }
        x := 0
        y += 1
    }
}

bossHPCheck(pBitmap3, hpw, hph) {
    global bossHealthBarHashTable, bossHpHelper
    isDead := 1
    makex := 0
    makey := 0

    loop hph {
        loop hpw {
            pixelColor := Gdip_GetPixel(pBitmap3, makex, makey)
            ; In v2 we use .Has() for Maps instead of HasKey()
            if (bossHealthBarHashTable.Has(pixelColor)) {
                isDead := 0
                break 2 ; Breaks out of both loops
            }
            makex += 1
        }
        makex := 0
        makey += 1
    }

    if (!isDead) {
        bossHpHelper := 0
    }
    return isDead
}

bossHPShowingUp(pBitmap3, hpw, hph) {
    global bossHealthBarHashTable, bossHpHelper
    isThere := 0
    makex := 0
    makey := 0

    loop hph {
        loop hpw {
            pixelColor := Gdip_GetPixel(pBitmap3, makex, makey)
            if (bossHealthBarHashTable.Has(pixelColor)) {
                isThere := 1
                break 2
            }
            makex += 1
        }
        makex := 0
        makey += 1
    }

    if (!isThere) {
        bossHpHelper := 0
    }
    return isThere
}

; ===================================================
; Pixel-Array Creation (Converts PNG to 0/1 string)
; ===================================================

makePixelArrayString(imageName) {
    global makew, makeh, makeWhite, makeBlack

    makeWhite := 0
    makeBlack := 0
    pixelString := ""

    ; Load image into memory
    pBitmap := Gdip_CreateBitmapFromFile(A_ScriptDir "\Split_Images\" imageName ".png")
    if (!pBitmap) {
        MsgBox("Error: Could not load image " imageName ".png.")
        return ""
    }

    ; Read width and height
    Gdip_GetImageDimensions(pBitmap, &makew, &makeh)

    BitmapData := Buffer(32, 0)
    Stride := 0, Scan0 := 0

    ; Lock image in RAM (LockMode 1 = Read Only, Format 0x26200A = 32bpp ARGB)
    Gdip_LockBits(pBitmap, 0, 0, makew, makeh, &Stride, &Scan0, &BitmapData, 1, 0x26200A)

    loop makeh {
        y := A_Index - 1
        loop makew {
            x := A_Index - 1

            ; Direct memory access
            pixelAddress := Scan0 + (y * Stride) + (x * 4)
            rawColor := NumGet(pixelAddress, "UInt")
            color := (rawColor & 0x00F0F0F0)

            ; Append to string directly with comma (is extremely fast)
            if (color == 0xF0F0F0) {
                pixelString .= "1,"
                makeWhite += 1
            } else {
                pixelString .= "0,"
                makeBlack += 1
            }
        }
    }

    ; Unlock and delete image in RAM (Important against memory leaks!)
    Gdip_UnlockBits(pBitmap, &BitmapData)
    Gdip_DisposeImage(pBitmap)

    ; Cut off the last, excess comma at the end of the string
    pixelString := RTrim(pixelString, ",")

    return pixelString
}
; ===================================================
; Image search functions (findNormal, findBossDeath, findBossThere)
; ===================================================

findNormal(imgInfo) {
    global makeh, makew, currentSplitPixelArray
    imageCoordinates := imgInfo[2]

    ; Gdip_BitmapFromScreen requires the coordinates string
    pBitmap := Gdip_BitmapFromScreen(imageCoordinates)

    ; Perform colorCheck
    pCorrect := colorCheck(pBitmap, currentSplitPixelArray)

    Gdip_DisposeImage(pBitmap)
    return pCorrect
}

findBossDeath(imgInfo) {
    global imageDataArray, bossHpHelper
    bossHPCoords := imageDataArray[3]

    pBitmap4 := Gdip_BitmapFromScreen(bossHPCoords)
    isDead := bossHPCheck(pBitmap4, 40, 10)

    if (isDead) {
        bossHpHelper += 1
    }

    pCorrect := Round((bossHpHelper / 4), 2)
    Gdip_DisposeImage(pBitmap4)
    return pCorrect
}

findBossThere(imgInfo) {
    global imageDataArray, bossHpHelper
    bossHPCoords := imageDataArray[3]

    pBitmap4 := Gdip_BitmapFromScreen(bossHPCoords)
    isThere := bossHPShowingUp(pBitmap4, 40, 10)

    if (isThere) {
        bossHpHelper += 1
    }

    pCorrect := Round((bossHpHelper / 6), 2)
    Gdip_DisposeImage(pBitmap4) ; Fix: was originally pBitmap
    return pCorrect
}

LoadPixelatedImage(filePath, targetW, targetH) {
    pBitmap := Gdip_CreateBitmapFromFile(filePath)
    if (!pBitmap)
        return 0

    Gdip_GetImageDimensions(pBitmap, &origW, &origH)

    pBitmapScaled := Gdip_CreateBitmap(targetW, targetH)
    pGraphics := Gdip_GraphicsFromImage(pBitmapScaled)

    Gdip_SetInterpolationMode(pGraphics, 5)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", pGraphics, "Int", 2)

    Gdip_DrawImage(pGraphics, pBitmap, 0, 0, targetW, targetH, 0, 0, origW, origH)

    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmapScaled)

    Gdip_DeleteGraphics(pGraphics)
    Gdip_DisposeImage(pBitmap)
    Gdip_DisposeImage(pBitmapScaled)

    return hBitmap
}
