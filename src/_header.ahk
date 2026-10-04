#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWorkingDir(A_ScriptDir)
DetectHiddenWindows(true)
if InStr(A_ScriptDir, A_Temp) && InStr(A_ScriptDir, ".zip") {
    MsgBox("Распакуйте архив в обычную папку и запустите DoctorBinder.ahk оттуда — иначе бинды не сохранятся.", "MedBind", "Icon!")
    ExitApp()
}

; ============================================================
;  MedBind 4.0 - биндер для медиков GTA SAMP RP
;  Запуск: двойной клик по этому файлу (нужен AutoHotkey v2)
; ============================================================

