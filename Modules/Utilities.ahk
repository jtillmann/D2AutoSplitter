#Requires AutoHotkey v2.0

SetBitmapColor(bitmap, color) {
    Gdip_GetImageDimensions(bitmap, &w, &h)
    loop h {
        cy := A_Index - 1
        loop w {
            cx := A_Index - 1
            argb := "0xFF" SubStr(color, 3)
            Gdip_SetPixel(bitmap, cx, cy, argb)
        }
    }
}

FindAllColorsBetween(darkColor, lightColor) {
    darkArr := ConvertToRGB(darkColor)
    lightArr := ConvertToRGB(lightColor)
    colorMap := Map()
    rDiff := lightArr[1] - darkArr[1] + 1
    gDiff := lightArr[2] - darkArr[2] + 1
    bDiff := lightArr[3] - darkArr[3] + 1

    rIdx := 0
    loop rDiff {
        gIdx := 0
        loop gDiff {
            bIdx := 0
            loop bDiff {
                rgb := [(darkArr[1] + rIdx), (darkArr[2] + gIdx), (darkArr[3] + bIdx)]
                hex := String(ConvertToHex(rgb))
                colorMap[hex] := 1
                bIdx++
            }
            gIdx++
        }
        rIdx++
    }
    return colorMap
}

ConvertToHex(rgb) {
    return format("0xff{:02x}{:02x}{:02x}", rgb*)
}

ConvertToRGB(color) {
    r := "0x" SubStr(color, 3, 2)
    g := "0x" SubStr(color, 5, 2)
    b := "0x" SubStr(color, 7, 2)
    return [Integer(r), Integer(g), Integer(b)]
}

WriteLog(text) {
    if !A_IsCompiled {
        try FileAppend A_NowUTC ": " text "`n", A_ScriptDir "\logfile.txt"
    }
}

MakePixelArrayString(imageName) {
    path := A_WorkingDir "\Split_Images\" imageName ".png"
    pBmp := Gdip_CreateBitmapFromFile(path)
    if (!pBmp)
        return ""

    x := 0, y := 0
    pixelStr := ""
    w := 0, h := 0
    Gdip_GetImageDimensions(pBmp, &w, &h)
    loop h {
        loop w {
            if (y != 0 || x != 0) {
                pixelStr .= ","
            }
            color := (Gdip_GetPixel(pBmp, x, y) & 0x00F0F0F0)
            pixelStr .= (color == 0xF0F0F0) ? "1" : "0"
            x += 1
        }
        x := 0
        y += 1
    }
    Gdip_DisposeImage(pBmp)
    return pixelStr
}

ColorCheck(pBitmap, pixelArr) {
    w := 0, h := 0
    Gdip_GetImageDimensions(pBitmap, &w, &h)
    x := 0, y := 0
    bCorrect := 0, wCorrect := 0
    idx := 1

    totalWhite := 0, totalBlack := 0
    for val in pixelArr {
        if (val == "1")
            totalWhite++
        else
            totalBlack++
    }

    loop h {
        loop w {
            color := (Gdip_GetPixel(pBitmap, x, y) & 0x00F0F0F0)
            if (color == 0xF0F0F0) {
                if (pixelArr[idx] == "1")
                    wCorrect += 1
            } else {
                if (pixelArr[idx] == "0")
                    bCorrect += 1
            }
            x += 1
            idx += 1
        }
        x := 0
        y += 1
    }

    mW := (totalWhite == 0) ? 1 : totalWhite
    mB := (totalBlack == 0) ? 1 : totalBlack

    pCorrect := Round((((bCorrect / mB) + (wCorrect / mW)) / 2), 2)

    ; Return result object instead of using globals
    return {
        match: Round((pCorrect * 100), 0),
        white: Round((wCorrect / mW * 100), 0),
        black: Round((bCorrect / mB * 100), 0),
        raw: pCorrect
    }
}

BossHPCheck(pBitmap, hpw, hph, bossHealthMap) {
    isDead := 1
    x := 0, y := 0
    loop hph {
        loop hpw {
            color := Gdip_GetPixel(pBitmap, x, y)
            if (bossHealthMap.Has(String(color))) {
                isDead := 0
                break 2
            }
            x += 1
        }
        x := 0
        y += 1
    }
    return isDead
}

BossHPShowingUp(pBitmap, hpw, hph, bossHealthMap) {
    isThere := 0
    x := 0, y := 0
    loop hph {
        loop hpw {
            color := Gdip_GetPixel(pBitmap, x, y)
            if (bossHealthMap.Has(String(color))) {
                isThere := 1
                break 2
            }
            x += 1
        }
        x := 0
        y += 1
    }
    return isThere
}
