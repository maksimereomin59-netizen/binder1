#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWorkingDir(A_ScriptDir)
DetectHiddenWindows(true)

; ============================================================
;  MedBind 4.0 - биндер для медиков GTA SAMP RP
;  Запуск: двойной клик по этому файлу (нужен AutoHotkey v2)
; ============================================================

#Include lib\App.ahk
#Include lib\Json.ahk
#Include lib\Store.ahk
#Include lib\Sender.ahk
#Include lib\Keys.ahk
#Include lib\Share.ahk
#Include lib\Theme.ahk
#Include lib\Controls.ahk
#Include lib\Dialogs.ahk
#Include lib\Preview.ahk
#Include lib\Toast.ahk
#Include lib\MainUI.ahk
#Include lib\Editor.ahk
#Include lib\SettingsUI.ahk

A_IconTip := App.Name " " App.Version
A_TrayMenu.Delete()
A_TrayMenu.Add("Открыть MedBind", (*) => MainUI.Show())
A_TrayMenu.Add("Вкл / выкл биндер", (*) => Keys.ToggleEnabled())
A_TrayMenu.Add()
A_TrayMenu.Add("Перезапустить", (*) => Reload())
A_TrayMenu.Add("Выход", (*) => ExitApp())
A_TrayMenu.Default := "Открыть MedBind"

try {
    Theme.Init()
    Store.Load()
    Keys.Apply()
    MainUI.Show()
} catch Error as err {
    msg := "Не удалось запустить MedBind:`n`n" err.Message "`n`nФайл: " err.File "`nСтрока: " err.Line
    try Dialogs.Alert("Ошибка запуска", msg, "error")
    catch
        MsgBox(msg, App.Name, "Iconx")
    ExitApp(1)
}
