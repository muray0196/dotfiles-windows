#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

excluded := ["DJMAX RESPECT V.exe", "hoge2.exe"]

IsExcluded(){
    global excluded
    for name in excluded
        if WinActive("ahk_exe " name)
            return true
    return false
}

#HotIf !IsExcluded()   ; 除外アプリはホットキー無効
^SC079::Send('{SC079}')
^SC07B::Send('{SC07B}')
^h::Send "{BS}"
#HotIf
