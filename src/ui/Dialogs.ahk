; ============================================================
;  Диалоги в едином стиле (вместо системных MsgBox / InputBox)
; ============================================================
class Dialogs {
    ; ввод строки; возвращает текст или ""
    static Prompt(title, label, def := "", owner := 0) {
        res := {v: "", ok: false}
        g := UI.NewGui(title, owner)
        UI.DialogHead(g, 420, Icon.Edit, title, label)
        e := UI.Field(g, 28, 104, 364, 42, def, "Limit40")
        g.AddButton("Default x-300 y-300 w10 h10", "ok").OnEvent("Click", Done)
        Btn.Add(g, "x180 y170 w100 h40", "Отмена", (*) => UI.CloseModal(g), "ghost")
        Btn.Add(g, "x290 y170 w102 h40", "Готово", Done, "primary")
        g.OnEvent("Close", (*) => UI.CloseModal(g))
        g.OnEvent("Escape", (*) => UI.CloseModal(g))
        UI.OpenModal(g, "w420 h234")
        e.Focus()
        SendMessage(0xB1, 0, -1, e)
        WinWaitClose("ahk_id " g.Hwnd)
        return res.ok ? Trim(res.v) : ""

        Done(*) {
            res.v := e.Value
            res.ok := true
            UI.CloseModal(g)
        }
    }

    ; подтверждение; true — если пользователь согласился
    static Confirm(title, text, okText := "Удалить", danger := true, owner := 0) {
        res := {ok: false}
        g := UI.NewGui(title, owner)
        UI.DialogHead(g, 460, danger ? Icon.Delete : Icon.Warning, title, "", danger ? "danger" : "warning")
        UI.Text(g, "x84 y54 w348 h66", text, Theme.Bg, 9, Theme.Soft)
        Btn.Add(g, "x212 y138 w100 h40", "Отмена", (*) => UI.CloseModal(g), "ghost")
        Btn.Add(g, "x322 y138 w110 h40", okText, Ok, danger ? "danger" : "primary", 10, danger ? Icon.Delete : "")
        g.OnEvent("Close", (*) => UI.CloseModal(g))
        g.OnEvent("Escape", (*) => UI.CloseModal(g))
        UI.OpenModal(g, "w460 h202")
        WinWaitClose("ahk_id " g.Hwnd)
        return res.ok

        Ok(*) {
            res.ok := true
            UI.CloseModal(g)
        }
    }

    ; сообщение об ошибке / информация. kind: error | warning | info
    static Alert(title, text, kind := "error", owner := 0) {
        g := UI.NewGui(title, owner)
        tone := kind = "error" ? "danger" : kind = "warning" ? "warning" : "accent"
        UI.DialogHead(g, 460, kind = "error" ? Icon.Error : kind = "warning" ? Icon.Warning : Icon.Info, title, "", tone)
        UI.Text(g, "x84 y54 w348 h130", text, Theme.Bg, 9, Theme.Soft)
        Btn.Add(g, "x322 y198 w110 h40", "Понятно", (*) => UI.CloseModal(g), "primary")
        g.OnEvent("Close", (*) => UI.CloseModal(g))
        g.OnEvent("Escape", (*) => UI.CloseModal(g))
        UI.OpenModal(g, "w460 h262")
        WinWaitClose("ahk_id " g.Hwnd)
    }

    ; создание / изменение категории: имя + иконка. Возвращает {name, icon} или 0
    static Category(title, name := "", iconKey := "folder", owner := 0) {
        res := {ok: false, name: name, icon: iconKey = "" ? "folder" : iconKey}
        orig := name
        g := UI.NewGui(title, owner)
        UI.DialogHead(g, 420, Icon.Folder, title, "Название и иконка показываются в боковой панели")
        UI.Label(g, "x28 y98 w200 h16", "НАЗВАНИЕ", Theme.Bg)
        e := UI.Field(g, 28, 118, 364, 42, name, "Limit24")
        UI.Label(g, "x28 y176 w200 h16", "ИКОНКА", Theme.Bg)
        tiles := Map()
        for i, key in Icon.CatKeys {
            col := Mod(i - 1, 6), row := (i - 1) // 6
            t := UI.IconText(g, "x" (28 + col * 62) " y" (198 + row * 50) " w54 h42 +0x100", Icon.Cat[key], Theme.Field, 13, Theme.Muted, true)
            Theme.Round(t, 54, 42, 8)
            t.OnEvent("Click", Picker_(key))
            tiles[key] := t
        }
        err := UI.Text(g, "x28 y310 w180 h40 +0x200", "", Theme.Bg, 9, Theme.Danger)
        g.AddButton("Default x-300 y-300 w10 h10", "ok").OnEvent("Click", Done)
        Btn.Add(g, "x182 y310 w100 h40", "Отмена", (*) => UI.CloseModal(g), "ghost")
        Btn.Add(g, "x292 y310 w100 h40", "Сохранить", Done, "primary")
        Paint()
        g.OnEvent("Close", (*) => UI.CloseModal(g))
        g.OnEvent("Escape", (*) => UI.CloseModal(g))
        UI.OpenModal(g, "w420 h374")
        e.Focus()
        SendMessage(0xB1, 0, -1, e)
        WinWaitClose("ahk_id " g.Hwnd)
        return res.ok ? {name: res.name, icon: res.icon} : 0

        Picker_(key) {
            return (*) => (res.icon := key, Paint())
        }
        Paint() {
            for key, t in tiles {
                on := key = res.icon
                t.SetFont("c" (on ? Theme.Accent : Theme.Muted))
                UI.Paint(t, on ? Theme.AccentSoft : Theme.Field)
            }
        }
        Done(*) {
            n := Trim(e.Value)
            if n = ""
                return err.Value := "Введите название"
            for c in Store.Data["categories"]
                if c = n && c != orig
                    return err.Value := "Такая категория уже есть"
            res.name := n, res.ok := true
            UI.CloseModal(g)
        }
    }
}

; совместимость со старыми вызовами
UI.DefineProp("Prompt", {Call: (this, p*) => Dialogs.Prompt(p*)})
UI.DefineProp("Confirm", {Call: (this, p*) => Dialogs.Confirm(p*)})
UI.DefineProp("Alert", {Call: (this, p*) => Dialogs.Alert(p*)})
