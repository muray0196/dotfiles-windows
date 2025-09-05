#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

excluded := ["hoge.exe", "hoge2.exe"]

IsExcluded(){
    global excluded
    for name in excluded
        if WinActive("ahk_exe " name)
            return true
    return false
}

#HotIf !IsExcluded()   ; 除外アプリはホットキー無効
^h::Send "{BS}"
#HotIf