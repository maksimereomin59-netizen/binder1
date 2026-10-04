; Обмен биндами между игроками: код MEDBIND:... (можно кинуть в Discord/VK) или файл .medbind
class Share {
    static Prefix := "MEDBIND:"

    static Encode(binds) {
        list := []
        for b in binds
            list.Push(Map("name", b["name"], "category", b["category"], "hotkey", b["hotkey"], "delay", b["delay"], "lines", b["lines"]))
        return this.Prefix B64.Encode(Json.Stringify(Map("app", "medbind", "v", 1, "binds", list), ""))
    }

    ; Понимает: код MEDBIND:, чистый JSON и старые файлы .doctorprofile из Doctor Binder V3
    static Decode(text) {
        text := Trim(text, " `t`r`n")
        if text = ""
            throw Error("вставьте код или выберите файл")
        if RegExMatch(text, "i)MEDBIND:\s*([A-Za-z0-9+/=\s]+)", &m)
            text := B64.Decode(m[1])
        else if SubStr(text, 1, 1) != "{" && SubStr(text, 1, 1) != "["
            throw Error("это не код MedBind (должен начинаться с MEDBIND:)")
        return this.Extract(Json.Parse(text))
    }

    static Extract(data) {
        catMap := Map("general", "Общие", "treatment", "Лечение", "rp", "RP")
        src := data
        if (data is Map) && data.Has("profile") && (data["profile"] is Map)
            src := data["profile"]
        if (src is Map) && src.Has("categories") && (src["categories"] is Array) {
            for c in src["categories"]
                if (c is Map) && c.Has("id") && c.Has("name")
                    catMap[c["id"]] := c["name"]
        }
        list := 0
        if src is Array
            list := src
        else if (src is Map) && src.Has("binds")
            list := src["binds"]
        if !(list is Array)
            throw Error("в коде нет списка биндов")
        out := []
        for item in list
            if item is Map
                out.Push(this.ToBind(item, catMap))
        if !out.Length
            throw Error("список биндов пуст")
        return out
    }

    static ToBind(src, catMap) {
        b := Store.NewBind()
        b["name"] := src.Has("name") && src["name"] != "" ? SubStr(String(src["name"]), 1, 60) : "Без названия"
        if src.Has("category") && src["category"] != ""
            b["category"] := SubStr(String(src["category"]), 1, 30)
        else if src.Has("categoryId") && catMap.Has(src["categoryId"])
            b["category"] := catMap[src["categoryId"]]
        if src.Has("hotkey")
            b["hotkey"] := String(src["hotkey"])
        if src.Has("delay") && Store.Num(src["delay"], 0) > 0
            b["delay"] := Store.Num(src["delay"], b["delay"])
        lines := src.Has("lines") ? src["lines"] : ""
        if lines is Array {            ; старый формат: массив строк со своими задержками
            txt := ""
            for i, l in lines {
                if !(l is Map) {
                    txt .= String(l) "`n"
                    continue
                }
                if l.Has("enabled") && !l["enabled"]
                    continue
                t := l.Has("text") ? String(l["text"]) : ""
                if l.Has("sendEnter") && !l["sendEnter"]
                    t .= " {noenter}"
                txt .= t "`n"
                d := l.Has("delay") ? Store.Num(l["delay"], 0) : 0
                if d > 0 && i < lines.Length && d != b["delay"]
                    txt .= "{wait " d "}`n"
            }
            lines := txt
        }
        b["lines"] := Store.MigrateVars(RTrim(StrReplace(String(lines), "`r"), "`n"))
        return b
    }

    ; ---------- окно «Поделиться» ----------
    static ExportDialog(ids) {
        binds := []
        for id in ids
            if b := Store.Find(id)
                binds.Push(b)
        if !binds.Length {
            Toast.Show("Сначала выберите бинды в списке", "Поделиться", , "info")
            return
        }
        code := this.Encode(binds)
        A_Clipboard := code
        W := 640, B := Theme.Bg, C := Theme.Card
        g := UI.NewGui("Поделиться биндами")
        UI.DialogHead(g, W, Icon.Share, "Код для обмена готов", "Код уже в буфере обмена. Отправьте его игроку — он нажмёт «Импорт» в MedBind и вставит код.")
        UI.Label(g, "x28 y104 w" (W - 56) " h16", "БИНДЫ  ·  " binds.Length, B)
        UI.Frame(g, 28, 124, W - 56, 160, C, 10)
        rv := RichView(g, 42, 136, W - 84, 138, C)
        out := Rtf.Head(17)
        for b in binds
            out .= Rtf.P(Rtf.C(b["hotkey"] = "" ? 4 : 5, Format("{:-10}", b["hotkey"] = "" ? "—" : Keys.Pretty(b["hotkey"]))) Rtf.C(1, "  " b["name"]) Rtf.C(3, "   " b["category"] " · " Preview.Msgs(Sender.Plan(b).Length)), 50)
        rv.Set(out "}")
        UI.Label(g, "x28 y300 w" (W - 56) " h16", "КОД MEDBIND", B)
        UI.Field(g, 28, 320, W - 56, 92, code, "ReadOnly Multi", true)
        Btn.Add(g, "x28 y432 w170 h40", "Сохранить файл", (*) => Share.SaveFile(code, g), "ghost", 10, Icon.Save)
        Btn.Add(g, "x" (W - 308) " y432 w136 h40", "Копировать", (*) => (A_Clipboard := code, Toast.Show("Код скопирован", "Поделиться", , "success")), "ghost", 10, Icon.Copy)
        Btn.Add(g, "x" (W - 164) " y432 w136 h40", "Готово", (*) => UI.CloseModal(g), "primary", 10, Icon.Check)
        g.OnEvent("Close", (*) => UI.CloseModal(g))
        g.OnEvent("Escape", (*) => UI.CloseModal(g))
        UI.OpenModal(g, "w" W " h500")
    }

    static SaveFile(code, owner) {
        owner.Opt("+OwnDialogs")
        path := FileSelect("S16", A_Desktop "\binds.medbind", "Сохранить бинды", "MedBind (*.medbind)")
        if path = ""
            return
        if !RegExMatch(path, "i)\.medbind$")
            path .= ".medbind"
        try FileDelete(path)
        FileAppend(code, path, "UTF-8")
        Toast.Show("Файл сохранён", "Поделиться")
    }

    ; ---------- окно «Импорт» ----------
    static ImportDialog() {
        parsed := []
        W := 680, B := Theme.Bg, C := Theme.Card
        g := UI.NewGui("Импорт биндов")
        UI.DialogHead(g, W, Icon.Import, "Импорт биндов", "Вставьте код MEDBIND:… от другого игрока или откройте файл .medbind / .doctorprofile.")
        UI.Label(g, "x28 y104 w" (W - 56) " h16", "КОД", B)
        clip := ""
        try clip := A_Clipboard
        codeE := UI.Field(g, 28, 124, W - 56, 96, InStr(clip, "MEDBIND:") ? clip : "", "Multi", true)
        UI.Label(g, "x28 y236 w" (W - 56) " h16", "ЧТО БУДЕТ ДОБАВЛЕНО", B)
        UI.Frame(g, 28, 256, W - 56, 200, C, 10)
        rv := RichView(g, 42, 268, W - 84, 178, C)
        keepSw := SwitchCtl(g, 28, 470, 420, "Сохранить клавиши (если они свободны)", true, B)
        Btn.Add(g, "x28 y516 w140 h40", "Из файла…", FromFile, "ghost", 10, Icon.Folder)
        Btn.Add(g, "x" (W - 308) " y516 w124 h40", "Отмена", (*) => UI.CloseModal(g), "ghost")
        Btn.Add(g, "x" (W - 176) " y516 w148 h40", "Импортировать", DoImport, "primary", 10, Icon.Import)
        codeE.OnEvent("Change", Update)
        keepSw.OnChange := Update
        g.OnEvent("Close", (*) => UI.CloseModal(g))
        g.OnEvent("Escape", (*) => UI.CloseModal(g))
        UI.OpenModal(g, "w" W " h584")
        Update()

        Update(*) {
            parsed.Length := 0
            if Trim(codeE.Value) = "" {
                rv.Set(Preview.Message("Здесь появится список биндов из кода. Проверьте текст перед импортом.", 4))
                return
            }
            try {
                for b in Share.Decode(codeE.Value)
                    parsed.Push(b)
            } catch Error as err {
                rv.Set(Preview.Message("Код не распознан: " err.Message, 9))
                return
            }
            rv.Set(Preview.Import(parsed, keepSw.State))
        }

        FromFile(*) {
            g.Opt("+OwnDialogs")
            path := FileSelect("1", A_Desktop, "Открыть бинды", "MedBind (*.medbind; *.doctorprofile; *.json)")
            if path = ""
                return
            codeE.Value := FileRead(path, "UTF-8")
            Update()
        }

        DoImport(*) {
            if !parsed.Length {
                Toast.Show("Сначала вставьте правильный код", "Импорт", , "error")
                return
            }
            freed := 0
            for b in parsed {
                hk := b["hotkey"]
                if hk != "" && (!keepSw.State || Store.HotkeyOwner(hk) != "" || Keys.IsSystem(hk)) {
                    b["hotkey"] := ""
                    if keepSw.State
                        freed++
                }
                Store.EnsureCategory(b["category"])
                Store.Data["binds"].Push(b)
            }
            Store.Save()
            Keys.Apply()
            UI.CloseModal(g)
            MainUI.Refresh()
            msg := "Добавлено биндов: " parsed.Length
            if freed
                msg .= "`nУ " freed " клавиша была занята — назначьте вручную"
            Toast.Show(msg, "Импорт завершён", 3500, freed ? "warning" : "success")
        }
    }
}
