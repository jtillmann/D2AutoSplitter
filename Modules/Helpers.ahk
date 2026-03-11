#Requires AutoHotkey v2.0

findAllColorsBetween(darkColor, lightColor) {
    darkArray := convertToRGB(darkColor)
    lightArray := convertToRGB(lightColor)
    returnMap := Map() ; Map() ersetzt {}

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
    ; v2 Formatierung
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

    ; 1. Vorbereitung für LockBits
    ; Wir erstellen einen Puffer für die Metadaten des Bildes und Variablen für Stride (Zeilenbreite) und Scan0 (Startadresse)
    BitmapData := Buffer(32, 0)
    Stride := 0
    Scan0 := 0

    ; 2. Bild im RAM sperren (LockMode 1 = Read Only, Format 0x26200A = 32bpp ARGB)
    Gdip_LockBits(pBitmap, 0, 0, makew, makeh, &Stride, &Scan0, &BitmapData, 1, 0x26200A)

    index := 1

    ; 3. Pixel direkt aus dem Speicher lesen
    loop makeh {
        y := A_Index - 1
        loop makew {
            x := A_Index - 1

            ; Die genaue Speicheradresse dieses einen Pixels berechnen:
            ; Startadresse + (Y-Koordinate * Zeilenbreite) + (X-Koordinate * 4 Bytes pro Pixel)
            pixelAddress := Scan0 + (y * Stride) + (x * 4)

            ; Den rohen Farbwert auslesen (UInt = 32-Bit Integer)
            rawColor := NumGet(pixelAddress, "UInt")

            ; Deine Maskierung anwenden (Ignoriert Alpha-Kanal und leichte Farbabweichungen)
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

    ; 4. Bild im RAM wieder entsperren (WICHTIG!)
    Gdip_UnlockBits(pBitmap, &BitmapData)

    ; --- Restliche Berechnung bleibt exakt gleich ---
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
            ; In v2 nutzt man .Has() für Maps anstelle von HasKey()
            if (bossHealthBarHashTable.Has(pixelColor)) {
                isDead := 0
                break 2 ; Bricht aus beiden Schleifen aus
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
; Pixel-Array Erstellung (Wandelt PNG in 0/1 String um)
; ===================================================

makePixelArrayString(imageName) {
    global makew, makeh, makeWhite, makeBlack

    makeWhite := 0
    makeBlack := 0
    pixelString := ""

    ; Bild in den Arbeitsspeicher laden
    pBitmap := Gdip_CreateBitmapFromFile(A_ScriptDir "\Split_Images\" imageName ".png")
    if (!pBitmap) {
        MsgBox("Fehler: Konnte Bild " imageName ".png nicht laden.")
        return ""
    }

    ; Breite und Höhe auslesen
    Gdip_GetImageDimensions(pBitmap, &makew, &makeh)

    BitmapData := Buffer(32, 0)
    Stride := 0, Scan0 := 0

    ; Bild im RAM sperren (LockMode 1 = Read Only, Format 0x26200A = 32bpp ARGB)
    Gdip_LockBits(pBitmap, 0, 0, makew, makeh, &Stride, &Scan0, &BitmapData, 1, 0x26200A)

    loop makeh {
        y := A_Index - 1
        loop makew {
            x := A_Index - 1

            ; Direkter Speicherzugriff
            pixelAddress := Scan0 + (y * Stride) + (x * 4)
            rawColor := NumGet(pixelAddress, "UInt")
            color := (rawColor & 0x00F0F0F0)

            ; String direkt mit Komma anhängen (ist extrem schnell)
            if (color == 0xF0F0F0) {
                pixelString .= "1,"
                makeWhite += 1
            } else {
                pixelString .= "0,"
                makeBlack += 1
            }
        }
    }

    ; Bild im RAM entsperren und löschen (Wichtig gegen Memory Leaks!)
    Gdip_UnlockBits(pBitmap, &BitmapData)
    Gdip_DisposeImage(pBitmap)

    ; Das letzte, überschüssige Komma am Ende des Strings abschneiden
    pixelString := RTrim(pixelString, ",")

    return pixelString
}
; ===================================================
; Bild-Such-Funktionen (findNormal, findBossDeath, findBossThere)
; ===================================================

findNormal(imgInfo) {
    global makeh, makew, currentSplitPixelArray
    imageCoordinates := imgInfo[2]

    ; Gdip_BitmapFromScreen benötigt den Koordinaten-String
    pBitmap := Gdip_BitmapFromScreen(imageCoordinates)

    ; colorCheck durchführen
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
    Gdip_DisposeImage(pBitmap4) ; Fix: war im Original pBitmap
    return pCorrect
}
