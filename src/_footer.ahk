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
