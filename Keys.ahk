; Горячие клавиши. Клавиши биндов работают только в окне игры,
; чтобы F1-F5 и другие не ломались в браузере и других программах.
class Keys {
    static Enabled := true
    static List := []

    static Apply() {
        this.Clear()
        s := Store.Data["settings"]
        bad := []
        ctx := s["requireGame"] ? "ahk_exe " s["gameExe"] : ""

        ; глобальные (~ = нажатие не блокируется для других программ)
        HotIf()
        this.Add("~" s["hkMenu"], (*) => MainUI.Toggle(), "", bad)
        this.Add("~" s["hkToggle"], (*) => Keys.ToggleEnabled(), "", bad)

        ; только в игре
        this.SetCtx(ctx)
        this.Add(s["hkStop"], (*) => Sender.Stop(true), ctx, bad)
        this.Add(s["hkId"], (*) => Keys.AskId(), ctx, bad)
        for b in Store.Data["binds"]
            if b["enabled"] && b["hotkey"] != ""
                this.Add(b["hotkey"], this.Runner(b["id"]), ctx, bad)
        HotIf()

        if bad.Length
            Toast.Show("Не удалось назначить: " Join(bad), "Горячие клавиши")
    }

    static SetCtx(ctx) {
        if ctx = ""
            HotIf()
        else
            HotIfWinActive(ctx)
    }

    static Add(key, fn, ctx, bad) {
        if key = "" || key = "~"
            return
        key := Keys.Norm(key)
        try {
            Hotkey(key, fn, "On")
            this.List.Push({key: key, ctx: ctx})
        } catch {
            bad.Push(key)
        }
    }

    ; буквы/цифры → код клавиши (vk), чтобы работало на любой раскладке
    static Norm(key) {
        if RegExMatch(key, "^([~*$^!+#<>]*)([A-Za-z0-9])$", &m)
            return m[1] "vk" Format("{:X}", Ord(StrUpper(m[2])))
        return key
    }

    static Clear() {
        for item in this.List {
            this.SetCtx(item.ctx)
            try Hotkey(item.key, "Off")
        }
        HotIf()
        this.List := []
    }

    static Runner(id) {
        return (*) => Keys.Run(id)
    }

    static Run(id) {
        if !this.Enabled
            return
        if b := Store.Find(id)
            Sender.Start(b)
    }

    static IsSystem(hk) {
        s := Store.Data["settings"]
        for k in ["hkMenu", "hkToggle", "hkStop", "hkId"]
            if s[k] != "" && s[k] = hk
                return true
        return false
    }

    static ToggleEnabled() {
        this.Enabled := !this.Enabled
        if !this.Enabled
            Sender.Stop()
        Toast.Show(this.Enabled ? "Бинды снова работают" : "Бинды временно отключены", this.Enabled ? "Биндер включён" : "Биндер выключен")
        MainUI.UpdateStatus()
    }

    ; Ввод ID прямо в игре: нажми F9, набери цифры и Enter.
    ; Нажатия перехватываются и в игру не попадают.
    static AskId() {
        Toast.Show("Наберите ID и нажмите Enter (Esc — отмена)", "ID игрока", 8000)
        ih := InputHook("L4 T8", "{Enter}{Esc}")
        ih.Start()
        ih.Wait()
        ok := ih.EndReason = "Max" || (ih.EndReason = "EndKey" && ih.EndKey = "Enter")
        if ok && RegExMatch(ih.Input, "^\d{1,4}$") {
            Store.Data["profile"]["id"] := ih.Input
            Store.Save()
            MainUI.UpdateProfile()
            Toast.Show("Теперь {id} = " ih.Input, "ID сохранён")
        } else {
            Toast.Show("ID не изменён", "ID игрока")
        }
    }

    static Pretty(hk) {
        if hk = ""
            return "—"
        out := ""
        while RegExMatch(hk, "^[\^!+#~*$<>]", &m) {
            switch m[0] {
                case "^": out .= "Ctrl + "
                case "!": out .= "Alt + "
                case "+": out .= "Shift + "
                case "#": out .= "Win + "
            }
            hk := SubStr(hk, 2)
        }
        return out StrUpper(SubStr(hk, 1, 1)) SubStr(hk, 2)
    }
}
