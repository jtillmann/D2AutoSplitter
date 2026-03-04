#Requires AutoHotkey v2.0
#SingleInstance Force
#KeyHistory 0
ListLines False
ProcessSetPriority "High"
SetWinDelay -1
SetControlDelay -1
SendMode "Input"
#Include "Gdip_v2.ahk"
SetWorkingDir A_ScriptDir
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

; Include Modules
#Include "Modules/Utilities.ahk"
#Include "Modules/Layouts.ahk"
#Include "Modules/SplitEngine.ahk"
#Include "Modules/SplitManager.ahk"
#Include "Modules/ImageMaker.ahk"
#Include "Modules/MainGui.ahk"

; Initialize Global State (Class Instances)
global EngineMgr := SplitEngine()
global SplitMgr  := SplitManager()
global ImgMaker  := ImageMaker()
global MainMgr   := MainGui()
global Autosplitter := MainMgr.Gui

; LiveSplit specific settings
global WinTitle := "LiveSplit"

; Initial directory and dependency setup
InitializeEnvironment()

; Global GDI+ Token
global pToken := Gdip_Startup()
InitializeImages()

; Start Application
MainMgr.SetHotkeys()
MainMgr.Show()

; --- Input Hooks (Routing to EngineMgr) ---
~$w::
~$a::
~$s::
~$d::
~+$w::
~+$a::
~+$s::
~+$d::
~$Space::
~$3::
~$WheelDown::
~$WheelUp::
~$e::
    {
        EngineMgr.InputKeyPressed()
    }

; --- Main Global Hotkeys ---
~^F7:: { ; Ctrl+F7 to toggle transparency
    global WinTitle, Activate := (IsSet(Activate) ? Activate : 0)
    if (Activate == 1) {
        Activate := 0
        WinSetExStyle "-0x20", WinTitle
        WinSetTransColor "Off", WinTitle
    } else {
        Activate := 1
        WinSetExStyle "+0x20", WinTitle
        WinSetTransColor "0x000000", WinTitle
    }
}

^F4::Reload()

; --- Initialization Helpers ---

InitializeEnvironment() {
    if !DirExist(A_ScriptDir "\Dependencies") {
        DirCreate A_ScriptDir "\Dependencies"
        FileAppend "", A_ScriptDir "\Dependencies\settings.txt"
    }
    if !DirExist(A_ScriptDir "\Split_Files")
        DirCreate A_ScriptDir "\Split_Files"
    if !DirExist(A_ScriptDir "\Split_Images") {
        DirCreate A_ScriptDir "\Split_Images"
        FileAppend "0x000000&0x000000&0|0|1|1", A_ScriptDir "\Split_Images\image_info.txt"
    }
}

InitializeImages() {
    global realImage := A_ScriptDir "\Dependencies\real_image.png"
    global BnWImage  := A_ScriptDir "\Dependencies\BnW.png"
    global scshot    := A_ScriptDir "\Dependencies\fullScreenshot.png"
    global tmpImage   := A_ScriptDir "\Dependencies\tmp.png"

    pBitmap := Gdip_BitmapFromScreen("0|0|1|1")
    Gdip_SaveBitmapToFile(pBitmap, realImage)
    Gdip_SaveBitmapToFile(pBitmap, BnWImage)
    Gdip_DisposeImage(pBitmap)
}
