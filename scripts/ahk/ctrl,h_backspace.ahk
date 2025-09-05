#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

^SC079::Send('{SC079}')
^SC07B::Send('{SC07B}')

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
