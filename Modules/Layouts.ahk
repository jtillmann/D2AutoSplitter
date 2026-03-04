#Requires AutoHotkey v2.0

class Layouts {
    ; --- Main GUI Layout ---
    static Main := [
        { Type: "Picture", Opt: "x0 y0 w721 h520", Text: "backgroundimage.png" }, 
        { Type: "Text", Opt: "x8 y432 w125 h15 +0x200", Text: "Made By A2TC - Improved By Scope" }, 
        { Type: "GroupBox", Opt: "x480 y60 w230 h200" }, 
        { Type: "GroupBox", Opt: "x480 y270 w230 h170", Text: "Hotkeys" },
        ; Hotkeys
        { Type: "Hotkey", Opt: "x570 y290 w130 h21", Ref: "ctrlHk1" }, 
        { Type: "Hotkey", Opt: "x570 y320 w130 h21", Ref: "ctrlHk2" }, 
        { Type: "Hotkey", Opt: "x570 y380 w130 h21", Ref: "ctrlHk4" }, 
        { Type: "Hotkey", Opt: "x570 y350 w130 h21", Ref: "ctrlHk3" },
        ; Buttons   
        { Type: "Button", Opt: "x10 y10 w120 h30", Text: "Create New Splits", Event: "OnSaveSplitFileEmpty" }, 
        { Type: "Button", Opt: "x140 y10 w100 h30", Text: "Open Splits", Event: "OnLoadSplitsToUse" }, 
        { Type: "Button", Opt: "x450 y10 w100 h30 +Hidden", Text: "Edit Splits", Ref: "ctrlEditSplitsBtn", Event: "OnEditSplits" }, 
        { Type: "Button", Opt: "x560 y10 w150 h30", Text: "Create Split Image", Event: "OnCreateSplitImage" },
        ; Engine Controls         
        { Type: "Button", Opt: "x490 y180 w210 h40", Text: "Start", Ref: "ctrlStartBtn", Event: "OnStartAutoSplitter" }, 
        { Type: "Button", Opt: "x490 y130 w210 h40", Text: "Reset", Event: "OnStopEngine" }, 
        { Type: "Button", Opt: "x600 y80 w100 h40", Text: "Next >", Event: "OnSkipSplit" }, 
        { Type: "Button", Opt: "x490 y80 w100 h40", Text: "< Previous", Event: "OnUndoSplit" }, 
        { Type: "Button", Opt: "x640 y410 w60 h20", Text: "Set", Event: "SetHotkeys" },
        ; Labels & Info                  
        { Type: "Text", Opt: "x250 y12 w150 h23 +0x200", Ref: "ctrlSplitFile" }, 
        { Type: "Text", Opt: "x10 y70 w300 h300 +0x200 +Center +Border", Ref: "ctrlTimerText" }, 
        { Type: "Picture", Opt: "x10 y70 w300 h300 +Border", Ref: "ctrlCurrImg" }, 
        { Type: "Text", Opt: "x490 y290 w60 h20 +0x200", Text: "Start/Split" }, 
        { Type: "Text", Opt: "x490 y320 w60 h20 +0x200", Text: "Reset" }, 
        { Type: "Text", Opt: "x490 y350 w60 h20 +0x200", Text: "Skip Split" }, 
        { Type: "Text", Opt: "x490 y380 w60 h20 +0x200", Text: "Undo Split" }, 
        { Type: "CheckBox", Opt: "x490 y227 w17 h24", Ref: "ctrlWaitInput" }, 
        { Type: "Text", Opt: "x510 y230 w150 h20 +0x200", Text: "Start waits for First Input", Ref: "ctrlWaitInputTitle" }, 
        { Type: "Text", Opt: "x325 y70 w150 h15", Text: "Previous Split" }, 
        { Type: "Text", Opt: "x325 y130 w150 h15", Text: "Current Split" }, 
        { Type: "Text", Opt: "x325 y170 w150 h15", Text: "Current Image" }, 
        { Type: "Text", Opt: "x325 y235 w150 h15", Text: "Next Split" }, 
        { Type: "Text", Opt: "x325 y85 w150 h25", Ref: "ctrlPrev" }, 
        { Type: "Text", Opt: "x325 y145 w150 h25", Ref: "ctrlCurr" }, 
        { Type: "Text", Opt: "x325 y185 w150 h25", Ref: "ctrlSplitImgName" }, 
        { Type: "Text", Opt: "x325 y250 w150 h25", Ref: "ctrlNext" },
        ; Stats                                                                             
        { Type: "Text", Opt: "x10 y380 w25 h20 +0x200 +Right", Text: "0", Ref: "ctrlLoopCount" }, 
        { Type: "Text", Opt: "x40 y380 w30 h20 +0x200", Text: "FPS" }, 
        { Type: "Text", Opt: "x70 y380 w25 h20 +0x200 +Right", Text: "0", Ref: "ctrlPMatch" }, 
        { Type: "Text", Opt: "x97 y380 w40 h20 +0x200", Text: "% Match" }, 
        { Type: "Text", Opt: "x150 y380 w25 h20 +0x200 +Right", Text: "0", Ref: "ctrlPWhite" }, 
        { Type: "Text", Opt: "x177 y380 w40 h20 +0x200", Text: "% White" }, 
        { Type: "Text", Opt: "x230 y380 w25 h20 +0x200 +Right", Text: "0", Ref: "ctrlPBlack" }, 
        { Type: "Text", Opt: "x257 y380 w70 h20 +0x200", Text: "% Black" }
    ]

    ; --- Split Manager Layout ---
    static SplitManager := [
        { Type: "Button", Opt: "x480 y10 w100 h30", Text: "Save and close", Event: "SaveAndClose" }, 
        { Type: "Button", Opt: "x30 y10 w100 h30", Text: "Add Split", Event: "OnAddButtonClick" }, 
        { Type: "Button", Opt: "x140 y10 w100 h30", Text: "Remove Split", Event: "OnRemoveButtonClick" }, 
        { Type: "Text", Opt: "x30 y60 w120 h20 +0x200 +Left", Text: "Split Name" }, 
        { Type: "Text", Opt: "x180 y60 w120 h20 +0x200 +Left", Text: "Image to Find" }, 
        { Type: "Text", Opt: "x350 y60 w70 h23 +0x200 +Left", Text: "Dummy" }, 
        { Type: "Text", Opt: "x410 y60 w60 h23 +0x200 +Left", Text: "Threshold" }, 
        { Type: "Text", Opt: "x500 y60 w120 h23 +0x200 +Left", Text: "Delay (s)" }
    ]

    static SplitManagerRow(index, offset) => [
        { Type: "Text", Opt: "x10 y" (61 + offset) " w20 h23", Text: index "." }, 
        { Type: "Edit", Opt: "x30 y" (56 + offset) " w140 h24", Ref: "ctrlNames", ParentIdx: index }, 
        { Type: "DropDownList", Opt: "x180 y" (56 + offset) " w160", Ref: "ctrlImages", ParentIdx: index }, 
        { Type: "CheckBox", Opt: "x370 y" (56 + offset) " w17 h24", Ref: "ctrlDummies", ParentIdx: index }, 
        { Type: "Edit", Opt: "x420 y" (56 + offset) " w77 h24 number +Center", Text: "0.90", Ref: "ctrlThresholds", ParentIdx: index }, 
        { Type: "Edit", Opt: "x500 y" (56 + offset) " w77 h24 number +Center", Text: "7", Ref: "ctrlDelays", ParentIdx: index }
    ]

    ; --- Image Maker Layout ---
    static ImageMaker := [
        { Type: "GroupBox", Opt: "x12 y-1 w140 h540", Text: "Settings" }, 
        { Type: "Button", Opt: "x22 y15 w120 h50", Text: "Freeze Screen", Ref: "ctrlCapture", Event: "Capture" }, 
        { Type: "Button", Opt: "x22 y15 w120 h50 +Hidden", Text: "Unfreeze Screen", Ref: "ctrlUncapture", Event: "Uncapture" }, 
        { Type: "Hotkey", Opt: "x27 y70 w110 h20", Ref: "ctrlHkCapture" }, 
        { Type: "Button", Opt: "x52 y92 w60 h23", Text: "Set", Event: "OnSetHotkeys" }, 
        { Type: "Button", Opt: "x22 y115 w120 h50", Text: "Select Area", Event: "SelectArea" }, 
        { Type: "Button", Opt: "x22 y165 w120 h50", Text: "Save Current Image", Event: "Save" }, 
        { Type: "Button", Opt: "x22 y480 w120 h50", Text: "Open Boss HP Bar Color Finder", Event: "OpenHPFinder" },
        ; Directional Controls  
        { Type: "Text", Opt: "x70 y219 w80 h20", Text: "Top" }, 
        { Type: "Text", Opt: "x63 y242 w38 h15 +Border +Center", Text: "0", Ref: "ctrlTopNum" }, 
        { Type: "Button", Opt: "x21 y239 w21 h20", Text: "-10", Event: "Move", Args: ["Top", -10] }, 
        { Type: "Button", Opt: "x122 y239 w24 h20", Text: "+10", Event: "Move", Args: ["Top", 10] }, 
        { Type: "Button", Opt: "x42 y239 w20 h20", Text: "-1", Event: "Move", Args: ["Top", -1] }, 
        { Type: "Button", Opt: "x102 y239 w20 h20", Text: "+1", Event: "Move", Args: ["Top", 1] }, 
        { Type: "Text", Opt: "x65 y289 w80 h20", Text: "Bottom" }, 
        { Type: "Text", Opt: "x63 y312 w38 h15 +Border +Center", Text: "0", Ref: "ctrlBotNum" }, 
        { Type: "Button", Opt: "x21 y309 w21 h20", Text: "-10", Event: "Move", Args: ["Bottom", -10] }, 
        { Type: "Button", Opt: "x122 y309 w24 h20", Text: "+10", Event: "Move", Args: ["Bottom", 10] }, 
        { Type: "Button", Opt: "x42 y309 w20 h20", Text: "-1", Event: "Move", Args: ["Bottom", -1] }, 
        { Type: "Button", Opt: "x102 y309 w20 h20", Text: "+1", Event: "Move", Args: ["Bottom", 1] }, 
        { Type: "Text", Opt: "x70 y359 w80 h20", Text: "Left" }, 
        { Type: "Text", Opt: "x63 y382 w38 h15 +Border +Center", Text: "0", Ref: "ctrlLeftNum" }, 
        { Type: "Button", Opt: "x21 y379 w21 h20", Text: "-10", Event: "Move", Args: ["Left", -10] }, 
        { Type: "Button", Opt: "x122 y379 w24 h20", Text: "+10", Event: "Move", Args: ["Left", 10] }, 
        { Type: "Button", Opt: "x42 y379 w20 h20", Text: "-1", Event: "Move", Args: ["Left", -1] }, 
        { Type: "Button", Opt: "x102 y379 w20 h20", Text: "+1", Event: "Move", Args: ["Left", 1] }, 
        { Type: "Text", Opt: "x67 y429 w80 h20", Text: "Right" }, 
        { Type: "Text", Opt: "x63 y452 w38 h15 +Border +Center", Text: "0", Ref: "ctrlRightNum" }, 
        { Type: "Button", Opt: "x21 y449 w21 h20", Text: "-10", Event: "Move", Args: ["Right", -10] }, 
        { Type: "Button", Opt: "x122 y449 w24 h20", Text: "+10", Event: "Move", Args: ["Right",10] }, 
        { Type: "Button", Opt: "x42 y449 w20 h20", Text: "-1", Event: "Move", Args: ["Right", -1] }, 
        { Type: "Button", Opt: "x102 y449 w20 h20", Text: "+1", Event: "Move", Args: ["Right",1] }, 
        { Type: "GroupBox", Opt: "x162 y-1 w530 h510", Text: "Black and White Pixels" }, 
        { Type: "GroupBox", Opt: "x702 y-1 w530 h510", Text: "Actual Image" }, 
        { Type: "Picture", Opt: "x712 y19 w510 h480", Text: "real_image.png", Ref: "ctrlRealPic" }, 
        { Type: "Picture", Opt: "x172 y19 w510 h480", Text: "BnW.png", Ref: "ctrlBnWPic" }, 
        { Type: "Text", Opt: "x270 y520 w100 h20", Text: "Percentage White:" }, 
        { Type: "Text", Opt: "x360 y520 w50 h20", Text: "0", Ref: "ctrlPW" }, 
        { Type: "Text", Opt: "x520 y520 w100 h20", Text: "Total Pixels:" }, 
        { Type: "Text", Opt: "x580 y520 w150 h20", Text: "0", Ref: "ctrlTP" }, 
        { Type: "Text", Opt: "x2 y538 w120 h10", Text: "Made by A2TC", Font: "s6, Verdana" }
    ]

    static HPFinder := [
        { Type: "Button", Opt: "x8 y8 w57 h128", Text: "Save Colors", Event: "SaveHPBarColors" }, 
        { Type: "Button", Opt: "x8 y146 w57 h56", Text: "Set Bar Location", Event: "SetBarLocation" }, 
        { Type: "Button", Opt: "x72 y168 w149 h46", Text: "Find Dark Color", Event: "SetDarkColor" }, 
        { Type: "Button", Opt: "x224 y168 w149 h46", Text: "Find Light Color", Event: "SetLightColor" }, 
        { Type: "Text", Opt: "x72 y137 w149 h28 +0x200 +Center", Text: "Dark Color" }, 
        { Type: "Text", Opt: "x224 y136 w149 h28 +0x200 +Center", Text: "Light Color" }, 
        { Type: "Picture", Opt: "x72 y8 w149 h129", Ref: "ctrlDarkHPColor" }, 
        { Type: "Picture", Opt: "x224 y8 w149 h129", Ref: "ctrlLightHPColor" }
    ]
}
