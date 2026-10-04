; ============================================================
;  Настройки и профиль
; ============================================================
class SettingsUI {
    static Open() {
        p := Store.Data["profile"], s := Store.Data["settings"]
        W := 760, B := Theme.Bg, C := Theme.Card
        g := UI.NewGui("Настройки")
        UI.DialogHead(g, W, Icon.Settings, "Настройки", "Профиль подставляется в бинды через {nick}, {name}, {rank}, {org} и {id}.")

        ; ---------- профиль ----------
        UI.Frame(g, 28, 100, 340, 330, C, 12)
        UI.Text(g, "x48 y116 w300 h22", "Профиль", C, 11, Theme.Text, 700)
        UI.Label(g, "x48 y148 w300 h16", "НИК В ИГРЕ", C)
        nickE := UI.Field(g, 48, 166, 300, 38, p["nick"], "Limit24")
        UI.Cue(nickE, "Ivan_Petrov")
        UI.Label(g, "x48 y216 w300 h16", "ДОЛЖНОСТЬ", C)
        rankE := UI.Field(g, 48, 234, 300, 38, p["rank"], "Limit40")
        UI.Cue(rankE, "Врач-терапевт")
        UI.Label(g, "x48 y284 w300 h16", "ОРГАНИЗАЦИЯ", C)
        orgE := UI.Field(g, 48, 302, 300, 38, p["org"], "Limit40")
        UI.Cue(orgE, "ЦГБ ЛС")
        UI.Label(g, "x48 y352 w300 h16", "ID ПАЦИЕНТА ПО УМОЛЧАНИЮ", C)
        idE := UI.Field(g, 48, 370, 110, 36, p["id"], "Number Limit4")
        hkIdT := UI.Text(g, "x170 y370 w180 h36 +0x200", "", C, 8, Theme.Faint)

        ; ---------- отправка ----------
        UI.Frame(g, 384, 100, 348, 330, C, 12)
        UI.Text(g, "x404 y116 w300 h22", "Отправка в чат", C, 11, Theme.Text, 700)
        UI.Label(g, "x404 y148 w148 h16", "КЛАВИША ЧАТА", C)
        chatS := Segmented(g, 404, 166, 148, 38, ["T", "F6"], s["chatKey"])
        UI.Label(g, "x568 y148 w144 h16", "РЕЖИМ ВВОДА", C)
        modeS := Segmented(g, 568, 166, 144, 38, ["Input", "Event"], s["sendMode"])
        UI.Label(g, "x404 y216 w100 h16", "ОТКРЫТИЕ, МС", C)
        openE := UI.Field(g, 404, 234, 96, 38, s["openDelay"], "Number Limit4 Center")
        UI.Label(g, "x510 y216 w100 h16", "ENTER, МС", C)
        enterE := UI.Field(g, 510, 234, 96, 38, s["enterDelay"], "Number Limit4 Center")
        UI.Label(g, "x616 y216 w100 h16", "СТРОКИ, МС", C)
        lineE := UI.Field(g, 616, 234, 96, 38, s["lineDelay"], "Number Limit5 Center")
        UI.Label(g, "x404 y284 w308 h16", "ПРОЦЕСС ИГРЫ", C)
        exeE := UI.Field(g, 404, 302, 308, 38, s["gameExe"], "Limit60")
        gameSw := SwitchCtl(g, 404, 356, 308, "Бинды только в окне игры", s["requireGame"], C)
        ruSw := SwitchCtl(g, 404, 390, 308, "Ставить русскую раскладку", s["forceRu"], C)

        ; ---------- горячие клавиши ----------
        UI.Frame(g, 28, 446, 704, 124, C, 12)
        UI.Text(g, "x48 y462 w300 h22", "Горячие клавиши MedBind", C, 11, Theme.Text, 700)
        UI.Text(g, "x352 y464 w360 h18 Right", "клик — нажать клавишу · Backspace — очистить", C, 8, Theme.Faint)
        defs := [["hkMenu", "ОКНО MEDBIND"], ["hkToggle", "ВКЛ / ВЫКЛ"], ["hkStop", "СТОП ОТПРАВКИ"], ["hkId", "ВВОД ID"]]
        hks := Map()
        for i, d in defs {
            x := 48 + (i - 1) * 168
            UI.Label(g, "x" x " y494 w160 h16", d[2], C)
            hks[d[1]] := KeyField(g, x, 512, 160, 38, s[d[1]])
            hks[d[1]].OnChange := (*) => Check()
        }

        ; ---------- низ ----------
        Btn.Add(g, "x28 y592 w150 h42", "Папка данных", (*) => Run(Store.Dir), "ghost", 10, Icon.Folder)
        errT := UI.Text(g, "x190 y592 w270 h42 +0x200", "", B, 9, Theme.Danger, 600)
        Btn.Add(g, "x472 y592 w120 h42", "Отмена", (*) => UI.CloseModal(g), "ghost")
        Btn.Add(g, "x600 y592 w132 h42", "Сохранить", Save, "primary", 10, Icon.Save)
        g.OnEvent("Close", (*) => UI.CloseModal(g))
        g.OnEvent("Escape", (*) => UI.CloseModal(g))
        UI.OpenModal(g, "w" W " h652")
        Check()

        ; проверка клавиш на лету — конфликт виден сразу
        Check() {
            v := hks["hkId"].Value
            hkIdT.Value := v = "" ? "быстрый ввод ID отключён" : "в игре: " Keys.Pretty(v) " + цифры"
            msg := KeyProblem()
            errT.Value := msg = "" ? "" : "⚠  " msg
            return msg
        }

        KeyProblem() {
            used := Map()
            for k, kf in hks {
                v := kf.Value
                if v = ""
                    continue
                if used.Has(v)
                    return "Клавиша " Keys.Pretty(v) " назначена дважды"
                used[v] := 1
                if (who := Store.HotkeyOwner(v)) != ""
                    return "Клавиша " Keys.Pretty(v) " уже у бинда «" who "»"
            }
            if hks["hkMenu"].Value = ""
                return "Укажите клавишу для открытия окна"
            return ""
        }

        Save(*) {
            nk := Trim(nickE.Value)
            if nk != "" && !RegExMatch(nk, "^[A-Za-z0-9]+(_[A-Za-z0-9]+)+$")
                return Fail("Ник должен быть в формате Ivan_Petrov", nickE)
            if (msg := Check()) != ""
                return Fail(msg)
            ex := Trim(exeE.Value)
            p["nick"] := nk
            p["rank"] := Trim(rankE.Value)
            p["org"] := Trim(orgE.Value)
            p["id"] := Trim(idE.Value)
            s["chatKey"] := chatS.Value
            s["sendMode"] := modeS.Value
            s["openDelay"] := Store.Num(openE.Value, 120)
            s["enterDelay"] := Store.Num(enterE.Value, 60)
            s["lineDelay"] := Max(100, Store.Num(lineE.Value, 1300))
            s["gameExe"] := ex != "" ? ex : "gta_sa.exe"
            s["requireGame"] := gameSw.State ? 1 : 0
            s["forceRu"] := ruSw.State ? 1 : 0
            for k, kf in hks
                s[k] := kf.Value
            Store.Save()
            Keys.Apply()
            UI.CloseModal(g)
            MainUI.UpdateProfile()
            MainUI.UpdateStatus()
            MainUI.Refresh()
            Toast.Show("Настройки сохранены", "MedBind", , "success")
        }

        Fail(msg, focus := 0) {
            errT.Value := "⚠  " msg
            SoundBeep(300, 120)
            if focus
                focus.Focus()
        }
    }
}
