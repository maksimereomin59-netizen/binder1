; Хранилище: один файл data\binder.json
class Store {
    static Dir := A_ScriptDir "\data"
    static File := A_ScriptDir "\data\binder.json"
    static Data := Map()
    static Seq := 0

    static Load() {
        if !DirExist(this.Dir)
            DirCreate(this.Dir)
        this.Data := Map()
        if FileExist(this.File) {
            try {
                this.Data := Json.Parse(FileRead(this.File, "UTF-8"))
            } catch Error as err {
                broken := this.Dir "\binder.broken-" A_Now ".json"
                try FileCopy(this.File, broken, true)
                msg := "Файл биндов повреждён, создан новый.`nСтарый сохранён как:`n" broken "`n`n" err.Message
                try Dialogs.Alert("Файл биндов повреждён", msg, "warning")
                catch
                    MsgBox(msg, App.Name, "Icon!")
                this.Data := Map()
            }
        }
        this.Normalize()
        this.Save()
    }

    static Save() {
        tmp := this.File ".tmp"
        try FileDelete(tmp)
        FileAppend(Json.Stringify(this.Data), tmp, "UTF-8")
        if FileExist(this.File)
            try FileCopy(this.File, this.Dir "\binder.backup.json", true)
        FileMove(tmp, this.File, true)
    }

    static DefaultSettings() {
        return Map(
            "chatKey", "T",
            "openDelay", 120,
            "enterDelay", 60,
            "lineDelay", 1300,
            "sendMode", "Input",
            "keyDelay", 15,
            "requireGame", 1,
            "gameExe", "gta_sa.exe",
            "forceRu", 1,
            "hkMenu", "F11",
            "hkToggle", "F12",
            "hkStop", "End",
            "hkId", "F9"
        )
    }

    static Normalize() {
        if !(this.Data is Map)
            this.Data := Map()
        d := this.Data
        firstRun := !d.Has("binds")
        d["version"] := 4
        if !d.Has("profile") || !(d["profile"] is Map)
            d["profile"] := Map()
        this.Fill(d["profile"], Map("nick", "", "rank", "", "org", "Больница ЛС", "id", ""))
        if !d.Has("settings") || !(d["settings"] is Map)
            d["settings"] := Map()
        this.Fill(d["settings"], this.DefaultSettings())
        if !d["settings"].Has("catIcons") || !(d["settings"]["catIcons"] is Map)
            d["settings"]["catIcons"] := Map()
        if !d.Has("categories") || !(d["categories"] is Array)
            d["categories"] := []
        if firstRun
            d["binds"] := this.StarterBinds()
        if !(d["binds"] is Array)
            d["binds"] := []
        clean := []
        for b in d["binds"] {
            if b is Map {
                this.Fill(b, this.NewBind())
                clean.Push(b)
            }
        }
        d["binds"] := clean
        if d["categories"].Length = 0
            d["categories"] := ["Общие", "Лечение", "RP"]
        for b in clean
            this.EnsureCategory(b["category"])
    }

    static Fill(target, defaults) {
        for k, v in defaults
            if !target.Has(k)
                target[k] := v
    }

    static NewId() {
        this.Seq += 1
        return "b" A_Now this.Seq Random(100, 999)
    }

    static NewBind(category := "Общие") {
        delay := 1300
        if this.Data.Has("settings")
            delay := this.Data["settings"]["lineDelay"]
        return Map("id", this.NewId(), "name", "", "category", category, "hotkey", "", "lines", "", "delay", delay, "enabled", 1)
    }

    static Make(name, cat, hk, lines) {
        b := this.NewBind(cat)
        b["name"] := name, b["hotkey"] := hk, b["lines"] := lines
        return b
    }

    static StarterBinds() {
        list := []
        list.Push(this.Make("Приветствие", "Общие", "F1", "Здравствуйте! Я {rank} {name}, что вас беспокоит?`n/me внимательно посмотрел на пациента"))
        list.Push(this.Make("Лечение", "Лечение", "F2", "/me открыл медицинскую сумку и достал нужный препарат`n/do Препарат в руке.`n/me передал препарат пациенту`n/heal {id} {noenter}"))
        list.Push(this.Make("Мед. карта", "Лечение", "F3", "/me достал бланк медицинской карты и ручку`n/do Бланк в руках.`n/me заполнил данные пациента`n{wait 2500}`n/me поставил печать и передал карту пациенту"))
        list.Push(this.Make("Рация: нужна помощь", "RP", "F4", "/r [{org}] {rank} {name}: нужна помощь в приёмном отделении."))
        list.Push(this.Make("Прощание", "Общие", "F5", "Всего доброго, не болейте!`n/me дружелюбно улыбнулся"))
        return list
    }

    static Num(v, def := 0) {
        try {
            n := Integer(v)
            return n < 0 ? 0 : n
        }
        return def
    }

    static Find(id) {
        for b in this.Data["binds"]
            if b["id"] = id
                return b
        return 0
    }

    static IndexOf(id) {
        for i, b in this.Data["binds"]
            if b["id"] = id
                return i
        return 0
    }

    static Remove(id) {
        if i := this.IndexOf(id)
            this.Data["binds"].RemoveAt(i)
    }

    static Clone(b) {
        c := Map()
        for k, v in b
            c[k] := v
        return c
    }

    static Duplicate(id) {
        src := this.Find(id)
        if !src
            return 0
        c := this.Clone(src)
        c["id"] := this.NewId()
        c["name"] := src["name"] " (копия)"
        c["hotkey"] := ""
        this.Data["binds"].InsertAt(this.IndexOf(id) + 1, c)
        return c
    }

    static HotkeyOwner(hk, exceptId := "") {
        if hk = ""
            return ""
        for b in this.Data["binds"]
            if b["id"] != exceptId && b["hotkey"] != "" && b["hotkey"] = hk
                return b["name"]
        return ""
    }

    static EnsureCategory(name) {
        name := Trim(name)
        if name = ""
            return
        for c in this.Data["categories"]
            if c = name
                return
        this.Data["categories"].Push(name)
    }

    ; иконка категории (ключ из Icon.CatKeys), хранится в settings.catIcons
    static CatIcon(name) {
        ic := this.Data["settings"]["catIcons"]
        if ic.Has(name)
            return ic[name]
        switch name {
            case "Общие": return "chat"
            case "Лечение": return "health"
            case "RP": return "person"
        }
        return "folder"
    }

    static SetCatIcon(name, key) {
        this.Data["settings"]["catIcons"][name] := key
    }

    static CountIn(cat) {
        n := 0
        for b in this.Data["binds"]
            if b["category"] = cat
                n++
        return n
    }

    static RenameCategory(old, new) {
        new := Trim(new)
        if new = "" || new = old
            return
        cats := this.Data["categories"]
        ic := this.Data["settings"]["catIcons"]
        if ic.Has(old) {
            ic[new] := ic[old]
            ic.Delete(old)
        }
        for i, c in cats
            if c = old
                cats[i] := new
        for b in this.Data["binds"]
            if b["category"] = old
                b["category"] := new
        ; убрать дубликаты, если новое имя уже было
        seen := Map(), out := []
        for c in cats
            if !seen.Has(StrLower(c)) {
                seen[StrLower(c)] := 1
                out.Push(c)
            }
        this.Data["categories"] := out
    }

    static DeleteCategory(name) {
        cats := this.Data["categories"]
        for i, c in cats
            if c = name {
                cats.RemoveAt(i)
                break
            }
        ic := this.Data["settings"]["catIcons"]
        if ic.Has(name)
            ic.Delete(name)
        if cats.Length = 0
            cats.Push("Общие")
        fallback := cats[1]
        for b in this.Data["binds"]
            if b["category"] = name
                b["category"] := fallback
        return fallback
    }

    ; Перевод старых переменных Doctor Binder V3 в новые
    static MigrateVars(text) {
        for pair in [["{P}", "{id}"], ["{MY}", "{nick}"], ["{HOSPITAL}", "{org}"], ["{SPECIALTY}", "{rank}"]]
            text := StrReplace(text, pair[1], pair[2])
        return text
    }
}
