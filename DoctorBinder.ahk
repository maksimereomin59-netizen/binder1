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

; ==================== App ====================

class App {
    static Name := "MedBind"
    static Version := "4.0"
}

Join(arr, sep := ", ") {
    out := ""
    for i, v in arr
        out .= (i > 1 ? sep : "") v
    return out
}


; ==================== Json ====================

; Небольшой JSON-парсер: объекты -> Map, массивы -> Array
class Json {
    static Parse(text) {
        pos := 1
        value := this._Value(&text, &pos)
        this._Ws(&text, &pos)
        if pos <= StrLen(text)
            throw Error("JSON: лишние символы на позиции " pos)
        return value
    }

    static Stringify(v, indent := "  ", level := 0) {
        nl := indent = "" ? "" : "`n"
        colon := indent = "" ? ":" : ": "
        if v is Map {
            if v.Count = 0
                return "{}"
            out := "{"
            first := true
            for k, val in v {
                out .= (first ? "" : ",") nl this._Rep(indent, level + 1) this._Quote(String(k)) colon this.Stringify(val, indent, level + 1)
                first := false
            }
            return out nl this._Rep(indent, level) "}"
        }
        if v is Array {
            if v.Length = 0
                return "[]"
            out := "["
            for i, val in v
                out .= (i > 1 ? "," : "") nl this._Rep(indent, level + 1) this.Stringify(val, indent, level + 1)
            return out nl this._Rep(indent, level) "]"
        }
        if v is Number
            return String(v)
        return this._Quote(String(v))
    }

    static _Rep(s, n) {
        out := ""
        loop n
            out .= s
        return out
    }

    static _Quote(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`t", "\t")
        return '"' s '"'
    }

    static _Ws(&s, &p) {
        len := StrLen(s)
        while p <= len {
            c := SubStr(s, p, 1)
            if c != " " && c != "`t" && c != "`r" && c != "`n"
                break
            p++
        }
    }

    static _Value(&s, &p) {
        this._Ws(&s, &p)
        c := SubStr(s, p, 1)
        if c = "{" {
            obj := Map()
            p++
            this._Ws(&s, &p)
            if SubStr(s, p, 1) = "}" {
                p++
                return obj
            }
            loop {
                this._Ws(&s, &p)
                if SubStr(s, p, 1) != '"'
                    throw Error("JSON: ожидался ключ на позиции " p)
                key := this._String(&s, &p)
                this._Ws(&s, &p)
                if SubStr(s, p, 1) != ":"
                    throw Error("JSON: ожидалось ':' на позиции " p)
                p++
                obj[key] := this._Value(&s, &p)
                this._Ws(&s, &p)
                c := SubStr(s, p, 1)
                p++
                if c = "}"
                    return obj
                if c != ","
                    throw Error("JSON: ожидалось ',' или '}' на позиции " (p - 1))
            }
        }
        if c = "[" {
            arr := []
            p++
            this._Ws(&s, &p)
            if SubStr(s, p, 1) = "]" {
                p++
                return arr
            }
            loop {
                arr.Push(this._Value(&s, &p))
                this._Ws(&s, &p)
                c := SubStr(s, p, 1)
                p++
                if c = "]"
                    return arr
                if c != ","
                    throw Error("JSON: ожидалось ',' или ']' на позиции " (p - 1))
            }
        }
        if c = '"'
            return this._String(&s, &p)
        if RegExMatch(s, "-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", &m, p) && m.Pos = p {
            p += m.Len
            return (InStr(m[0], ".") || InStr(m[0], "e")) ? Float(m[0]) : Integer(m[0])
        }
        if SubStr(s, p, 4) == "true" {
            p += 4
            return 1
        }
        if SubStr(s, p, 5) == "false" {
            p += 5
            return 0
        }
        if SubStr(s, p, 4) == "null" {
            p += 4
            return ""
        }
        throw Error("JSON: неожиданный символ на позиции " p)
    }

    static _String(&s, &p) {
        p++
        out := ""
        len := StrLen(s)
        loop {
            if p > len
                throw Error("JSON: незакрытая строка")
            c := SubStr(s, p, 1)
            if c = '"' {
                p++
                return out
            }
            if c = "\" {
                n := SubStr(s, p + 1, 1)
                switch n, true {
                    case '"': out .= '"'
                    case "\": out .= "\"
                    case "/": out .= "/"
                    case "b": out .= Chr(8)
                    case "f": out .= Chr(12)
                    case "n": out .= "`n"
                    case "r": out .= "`r"
                    case "t": out .= "`t"
                    case "u":
                        out .= Chr(Integer("0x" SubStr(s, p + 2, 4)))
                        p += 4
                    default:
                        throw Error("JSON: неверная escape-последовательность")
                }
                p += 2
                continue
            }
            out .= c
            p++
        }
    }
}

; Base64 для кодов обмена (UTF-8)
class B64 {
    static Encode(str) {
        n := StrPut(str, "UTF-8")
        buf := Buffer(n)
        StrPut(str, buf, "UTF-8")
        flags := 0x40000001
        chars := 0
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", n - 1, "UInt", flags, "Ptr", 0, "UInt*", &chars)
        out := Buffer(chars * 2)
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", n - 1, "UInt", flags, "Ptr", out, "UInt*", &chars)
        return StrGet(out, "UTF-16")
    }

    static Decode(b64) {
        b64 := RegExReplace(b64, "\s")
        size := 0
        if !DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
            throw Error("код повреждён")
        buf := Buffer(size)
        DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", buf, "UInt*", &size, "Ptr", 0, "Ptr", 0)
        return StrGet(buf, size, "UTF-8")
    }
}


; ==================== Store ====================

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


; ==================== Sender ====================

; Отправка бинда в чат игры
; Спец-команды в строках:
;   # текст      - комментарий, не отправляется
;   {wait 2000}  - отдельной строкой: своя пауза перед следующей строкой
;   {noenter}    - оставить строку в чате без Enter (бинд на ней заканчивается)
class Sender {
    static Steps := []
    static Index := 0
    static Running := false
    static Name := ""
    static Fn := 0

    static Plan(bind) {
        steps := []
        def := Store.Num(bind["delay"], 1300)
        for raw in StrSplit(StrReplace(bind["lines"], "`r"), "`n") {
            line := Trim(raw)
            if line = "" || SubStr(line, 1, 1) = "#"
                continue
            if RegExMatch(line, "i)^\{wait\s+(\d+)\}$", &m) {
                if steps.Length
                    steps[-1].pause := Integer(m[1])
                continue
            }
            enter := !RegExMatch(line, "i)\{noenter\}")
            text := Trim(RegExReplace(line, "i)\s*\{noenter\}", ""))
            if !enter
                text .= " "
            steps.Push({text: text, enter: enter, pause: def})
            if !enter
                break
        }
        return steps
    }

    static Resolve(text) {
        p := Store.Data["profile"]
        nick := String(p["nick"])
        vars := [
            ["{id}", p["id"]],
            ["{nick}", nick],
            ["{name}", StrReplace(nick, "_", " ")],
            ["{rank}", p["rank"]],
            ["{org}", p["org"]],
            ["{time}", FormatTime(, "HH:mm")],
            ["{date}", FormatTime(, "dd.MM.yyyy")]
        ]
        for v in vars
            text := StrReplace(text, v[1], v[2])
        return text
    }

    static PreviewText(bind) {
        steps := this.Plan(bind)
        if !steps.Length
            return "Здесь появится то, что бинд отправит в чат."
        out := ""
        t := 0
        for i, st in steps {
            out .= Format("{:5.1f}с  ", t / 1000) this.Resolve(st.text) (st.enter ? "" : "  [без Enter]") "`n"
            t += st.pause
        }
        return RTrim(out, "`n")
    }

    static Duration(steps) {
        total := 0
        for i, st in steps
            if i < steps.Length
                total += st.pause
        return total
    }

    static Start(bind) {
        this.Stop()
        steps := this.Plan(bind)
        if !steps.Length {
            Toast.Show("В бинде нет строк для отправки", bind["name"])
            return
        }
        ; ждём, пока игрок отпустит Ctrl/Alt/Shift, иначе вместо «T» уйдёт Ctrl+T
        for k in ["Ctrl", "Alt", "Shift", "LWin"]
            KeyWait(k, "T1")
        this.Steps := steps
        this.Index := 0
        this.Name := bind["name"]
        this.Running := true
        if !this.Fn
            this.Fn := ObjBindMethod(this, "Tick")
        SetTimer(this.Fn, -1)
    }

    static Tick() {
        if !this.Running
            return
        s := Store.Data["settings"]
        this.Index += 1
        if this.Index > this.Steps.Length
            return this.Stop()
        if s["requireGame"] && !WinActive("ahk_exe " s["gameExe"]) {
            this.Stop()
            Toast.Show("Окно игры неактивно — отправка прервана", this.Name)
            return
        }
        step := this.Steps[this.Index]
        try {
            this.Say(this.Resolve(step.text), step.enter)
        } catch Error as err {
            this.Stop()
            Toast.Show("Ошибка отправки: " err.Message, this.Name)
            return
        }
        if !this.Running        ; нажали «Стоп» во время отправки
            return
        if this.Index < this.Steps.Length
            SetTimer(this.Fn, -Max(50, step.pause))
        else
            this.Stop()
    }

    static Say(text, enter) {
        s := Store.Data["settings"]
        SendMode(s["sendMode"] = "Event" ? "Event" : "Input")
        SetKeyDelay(Store.Num(s["keyDelay"], 15), 10)
        if s["forceRu"]
            try PostMessage(0x50, 0, 0x4190419, , "A")   ; раскладка RU, чтобы не было «????»
        ; vk54 = физическая клавиша T — работает при любой раскладке
        Send(s["chatKey"] = "F6" ? "{F6}" : "{vk54}")
        Sleep(Store.Num(s["openDelay"], 120))
        SendText(text)
        if enter {
            Sleep(Store.Num(s["enterDelay"], 60))
            Send("{Enter}")
        }
    }

    static Stop(notify := false) {
        wasRunning := this.Running
        this.Running := false
        if this.Fn
            SetTimer(this.Fn, 0)
        if notify && wasRunning
            Toast.Show("Отправка остановлена", this.Name)
    }
}


; ==================== Keys ====================

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


; ==================== Share ====================

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


; ==================== Theme ====================

; ============================================================
;  MedBind Design System: цвета, иконки, базовые элементы.
;  Все окна собираются только из этих компонентов — стиль меняется в одном месте.
; ============================================================
class Theme {
    static Font := "Segoe UI"
    static Mono := "Consolas"

    ; поверхности
    static Bg := "0B0E13"
    static Side := "0D1218"
    static Card := "11161D"
    static CardHover := "161C25"
    static CardSel := "0D2129"
    static Field := "151B24"
    static FieldHover := "1C2430"
    static ChatBg := "090C11"
    static Gutter := "151A21"
    ; линии
    static Line := "1F2937"
    static LineHover := "2C3A4C"
    static KeyLine := "2A3646"
    ; текст
    static Text := "E8EDF4"
    static Soft := "C2CBD8"
    static Muted := "8792A4"
    static Faint := "5A6577"
    ; акценты
    static Accent := "38C3E8"
    static AccentHover := "62D2F0"
    static AccentPress := "2AA9CC"
    static AccentInk := "05242E"
    static AccentLine := "2B7E99"
    static AccentSoft := "0F2B36"
    static AccentSoftHover := "143A49"
    static AccentSoftPress := "1A4859"
    static Violet := "8C93E6"
    static VioletSoft := "23264A"
    static VioletSoftHover := "2C3060"
    ; статусы
    static Success := "3DD68C"
    static SuccessBg := "0E2A1D"
    static Warning := "E2B65E"
    static WarningBg := "2D2515"
    static Danger := "E5696E"
    static DangerBg := "2C181B"
    static DangerHover := "3A1E22"
    static DangerPress := "4A242A"

    static Inited := false

    ; тёмные системные меню (ПКМ и выпадающие списки), Windows 10 1903+
    static Init() {
        if this.Inited
            return
        this.Inited := true
        try {
            ux := DllCall("LoadLibrary", "Str", "uxtheme.dll", "Ptr")
            setMode := DllCall("GetProcAddress", "Ptr", ux, "Ptr", 135, "Ptr")
            flush := DllCall("GetProcAddress", "Ptr", ux, "Ptr", 136, "Ptr")
            if setMode
                DllCall(setMode, "Int", 2)
            if flush
                DllCall(flush)
        }
    }

    ; тёмный заголовок, скруглённые углы и тонкая рамка окна (Windows 10/11)
    static Dark(g) {
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 34, "Int*", Color.BGR(Theme.Line), "Int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 35, "Int*", Color.BGR(Theme.Bg), "Int", 4)
    }

    static DarkCtrl(ctrl, name := "DarkMode_Explorer") {
        try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", name, "Ptr", 0)
    }

    ; скругление; r — радиус, учитывается масштаб Windows (125%, 150%…)
    static Round(ctrl, w, h, r := 8) {
        if !r
            return
        s := A_ScreenDPI / 96
        d := Round(r * 2 * s)
        try WinSetRegion("0-0 w" Round(w * s) " h" Round(h * s) " r" d "-" d, ctrl)
    }
}

class Color {
    static BGR(hex) {
        v := Integer("0x" hex)
        return ((v & 0xFF) << 16) | (v & 0xFF00) | ((v >> 16) & 0xFF)
    }
    static Mix(a, b, t) {
        a := Integer("0x" a), b := Integer("0x" b)
        r := Round(((a >> 16) & 255) * (1 - t) + ((b >> 16) & 255) * t)
        g := Round(((a >> 8) & 255) * (1 - t) + ((b >> 8) & 255) * t)
        bl := Round((a & 255) * (1 - t) + (b & 255) * t)
        return Format("{:06X}", (r << 16) | (g << 8) | bl)
    }
}

; Иконки из системного шрифта Segoe MDL2 Assets (есть в Windows 10/11)
class Icon {
    static Font := "Segoe MDL2 Assets"
    static Search := Chr(0xE721)
    static Add := Chr(0xE710)
    static Settings := Chr(0xE713)
    static Import := Chr(0xE896)
    static Share := Chr(0xE72D)
    static Edit := Chr(0xE70F)
    static Copy := Chr(0xE8C8)
    static Delete := Chr(0xE74D)
    static Keyboard := Chr(0xE765)
    static Doc := Chr(0xE8A5)
    static Cancel := Chr(0xE711)
    static Down := Chr(0xE70D)
    static Undo := Chr(0xE7A7)
    static Save := Chr(0xE74E)
    static Warning := Chr(0xE7BA)
    static Error := Chr(0xE783)
    static Info := Chr(0xE946)
    static Check := Chr(0xE73E)
    static Clock := Chr(0xE916)
    static Enter := Chr(0xE751)
    static All := Chr(0xE8FD)
    static Folder := Chr(0xE8B7)
    static Move := Chr(0xE8DE)
    static Power := Chr(0xE7E8)
    static More := Chr(0xE712)
    static Monitor := Chr(0xE7F4)
    static Home := Chr(0xE80F)
    static ChevL := Chr(0xE76B)
    static ChevR := Chr(0xE76C)

    static Cat := Map(
        "folder", Chr(0xE8B7), "chat", Chr(0xE8BD), "health", Chr(0xE95E), "heart", Chr(0xEB51),
        "person", Chr(0xE77B), "people", Chr(0xE716), "shield", Chr(0xEA18), "car", Chr(0xE804),
        "phone", Chr(0xE717), "doc", Chr(0xE8A5), "star", Chr(0xE734), "bolt", Chr(0xE945)
    )
    static CatKeys := ["folder", "chat", "health", "heart", "person", "people", "shield", "car", "phone", "doc", "star", "bolt"]

    static ForCat(name) {
        return Icon.Cat.Get(Store.CatIcon(name), Icon.Cat["folder"])
    }
}

; ============================================================
;  Базовые элементы и модальные окна
; ============================================================
class UI {
    static Owners := Map()

    static Pos(opts) {
        r := {x: 0, y: 0, w: 100, h: 30}
        for k in ["x", "y", "w", "h"]
            if RegExMatch(opts, "i)(?:^|\s)" k "(-?\d+)", &m)
                r.%k% := Integer(m[1])
        return r
    }

    ; точная ширина текста (для центрирования иконки и подписи на кнопках, ширины чипов)
    static TextW(text, size := 10, weight := 600, font := "") {
        font := font = "" ? Theme.Font : font
        hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
        hf := DllCall("CreateFont", "Int", -Round(size * A_ScreenDPI / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight
            , "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 5, "UInt", 0, "Str", font, "Ptr")
        old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hf, "Ptr")
        sz := Buffer(8, 0)
        DllCall("GetTextExtentPoint32", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", sz)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
        DllCall("DeleteObject", "Ptr", hf)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
        return Ceil(NumGet(sz, 0, "Int") * 96 / A_ScreenDPI)
    }

    static Text(g, opts, text, bg, size := 10, color := "", weight := 400, font := "") {
        g.SetFont("s" size " w" weight " q5 c" (color = "" ? Theme.Text : color), font = "" ? Theme.Font : font)
        return g.AddText(opts " Background" bg, text)
    }

    static Label(g, opts, text, bg) {
        return UI.Text(g, opts, text, bg, 8, Theme.Muted, 700)
    }

    static IconText(g, opts, glyph, bg, size := 10, color := "") {
        return UI.Text(g, opts " +0x200 Center", glyph, bg, size, color = "" ? Theme.Muted : color, 400, Icon.Font)
    }

    ; фоновая плашка; +0x4000000 — не рисуется поверх текста
    static Box(g, x, y, w, h, color, r := 10, extra := "") {
        c := g.AddText("x" x " y" y " w" w " h" h " +0x4000000 " extra " Background" color)
        Theme.Round(c, w, h, r)
        return c
    }

    ; карточка с тонкой рамкой: .o — рамка, .i — заливка
    static Frame(g, x, y, w, h, fill, r := 10, border := "", innerExtra := "") {
        o := UI.Box(g, x, y, w, h, border = "" ? Theme.Line : border, r)
        i := UI.Box(g, x + 1, y + 1, w - 2, h - 2, fill, r > 1 ? r - 1 : 0, innerExtra)
        return {o: o, i: i}
    }

    static Paint(ctrl, color) {
        try {
            ctrl.Opt("Background" color)
            ctrl.Redraw()
        }
    }

    ; поле ввода в рамке; при фокусе рамка подсвечивается
    static Field(g, x, y, w, h, value := "", opts := "", mono := false) {
        fr := UI.Frame(g, x, y, w, h, Theme.Field, 8)
        g.SetFont("s10 w400 q5 c" Theme.Text, mono ? Theme.Mono : Theme.Font)
        if InStr(opts, "Multi")
            e := g.AddEdit("x" (x + 12) " y" (y + 9) " w" (w - 18) " h" (h - 16) " -E0x200 " opts " Background" Theme.Field, value)
        else
            e := g.AddEdit("x" (x + 12) " y" (y + (h - 22) // 2 + 1) " w" (w - 24) " r1 -E0x200 -Multi " opts " Background" Theme.Field, value)
        Theme.DarkCtrl(e)
        if !InStr(opts, "ReadOnly")
            UI.FocusRing(e, fr.o)
        return e
    }

    static FocusRing(edit, ring) {
        edit.OnEvent("Focus", (*) => UI.Paint(ring, Theme.AccentLine))
        edit.OnEvent("LoseFocus", (*) => UI.Paint(ring, Theme.Line))
    }

    static Cue(edit, text) {
        SendMessage(0x1501, 1, StrPtr(text), edit)
    }

    static Divider(g, x, y, w) {
        return UI.Box(g, x, y, w, 1, Theme.Line, 0)
    }

    static NewGui(title, owner := 0) {
        Theme.Init()
        if !owner
            owner := MainUI.G
        g := Gui((owner ? "+Owner" owner.Hwnd : "") " -MinimizeBox -MaximizeBox", title)
        g.BackColor := Theme.Bg
        g.MarginX := 0, g.MarginY := 0
        UI.Owners[g.Hwnd] := owner
        return g
    }

    static OpenModal(g, size) {
        Theme.Dark(g)
        owner := UI.Owners.Get(g.Hwnd, 0)
        if owner
            try owner.Opt("+Disabled")
        g.Show(size)
    }

    static CloseModal(g) {
        hwnd := g.Hwnd
        owner := UI.Owners.Has(hwnd) ? UI.Owners.Delete(hwnd) : 0
        Hover.Forget(hwnd)
        if owner
            try owner.Opt("-Disabled")
        g.Destroy()
        if owner
            try WinActivate(owner)
    }

    ; шапка диалога: круглый значок + заголовок + пояснение
    static DialogHead(g, w, glyph, title, text := "", tone := "accent") {
        bg := tone = "danger" ? Theme.DangerBg : tone = "warning" ? Theme.WarningBg : tone = "violet" ? Theme.VioletSoft : Theme.AccentSoft
        fg := tone = "danger" ? Theme.Danger : tone = "warning" ? Theme.Warning : tone = "violet" ? Theme.Violet : Theme.Accent
        b := UI.IconText(g, "x28 y26 w40 h40", glyph, bg, 13, fg)
        Theme.Round(b, 40, 40, 20)
        UI.Text(g, "x84 y24 w" (w - 112) " h26", title, Theme.Bg, 13, Theme.Text, 700)
        if text != ""
            UI.Text(g, "x84 y50 w" (w - 112) " h40", text, Theme.Bg, 9, Theme.Muted)
    }
}


; ==================== Controls ====================

; ============================================================
;  Интерактивные компоненты: наведение, кнопки, переключатели,
;  списки, поле клавиши, предпросмотр чата (RichEdit)
; ============================================================

; Наведение и нажатие для любых элементов. obj может иметь Enter/Leave/Press/Release
class Hover {
    static Items := Map()
    static Cur := 0
    static Down := 0
    static Fn := 0

    static Add(ctrl, obj, guiHwnd) {
        if !this.Fn {
            this.Fn := ObjBindMethod(this, "Check")
            OnMessage(0x200, ObjBindMethod(this, "OnMove"))
            OnMessage(0x201, ObjBindMethod(this, "OnDown"))
            OnMessage(0x203, ObjBindMethod(this, "OnDown"))
            OnMessage(0x202, ObjBindMethod(this, "OnUp"))
        }
        this.Items[ctrl.Hwnd] := {obj: obj, gui: guiHwnd}
    }

    static OnMove(wParam, lParam, msg, hwnd) {
        this.SetCur(this.Items.Has(hwnd) ? this.Items[hwnd].obj : 0)
    }

    static OnDown(wParam, lParam, msg, hwnd) {
        if this.Items.Has(hwnd) {
            this.Down := this.Items[hwnd].obj
            if HasMethod(this.Down, "Press")
                try this.Down.Press()
        }
    }

    static OnUp(wParam, lParam, msg, hwnd) {
        if d := this.Down {
            this.Down := 0
            if HasMethod(d, "Release")
                try d.Release()
        }
    }

    static Check() {
        h := 0
        try MouseGetPos(, , , &h, 2)
        this.SetCur(h && this.Items.Has(h) ? this.Items[h].obj : 0)
    }

    static SetCur(obj) {
        if obj = this.Cur
            return
        old := this.Cur
        this.Cur := obj
        if old && HasMethod(old, "Leave")
            try old.Leave()
        if obj {
            if HasMethod(obj, "Enter")
                try obj.Enter()
            SetTimer(this.Fn, 100)
        } else {
            SetTimer(this.Fn, 0)
        }
    }

    static Forget(guiHwnd) {
        dead := []
        for hwnd, it in this.Items
            if it.gui = guiHwnd
                dead.Push(hwnd)
        for hwnd in dead
            this.Items.Delete(hwnd)
        this.Cur := 0, this.Down := 0
        if this.Fn
            SetTimer(this.Fn, 0)
    }
}

; Плавная смена фона набора контролов (3 кадра ≈ 45 мс) + состояние нажатия
class PaintHover {
    __New(ctrls, bg, hv, pr := "") {
        this.Ctrls := ctrls, this.Bg := bg, this.Hv := hv, this.Pr := pr = "" ? hv : pr
        this.Cur := bg, this.Hot := false, this.T := 0, this.From := bg, this.To := bg
        this.Fn := ObjBindMethod(this, "Step")
    }
    Enter() {
        this.Hot := true
        this.Fade(this.Hv)
    }
    Leave() {
        this.Hot := false
        this.Fade(this.Bg)
    }
    Press() {
        SetTimer(this.Fn, 0)
        this.Paint(this.Pr)
    }
    Release() {
        this.Paint(this.Hot ? this.Hv : this.Bg)
    }
    SetColors(bg, hv, pr := "") {
        this.Bg := bg, this.Hv := hv, this.Pr := pr = "" ? hv : pr
        SetTimer(this.Fn, 0)
        this.Paint(this.Hot ? hv : bg)
    }
    Fade(target) {
        this.From := this.Cur, this.To := target, this.T := 0
        SetTimer(this.Fn, 15)
    }
    Step() {
        this.T += 1
        this.Paint(this.T >= 3 ? this.To : Color.Mix(this.From, this.To, this.T / 3))
        if this.T >= 3
            SetTimer(this.Fn, 0)
    }
    Paint(c) {
        this.Cur := c
        for ctl in this.Ctrls
            UI.Paint(ctl, c)
    }
}

; Кнопка: фон + (иконка) + (подпись). Виды: primary, ghost, subtle, danger, chip, violet
class Btn {
    static Add(g, opts, label, cb, kind := "ghost", size := 10, glyph := "", parentBg := "") {
        return Btn(g, opts, label, cb, kind, size, glyph, parentBg)
    }

    __New(g, opts, label, cb, kind, size, glyph, parentBg) {
        this.Cb := cb, this.Size := size, this.Glyph := glyph, this.Enabled := true
        p := UI.Pos(opts)
        this.P := p
        switch kind {
            case "primary": bg := Theme.Accent, fg := Theme.AccentInk, hv := Theme.AccentHover, pr := Theme.AccentPress
            case "danger": bg := Theme.DangerBg, fg := Theme.Danger, hv := Theme.DangerHover, pr := Theme.DangerPress
            case "chip": bg := Theme.AccentSoft, fg := Theme.Accent, hv := Theme.AccentSoftHover, pr := Theme.AccentSoftPress
            case "violet": bg := Theme.VioletSoft, fg := Theme.Violet, hv := Theme.VioletSoftHover, pr := Theme.VioletSoftHover
            case "subtle":
                bg := parentBg = "" ? Theme.Bg : parentBg, fg := Theme.Muted, hv := Theme.Field, pr := Theme.Line
            default: bg := Theme.Field, fg := Theme.Text, hv := Theme.FieldHover, pr := Theme.Line
        }
        this.Fg := fg
        r := p.h >= 36 ? 9 : p.h >= 28 ? 7 : 6
        this.Plate := g.AddText("x" p.x " y" p.y " w" p.w " h" p.h " +0x100 +0x4000000 Background" bg)
        Theme.Round(this.Plate, p.w, p.h, r)
        this.Ic := UI.Text(g, "x" p.x " y" p.y " w18 h" p.h " +0x200 Center", glyph, bg, size, fg, 400, Icon.Font)
        this.Lb := UI.Text(g, "x" p.x " y" p.y " w" p.w " h" p.h " +0x200 Center", label, bg, size, fg, 600)
        this.Parts := [this.Plate, this.Ic, this.Lb]
        this.Plate.OnEvent("Click", ObjBindMethod(this, "Fire"))
        this.Hv := PaintHover(this.Parts, bg, hv, pr)
        Hover.Add(this.Plate, this.Hv, g.Hwnd)
        this.Layout(label, glyph)
    }

    Fire(*) {
        if this.Enabled && this.Cb
            (this.Cb)()
    }

    ; центрирует иконку и подпись как единый блок
    Layout(label, glyph) {
        p := this.P
        this.Label := label, this.Glyph := glyph
        this.Lb.Value := label, this.Ic.Value := glyph
        this.IconFits := glyph != ""
        if glyph = "" {
            this.Ic.Visible := false
            this.Lb.Move(p.x + 4, p.y, p.w - 8, p.h)
            return
        }
        if label = "" {
            this.Lb.Visible := false
            this.Ic.Move(p.x, p.y, p.w, p.h)
            return
        }
        tw := UI.TextW(label, this.Size, 600)
        cw := 16 + 8 + tw
        if cw > p.w - 12 {             ; не влезает — без иконки
            this.IconFits := false
            this.Ic.Visible := false
            this.Lb.Move(p.x + 4, p.y, p.w - 8, p.h)
            return
        }
        sx := p.x + (p.w - cw) // 2
        this.Ic.Move(sx, p.y, 16, p.h)
        this.Lb.Move(sx + 23, p.y, tw + 4, p.h)
        this.Lb.Opt("-Center")
    }

    Set(label, glyph := "", cb := 0) {
        if cb
            this.Cb := cb
        this.Lb.Opt("+Center")
        this.Lb.Visible := true, this.Ic.Visible := true
        this.Layout(label, glyph)
        this.Show(this.Visible_)
        for c in this.Parts
            c.Redraw()
    }

    Visible_ := true
    IconFits := false
    Show(v) {
        this.Visible_ := v
        this.Plate.Visible := v
        this.Ic.Visible := v && this.IconFits
        this.Lb.Visible := v && this.Label != ""
    }
}

; Переключатель-пилюля с плавным ходом кружка
class SwitchCtl {
    __New(g, x, y, w, label, state, bg, onColor := "") {
        this.State := !!state, this.X := x, this.Y := y, this.OnChange := 0
        this.OnColor := onColor = "" ? Theme.Accent : onColor
        this.Track := g.AddText("x" x " y" (y + 3) " w40 h22 +0x100 +0x4000000 Background" Theme.Line)
        Theme.Round(this.Track, 40, 22, 11)
        this.Knob := g.AddText("x" (x + 3) " y" (y + 6) " w16 h16 BackgroundFFFFFF")
        Theme.Round(this.Knob, 16, 16, 8)
        this.Lbl := UI.Text(g, "x" (x + 52) " y" y " w" (w - 52) " h28 +0x200 +0x100", label, bg, 10, Theme.Soft, 500)
        for c in [this.Track, this.Lbl]
            c.OnEvent("Click", ObjBindMethod(this, "Flip"))
        this.KX := this.State ? 21 : 3
        this.AnimFn := ObjBindMethod(this, "Anim")
        this.Render(false)
    }
    Flip(*) {
        this.Set(!this.State)
        if this.OnChange
            (this.OnChange)(this.State)
    }
    Set(v) {
        this.State := !!v
        this.Render(true)
    }
    Render(animate) {
        UI.Paint(this.Track, this.State ? this.OnColor : Theme.Line)
        UI.Paint(this.Knob, this.State ? "FFFFFF" : "C9CED8")
        if animate {
            SetTimer(this.AnimFn, 12)
        } else {
            this.KX := this.State ? 21 : 3
            this.Knob.Move(this.X + this.KX, this.Y + 6)
        }
    }
    Anim() {
        target := this.State ? 21 : 3
        this.KX += (target > this.KX ? 6 : -6)
        if Abs(target - this.KX) < 6
            this.KX := target
        try {
            this.Knob.Move(this.X + this.KX, this.Y + 6)
            this.Knob.Redraw()
        }
        if this.KX = target
            SetTimer(this.AnimFn, 0)
    }
}

; Выпадающий список в стиле полей ввода (меню тёмное системное)
class Picker {
    __New(g, x, y, w, h, value, itemsFn, allowNew := false, iconFn := 0) {
        this.G := g, this.Value := value, this.ItemsFn := itemsFn, this.AllowNew := allowNew
        this.IconFn := iconFn, this.OnChange := 0
        this.Fr := UI.Frame(g, x, y, w, h, Theme.Field, 8)
        off := iconFn ? 36 : 12
        this.I := UI.IconText(g, "x" (x + 12) " y" (y + 1) " w18 h" (h - 2), "", Theme.Field, 10, Theme.Accent)
        this.I.Visible := !!iconFn
        this.T := UI.Text(g, "x" (x + off) " y" (y + 1) " w" (w - off - 34) " h" (h - 2) " +0x200 +0x100", value, Theme.Field, 10, Theme.Text, 500)
        this.A := UI.IconText(g, "x" (x + w - 32) " y" (y + 1) " w24 h" (h - 2) " +0x100", Icon.Down, Theme.Field, 8, Theme.Muted)
        for c in [this.T, this.A]
            c.OnEvent("Click", ObjBindMethod(this, "Open"))
        hv := {Enter: (*) => UI.Paint(this.Fr.o, Theme.LineHover), Leave: (*) => UI.Paint(this.Fr.o, Theme.Line)}
        Hover.Add(this.T, hv, g.Hwnd), Hover.Add(this.A, hv, g.Hwnd)
        this.Set(value, false)
    }
    Open(*) {
        m := Menu()
        for item in this.ItemsFn() {
            m.Add(item, this.Chooser(item))
            if item = this.Value
                m.Check(item)
        }
        if this.AllowNew {
            m.Add()
            m.Add("＋  Новая категория…", ObjBindMethod(this, "AskNew"))
        }
        m.Show()
    }
    Chooser(item) {
        return (*) => this.Set(item)
    }
    AskNew(*) {
        r := Dialogs.Category("Новая категория", "", "folder", this.G)
        if r {
            Store.EnsureCategory(r.name)
            Store.SetCatIcon(r.name, r.icon)
            this.Set(r.name)
        }
    }
    Set(v, notify := true) {
        this.Value := v
        this.T.Value := v
        if this.IconFn
            this.I.Value := (this.IconFn)(v)
        if notify && this.OnChange
            (this.OnChange)(v)
    }
}

; Сегментированный переключатель [ A | B ]
class Segmented {
    __New(g, x, y, w, h, options, value) {
        this.Value := value, this.Btns := Map(), this.OnChange := 0
        UI.Frame(g, x, y, w, h, Theme.Field, 8)
        bw := (w - 8) // options.Length
        for i, opt in options {
            c := UI.Text(g, "x" (x + 4 + (i - 1) * bw) " y" (y + 4) " w" bw " h" (h - 8) " +0x200 +0x100 Center", opt, Theme.Field, 10, Theme.Muted, 600)
            Theme.Round(c, bw, h - 8, 6)
            c.OnEvent("Click", this.Chooser(opt))
            this.Btns[opt] := c
        }
        if !this.Btns.Has(value)
            this.Value := options[1]
        this.Render()
    }
    Chooser(opt) {
        return (*) => this.Set(opt)
    }
    Set(v) {
        this.Value := v
        this.Render()
        if this.OnChange
            (this.OnChange)(v)
    }
    Render() {
        for opt, c in this.Btns {
            on := opt = this.Value
            c.SetFont("c" (on ? Theme.Accent : Theme.Muted))
            UI.Paint(c, on ? Theme.AccentSoft : Theme.Field)
        }
    }
}

; Поле назначения клавиши: клик → нажать клавишу (можно с Ctrl/Alt/Shift)
; Esc — отмена, Backspace — очистить. OnChange(value) вызывается после любого изменения
class KeyField {
    __New(g, x, y, w, h, value) {
        this.Value := value, this.OnChange := 0, this.Busy := false
        this.Fr := UI.Frame(g, x, y, w, h, Theme.Field, 8)
        this.I := UI.IconText(g, "x" (x + 10) " y" (y + 1) " w20 h" (h - 2), Icon.Keyboard, Theme.Field, 11, Theme.Muted)
        this.T := UI.Text(g, "x" (x + 38) " y" (y + 1) " w" (w - 38 - 32) " h" (h - 2) " +0x200 +0x100", "", Theme.Field, 10, Theme.Text, 600)
        this.X := UI.IconText(g, "x" (x + w - 30) " y" (y + 1) " w24 h" (h - 2) " +0x100", Icon.Cancel, Theme.Field, 7, Theme.Faint)
        this.T.OnEvent("Click", ObjBindMethod(this, "Capture"))
        this.X.OnEvent("Click", ObjBindMethod(this, "Clear"))
        hv := {Enter: (*) => (this.Busy ? 0 : UI.Paint(this.Fr.o, Theme.LineHover)), Leave: (*) => (this.Busy ? 0 : UI.Paint(this.Fr.o, Theme.Line))}
        Hover.Add(this.T, hv, g.Hwnd)
        this.Render()
    }
    Clear(*) {
        this.Set("")
    }
    Set(v) {
        this.Value := v
        this.Render()
        if this.OnChange
            (this.OnChange)(v)
    }
    Render(waiting := false) {
        UI.Paint(this.Fr.o, waiting ? Theme.Accent : Theme.Line)
        this.I.SetFont("c" (waiting ? Theme.Accent : this.Value = "" ? Theme.Faint : Theme.Muted))
        this.I.Redraw()
        this.X.Visible := !waiting && this.Value != ""
        if waiting {
            this.T.SetFont("c" Theme.Accent)
            this.T.Value := "Нажмите клавишу…  Esc — отмена"
        } else if this.Value = "" {
            this.T.SetFont("c" Theme.Faint)
            this.T.Value := "Нажмите, чтобы назначить"
        } else {
            this.T.SetFont("c" Theme.Text)
            this.T.Value := Keys.Pretty(this.Value)
        }
    }
    Capture(*) {
        if this.Busy
            return
        this.Busy := true
        this.Render(true)
        Keys.Clear()                       ; чтобы бинды не срабатывали во время назначения
        ih := InputHook("L0 T8")
        ih.KeyOpt("{All}", "ES")
        ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-ES")
        ih.Start()
        ih.Wait()
        Keys.Apply()
        this.Busy := false
        if ih.EndReason != "EndKey" || ih.EndKey = "Escape"
            return this.Render()
        if ih.EndKey = "Backspace"
            return this.Set("")
        vk := GetKeyVK(ih.EndKey)
        key := (vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A) ? Chr(vk) : ih.EndKey
        mods := ih.EndMods
        prefix := (InStr(mods, "^") ? "^" : "") (InStr(mods, "!") ? "!" : "") (InStr(mods, "+") ? "+" : "")
        this.Set(prefix key)
    }
}

; Только для чтения: цветной текст (RTF) через стандартный RichEdit из Windows
class RichView {
    static Loaded := false
    __New(g, x, y, w, h, bg) {
        if !RichView.Loaded {
            DllCall("LoadLibrary", "Str", "Msftedit.dll", "Ptr")
            RichView.Loaded := true
        }
        this.C := g.AddCustom("ClassRICHEDIT50W x" x " y" y " w" w " h" h " +0x200844 -E0x200")
        SendMessage(0x443, 0, Color.BGR(bg), this.C)        ; EM_SETBKGNDCOLOR
        Theme.DarkCtrl(this.C)
    }
    Set(rtf) {
        buf := Buffer(StrPut(rtf, "CP0"))
        StrPut(rtf, buf, "CP0")
        st := Buffer(8, 0)                                     ; SETTEXTEX {flags=0, codepage=CP_ACP}
        SendMessage(0x461, st.Ptr, buf.Ptr, this.C)          ; EM_SETTEXTEX
        SendMessage(0xB1, 0, 0, this.C)
        SendMessage(0xB7, 0, 0, this.C)
    }
    Visible {
        set => this.C.Visible := value
    }
}

; Построитель RTF. Цвета: 1 Text, 2 Soft, 3 Muted, 4 Faint, 5 Accent, 6 Violet, 7 Success, 8 Warning, 9 Danger
class Rtf {
    static Head(fs := 18) {
        out := "{\rtf1\ansi\deff0{\fonttbl{\f0 Consolas;}{\f1 Segoe UI;}}{\colortbl `;"
        for c in [Theme.Text, Theme.Soft, Theme.Muted, Theme.Faint, Theme.Accent, Theme.Violet, Theme.Success, Theme.Warning, Theme.Danger] {
            v := Integer("0x" c)
            out .= "\red" ((v >> 16) & 255) "\green" ((v >> 8) & 255) "\blue" (v & 255) ";"
        }
        return out "}\f0\fs" fs " "
    }
    static Esc(s) {
        out := ""
        p := StrPtr(s)
        Loop StrLen(s) {
            c := NumGet(p, (A_Index - 1) * 2, "UShort")
            if c = 92 || c = 123 || c = 125
                out .= "\" Chr(c)
            else if c = 10
                out .= "\line "
            else if c = 13
                continue
            else if c > 127
                out .= "\u" (c > 32767 ? c - 65536 : c) "?"
            else
                out .= Chr(c)
        }
        return out
    }
    static C(i, text) {
        return "\cf" i " " Rtf.Esc(text)
    }
    static P(body, sa := 90) {
        return "\pard\sa" sa " " body "\par "
    }
}


; ==================== Dialogs ====================

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
            t := UI.IconText(g, "x" (28 + col * 62) " y" (198 + row * 50) " w54 h42 +0x100", Icon.Cat[key], Theme.Field, 13, Theme.Muted)
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


; ==================== Preview ====================

; ============================================================
;  Предпросмотр в стиле игрового чата (RTF для RichView)
; ============================================================
class Preview {
    static RpCmd := "i)^/(me|do|todo|try|ame|b)$"

    ; что именно уйдёт в чат, строка за строкой
    static Chat(bind) {
        steps := Sender.Plan(bind)
        out := Rtf.Head(18)
        if !steps.Length
            return out "\f1" Rtf.P(Rtf.C(4, "Добавьте строки — здесь появится то, что бинд отправит в чат.")) "}"
        nick := Trim(StrReplace(String(Store.Data["profile"]["nick"]), "_", " "))
        nick := nick = "" ? "Вы" : nick
        def := Store.Num(bind["delay"], 1300)
        for i, st in steps {
            text := Sender.Resolve(st.text)
            body := Rtf.C(4, Format("{:02}", i) "  ")
            if RegExMatch(text, "^(/\S+)(.*)$", &m) {
                col := !RegExMatch(m[1], Preview.RpCmd) ? 5 : (m[1] = "/me" ? 5 : m[1] = "/do" ? 7 : 6)
                body .= "\b" Rtf.C(col, m[1]) "\b0" Rtf.C(1, m[2])
            } else {
                body .= Rtf.C(3, nick ": ") Rtf.C(1, text)
            }
            if !st.enter
                body .= Rtf.C(8, "   ⏎ без Enter")
            out .= Rtf.P(body)
            if i < steps.Length && st.pause != def
                out .= Rtf.P(Rtf.C(4, "    ⏱ пауза " Format("{:.1f}", st.pause / 1000) " с"))
        }
        return out "}"
    }

    static Stat(bind) {
        steps := Sender.Plan(bind)
        return Preview.Msgs(steps.Length) "  ·  ≈ " Format("{:.1f}", Sender.Duration(steps) / 1000) " с"
    }

    static Msgs(n) {
        m := Mod(n, 10), h := Mod(n, 100)
        w := (m = 1 && h != 11) ? "сообщение" : (m >= 2 && m <= 4 && (h < 12 || h > 14)) ? "сообщения" : "сообщений"
        return n " " w
    }

    ; панель, когда ничего не выбрано: статистика + шпаргалка клавиш
    static Overview() {
        total := 0, active := 0, nokey := 0
        for b in Store.Data["binds"] {
            total++
            active += b["enabled"] ? 1 : 0
            nokey += b["hotkey"] = "" ? 1 : 0
        }
        s := Store.Data["settings"]
        out := Rtf.Head(17) "\f1"
        out .= Rtf.P("\b" Rtf.C(1, total "") "\b0" Rtf.C(3, " биндов    ") "\b" Rtf.C(7, active "") "\b0" Rtf.C(3, " активны    ") "\b" Rtf.C(nokey ? 8 : 1, nokey "") "\b0" Rtf.C(3, " без клавиши"), 200)
        out .= Rtf.P("\fs15\b" Rtf.C(4, "В ИГРЕ") "\b0\fs17", 60)
        for row in [[s["hkMenu"], "показать / скрыть MedBind"], [s["hkToggle"], "включить / выключить биндер"], [s["hkStop"], "остановить отправку"], [s["hkId"], "ввести ID игрока для {id}"]]
            if row[1] != ""
                out .= Rtf.P("\f0\b" Rtf.C(5, Keys.Pretty(row[1])) "\b0\f1" Rtf.C(2, "   " row[2]), 50)
        out .= Rtf.P("", 60) Rtf.P("\fs15\b" Rtf.C(4, "В ОКНЕ") "\b0\fs17", 60)
        for row in [["Ctrl + N", "новый бинд"], ["Ctrl + F", "поиск"], ["Enter", "редактировать"], ["Ctrl + D", "дублировать"], ["Delete", "удалить"], ["Ctrl / Shift + клик", "выбрать несколько"], ["ПКМ", "все действия"]]
            out .= Rtf.P("\f0\b" Rtf.C(6, row[1]) "\b0\f1" Rtf.C(2, "   " row[2]), 50)
        return out "}"
    }

    ; несколько выбранных биндов
    static List(ids) {
        out := Rtf.Head(17) "\f1"
        for id in ids {
            if !(b := Store.Find(id))
                continue
            out .= Rtf.P("\f0\b" Rtf.C(b["hotkey"] = "" ? 4 : 5, Format("{:-12}", Keys.Pretty(b["hotkey"]))) "\b0\f1" Rtf.C(b["enabled"] ? 1 : 3, "  " b["name"]), 60)
        }
        out .= Rtf.P("", 40) Rtf.P(Rtf.C(4, "Можно переместить, дублировать, поделиться или удалить сразу все."))
        return out "}"
    }

    ; предпросмотр импорта
    static Import(parsed, keep) {
        out := Rtf.Head(17) "\f1"
        out .= Rtf.P(Rtf.C(3, "Найдено биндов: ") "\b" Rtf.C(1, parsed.Length "") "\b0", 160)
        for b in parsed {
            hk := b["hotkey"]
            busy := hk != "" && (Store.HotkeyOwner(hk) != "" || Keys.IsSystem(hk))
            key := hk = "" ? "без клавиши" : Keys.Pretty(hk)
            note := !keep && hk != "" ? "  · клавиша не переносится" : busy ? "  · занята, будет снята" : ""
            steps := Sender.Plan(b)
            out .= Rtf.P("\b" Rtf.C(1, b["name"]) "\b0" Rtf.C(3, "   " b["category"] " · " Preview.Msgs(steps.Length)), 20)
            out .= Rtf.P("\f0" Rtf.C(busy || note != "" ? 8 : 5, key) "\f1" Rtf.C(8, note), 30)
            for i, st in steps {
                if i > 2 {
                    out .= Rtf.P("\f0" Rtf.C(4, "   …") "\f1", 10)
                    break
                }
                out .= Rtf.P("\f0" Rtf.C(4, "   ") Rtf.C(2, st.text) "\f1", 10)
            }
            out .= Rtf.P("", 60)
        }
        return out "}"
    }

    static Message(text, color := 4) {
        return Rtf.Head(17) "\f1" Rtf.P(Rtf.C(color, text)) "}"
    }
}


; ==================== Toast ====================

; Уведомления в правом нижнем углу (видны в оконном режиме игры).
; Клики проходят сквозь, фокус не отнимается.
class Toast {
    static G := 0
    static HideFn := 0

    ; kind: info | success | error | "" (определить по тексту)
    static Show(text, title := "", ms := 2400, kind := "") {
        if kind = ""
            kind := this.Guess(text " " title)
        if !this.HideFn
            this.HideFn := ObjBindMethod(this, "Hide")
        if this.G
            try this.G.Destroy()
        W := 340
        lines := 1 + StrLen(text) // 40
        StrReplace(text, "`n", , , &nl)
        lines += nl
        H := 52 + lines * 18
        col := kind = "error" ? Theme.Danger : kind = "success" ? Theme.Success : Theme.Accent
        glyph := kind = "error" ? Icon.Error : kind = "success" ? Icon.Check : Icon.Info
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
        g.BackColor := Theme.Line
        g.MarginX := 0, g.MarginY := 0
        UI.Box(g, 1, 1, W - 2, H - 2, Theme.Card, 0)
        UI.Box(g, 1, 14, 3, H - 28, col, 0)
        UI.IconText(g, "x18 y14 w20 h20", glyph, Theme.Card, 11, col)
        UI.Text(g, "x46 y14 w" (W - 64) " h18", title = "" ? App.Name : title, Theme.Card, 10, Theme.Text, 700)
        UI.Text(g, "x46 y34 w" (W - 64) " h" (H - 44), text, Theme.Card, 9, Theme.Soft)
        this.G := g
        g.Show("NA Hide w" W " h" H)
        WinGetPos(, , &pw, &ph, g)
        MonitorGetWorkArea(MonitorGetPrimary(), , , &right, &bottom)
        WinMove(right - pw - 20, bottom - ph - 20, , , g)
        s := A_ScreenDPI / 96
        try WinSetRegion("0-0 w" pw " h" ph " r" Round(20 * s) "-" Round(20 * s), g)
        g.Show("NA")
        WinSetTransparent(246, g)
        SetTimer(this.HideFn, -ms)
    }

    static Guess(s) {
        if RegExMatch(s, "i)ошибк|не удалось|не распознан|занят|прерван|выключен|отключен|нет строк|сначала")
            return "error"
        if RegExMatch(s, "i)сохран|добавлен|скопирован|включён|снова работают|завершён|удалён|готов|перемещ")
            return "success"
        return "info"
    }

    static Hide() {
        if this.G
            try this.G.Hide()
    }
}


; ==================== MainUI ====================

; ============================================================
;  Главное окно: сайдбар · шапка · список карточек · правая панель
;  Композиция рассчитана на 1366×768 … 1920×1080 и выше
; ============================================================
class MainUI {
    static G := 0
    static W := 1200
    static H := 700
    static SW := 232          ; ширина сайдбара
    static PW := 316          ; ширина правой панели
    static PX := 0
    static CX := 0
    static CW := 0
    static LT := 120          ; верх списка карточек
    static STEP := 70
    static CH := 62
    static NavTop := 98
    static NavStep := 32
    static CardN := 7
    static NavN := 8
    static Cards := []
    static Navs := []
    static Hwnds := Map()     ; hwnd -> {t: "card"|"nav", i}
    static Rows := []
    static NavItems := []
    static Offset := 0
    static NavOffset := 0
    static Sel := Map()
    static Anchor := ""
    static HoverCard := 0
    static HoverNav := 0
    static CurCat := ""
    static D := {}
    static E := {}
    static PgSlots := []
    static Touched := Map()   ; id -> A_Now последнего изменения (в памяти)

    static Show() {
        if !this.G
            this.Build()
        this.G.Show()
        WinActivate("ahk_id " this.G.Hwnd)
    }

    static Toggle() {
        if this.G && WinActive("ahk_id " this.G.Hwnd)
            this.G.Hide()
        else
            this.Show()
    }

    static Layout() {
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        s := A_ScreenDPI / 96
        ww := (r - l) / s, wh := (b - t) / s
        this.W := Round(Min(1280, ww - 16, Max(1024, ww - 120)))
        this.H := Round(Min(820, wh - 16, Max(560, wh - 60)))
        this.PW := this.W >= 1240 ? 316 : 292
        this.CX := this.SW + 24
        this.PX := this.W - this.PW - 16
        this.CW := this.PX - 16 - this.CX
        this.NavN := Max(4, Min(9, (this.H - 320) // this.NavStep))
        this.CardN := Max(3, (this.H - 56 - this.LT) // this.STEP)
    }

    static Build() {
        Theme.Init()
        this.Layout()
        S := Theme.Side, B := Theme.Bg, C := Theme.Card, W := this.W, H := this.H
        g := Gui("-MaximizeBox", App.Name " " App.Version)
        g.BackColor := B
        g.MarginX := 0, g.MarginY := 0
        this.G := g

        ; ================= сайдбар =================
        UI.Box(g, 0, 0, this.SW, H, S, 0)
        UI.Box(g, this.SW, 0, 1, H, Theme.Line, 0)
        lg := UI.IconText(g, "x18 y18 w36 h36", Icon.Cat["health"], Theme.AccentSoft, 14, Theme.Accent)
        Theme.Round(lg, 36, 36, 10)
        UI.Text(g, "x64 y16 w150 h20", "MedBind", S, 13, Theme.Text, 700)
        UI.Text(g, "x64 y37 w150 h14", "Doctor Binder", S, 8, Theme.Muted)

        ; индикатор активности (клик — вкл / выкл)
        stb := UI.Box(g, 10, 62, this.SW - 20, 24, S, 7, "+0x100")
        this.StDot := UI.Text(g, "x18 y62 w12 h24 +0x200", "●", S, 8, Theme.Success)
        this.StText := UI.Text(g, "x32 y62 w110 h24 +0x200", "", S, 9, Theme.Success, 600)
        this.StVer := UI.Text(g, "x" (this.SW - 76) " y62 w58 h24 +0x200 Right", "v" App.Version, S, 8, Theme.Faint, 600)
        for c in [stb, this.StDot, this.StText, this.StVer]
            c.OnEvent("Click", (*) => Keys.ToggleEnabled())
        Hover.Add(stb, PaintHover([stb], S, Theme.Card), g.Hwnd)

        ; категории
        loop this.NavN {
            y := this.NavTop + (A_Index - 1) * this.NavStep
            base := UI.Box(g, 10, y, this.SW - 20, 30, S, 8, "+0x100")
            bar := UI.Box(g, 10, y + 7, 3, 16, Theme.Accent, 2)
            ic := UI.IconText(g, "x22 y" y " w20 h30", "", S, 10, Theme.Muted)
            name := UI.Text(g, "x48 y" y " w" (this.SW - 92) " h30 +0x200", "", S, 10, Theme.Soft, 500)
            cnt := UI.Text(g, "x" (this.SW - 42) " y" y " w24 h30 +0x200 Right", "", S, 8, Theme.Faint, 600)
            this.Navs.Push({plate: base, bar: bar, ic: ic, name: name, cnt: cnt, item: 0})
            base.OnEvent("Click", this.NavClicker(A_Index))
            this.Hwnds[base.Hwnd] := {t: "nav", i: A_Index}
            Hover.Add(base, SlotHover("nav", A_Index), g.Hwnd)
        }
        ya := this.NavTop + this.NavN * this.NavStep + 8
        ab := UI.Box(g, 10, ya, this.SW - 20, 30, S, 8, "+0x100")
        ai := UI.IconText(g, "x22 y" ya " w20 h30", Icon.Add, S, 9, Theme.Muted)
        at := UI.Text(g, "x48 y" ya " w" (this.SW - 70) " h30 +0x200", "Добавить категорию", S, 9, Theme.Muted, 500)
        for c in [ab, ai, at]
            c.OnEvent("Click", (*) => MainUI.NewCategory())
        Hover.Add(ab, PaintHover([ab, ai, at], S, Theme.Card), g.Hwnd)

        ; профиль и настройки внизу
        UI.Divider(g, 16, H - 150, this.SW - 32)
        pr := UI.Box(g, 10, H - 140, this.SW - 20, 30, S, 8, "+0x100")
        pi := UI.IconText(g, "x22 y" (H - 140) " w20 h30", Icon.Cat["person"], S, 10, Theme.Muted)
        pt := UI.Text(g, "x48 y" (H - 140) " w" (this.SW - 70) " h30 +0x200", "Профиль", S, 10, Theme.Soft, 500)
        for c in [pr, pi, pt]
            c.OnEvent("Click", (*) => SettingsUI.Open())
        Hover.Add(pr, PaintHover([pr, pi, pt], S, Theme.Card), g.Hwnd)

        pf := UI.Box(g, 10, H - 102, this.SW - 20, 54, Theme.Card, 10, "+0x100")
        this.Avatar := UI.Text(g, "x18 y" (H - 93) " w36 h36 +0x200 Center", "?", Theme.VioletSoft, 10, Theme.Violet, 700)
        Theme.Round(this.Avatar, 36, 36, 18)
        this.ProfName := UI.Text(g, "x62 y" (H - 96) " w" (this.SW - 100) " h18", "", Theme.Card, 10, Theme.Text, 600)
        this.ProfInfo := UI.Text(g, "x62 y" (H - 79) " w" (this.SW - 100) " h14", "", Theme.Card, 8, Theme.Muted)
        this.ProfId := UI.Text(g, "x62 y" (H - 65) " w" (this.SW - 100) " h14", "", Theme.Card, 8, Theme.Faint)
        pch := UI.IconText(g, "x" (this.SW - 34) " y" (H - 89) " w20 h28 +0x200", Icon.ChevR, Theme.Card, 8, Theme.Faint)
        for c in [pf, this.Avatar, this.ProfName, this.ProfInfo, this.ProfId, pch]
            c.OnEvent("Click", (*) => SettingsUI.Open())
        Hover.Add(pf, PaintHover([pf, this.Avatar, this.ProfName, this.ProfInfo, this.ProfId, pch], Theme.Card, Theme.CardHover), g.Hwnd)

        sr := UI.Box(g, 10, H - 42, this.SW - 20, 30, S, 8, "+0x100")
        si := UI.IconText(g, "x22 y" (H - 42) " w20 h30", Icon.Settings, S, 10, Theme.Muted)
        stt := UI.Text(g, "x48 y" (H - 42) " w" (this.SW - 70) " h30 +0x200", "Настройки", S, 10, Theme.Soft, 500)
        for c in [sr, si, stt]
            c.OnEvent("Click", (*) => SettingsUI.Open())
        Hover.Add(sr, PaintHover([sr, si, stt], S, Theme.Card), g.Hwnd)

        ; ================= шапка =================
        CX := this.CX, CW := this.CW
        this.TitleI := UI.IconText(g, "x" CX " y16 w40 h40", "", Theme.AccentSoft, 13, Theme.Accent)
        Theme.Round(this.TitleI, 40, 40, 12)
        UI.Text(g, "x" (CX + 54) " y13 w200 h14", "Категория", B, 8, Theme.Muted)
        this.TitleT := UI.Text(g, "x" (CX + 54) " y27 w300 h24", "", B, 15, Theme.Text, 700)
        this.CountT := UI.Text(g, "x" (CX + 54) " y31 w" (CW - 60) " h20 +0x200", "", B, 9, Theme.Muted)

        ; статус игры справа
        gcw := 176
        gcx := W - 16 - gcw
        gcf := UI.Frame(g, gcx, 14, gcw, 44, Theme.Card, 10, , "+0x100")
        UI.IconText(g, "x" (gcx + 12) " y15 w20 h42", Icon.Monitor, Theme.Card, 11, Theme.Muted)
        this.GameName := UI.Text(g, "x" (gcx + 40) " y13 w" (gcw - 70) " h22 +0x200", "", Theme.Card, 9, Theme.Text, 600)
        this.GameSt := UI.Text(g, "x" (gcx + 40) " y33 w" (gcw - 70) " h16 +0x200", "", Theme.Card, 8, Theme.Success, 600)
        UI.IconText(g, "x" (gcx + gcw - 26) " y15 w16 h42", Icon.Down, Theme.Card, 8, Theme.Muted)
        for c in [gcf.i, this.GameName, this.GameSt]
            c.OnEvent("Click", (*) => SettingsUI.Open())
        Hover.Add(gcf.i, PaintHover([gcf.i, this.GameName, this.GameSt], Theme.Card, Theme.CardHover), g.Hwnd)
        this.EcgX := gcx - 256
        UI.Text(g, "x" this.EcgX " y16 w240 h40 Right", "─────────/\──────/\────────/\─────────", B, 9, Theme.AccentLine, 400, Theme.Mono)

        ; ================= панель действий =================
        ty := 68
        createX := W - 16 - 150
        Btn.Add(g, "x" createX " y" ty " w150 h38", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "primary", 10, Icon.Add)
        this.EnableSw := SwitchCtl(g, createX - 58, ty + 6, 92, "", Keys.Enabled, B, Theme.Success)
        this.EnableSw.Lbl.Visible := false
        this.EnableSw.OnChange := (*) => Keys.ToggleEnabled()
        impX := createX - 58 - 16 - 110
        Btn.Add(g, "x" impX " y" ty " w110 h38", "Импорт", (*) => Share.ImportDialog(), "ghost", 10, Icon.Import)
        swd := impX - 16 - CX
        sf := UI.Frame(g, CX, ty, swd, 38, Theme.Field, 10)
        UI.IconText(g, "x" (CX + 12) " y" (ty - 1) " w20 h40", Icon.Search, Theme.Field, 11, Theme.Muted)
        g.SetFont("s10 w400 q5 c" Theme.Text, Theme.Font)
        this.SearchE := g.AddEdit("x" (CX + 40) " y" (ty + 8) " w" (swd - 140) " r1 -E0x200 -Multi Background" Theme.Field)
        Theme.DarkCtrl(this.SearchE)
        UI.Cue(this.SearchE, "Поиск по названию, содержимому или горячей клавише...")
        UI.FocusRing(this.SearchE, sf.o)
        this.SearchX := UI.IconText(g, "x" (CX + swd - 94) " y" (ty - 1) " w24 h40 +0x100", Icon.Cancel, Theme.Field, 8, Theme.Muted)
        this.SearchX.OnEvent("Click", (*) => MainUI.ClearSearch())
        this.SearchX.Visible := false
        hint := UI.Text(g, "x" (CX + swd - 66) " y" (ty + 9) " w54 h20 +0x200 Center", "Ctrl + K", Theme.FieldHover, 8, Theme.Muted, 600)
        Theme.Round(hint, 54, 20, 6)
        this.SearchE.OnEvent("Change", (*) => (MainUI.Offset := 0, MainUI.Refresh()))

        ; ================= карточки =================
        loop this.CardN {
            y := this.LT + (A_Index - 1) * this.STEP
            fr := UI.Frame(g, CX, y, CW, this.CH, C, 12, , "+0x100")
            plate := UI.IconText(g, "x" (CX + 12) " y" (y + 12) " w38 h38", "", Theme.Field, 12, Theme.Soft)
            Theme.Round(plate, 38, 38, 10)
            title := UI.Text(g, "x" (CX + 62) " y" (y + 8) " w" (CW - 322) " h18", "", C, 10, Theme.Text, 600)
            keyf := UI.Frame(g, CX + 62, y + 8, 40, 18, Theme.Field, 6, Theme.KeyLine)
            key := UI.Text(g, "x" (CX + 62) " y" (y + 8) " w40 h18 +0x200 Center", "", Theme.Field, 8, Theme.Text, 700, Theme.Mono)
            catb := UI.Box(g, CX + 62, y + 8, 60, 18, Theme.AccentSoft, 6)
            cat := UI.Text(g, "x" (CX + 62) " y" (y + 8) " w60 h18 +0x200 Center", "", Theme.AccentSoft, 8, Theme.Accent, 600)
            sub1 := UI.Text(g, "x" (CX + 62) " y" (y + 28) " w" (CW - 302) " h15", "", C, 9, Theme.Soft)
            sub2 := UI.Text(g, "x" (CX + 62) " y" (y + 43) " w" (CW - 302) " h15", "", C, 9, Theme.Muted)
            cnt := UI.Text(g, "x" (CX + CW - 212) " y" (y + 22) " w84 h18 +0x200 Right", "", C, 9, Theme.Muted)
            swx := CX + CW - 118
            sw := SwitchCtl(g, swx, y + 17, 80, "Вкл", true, C, Theme.Success)
            sw.OnChange := this.Switcher(A_Index)
            keb := UI.IconText(g, "x" (CX + CW - 30) " y" (y + 20) " w24 h24 +0x100", Icon.More, C, 9, Theme.Muted)
            chk := UI.IconText(g, "x" (CX + CW - 26) " y" (y + 4) " w16 h16 +0x200 Center", Icon.Check, Theme.Accent, 7, Theme.AccentInk)
            Theme.Round(chk, 16, 16, 8)
            this.Cards.Push({fr: fr, plate: plate, title: title, keyf: keyf, key: key, catb: catb, cat: cat, sub1: sub1, sub2: sub2, cnt: cnt, sw: sw, keb: keb, chk: chk, id: ""})
            fr.i.OnEvent("Click", this.CardClicker(A_Index))
            fr.i.OnEvent("DoubleClick", this.CardOpener(A_Index))
            keb.OnEvent("Click", this.KebClicker(A_Index))
            this.Hwnds[fr.i.Hwnd] := {t: "card", i: A_Index}
            Hover.Add(fr.i, SlotHover("card", A_Index), g.Hwnd)
        }

        ; пустое состояние (горизонтальная плашка)
        e := this.E
        e.fr := UI.Frame(g, CX, this.LT, CW, 76, C, 12)
        e.ic := UI.IconText(g, "x" (CX + 16) " y" (this.LT + 16) " w44 h44", Icon.Search, Theme.Field, 14, Theme.Muted)
        Theme.Round(e.ic, 44, 44, 22)
        e.t := UI.Text(g, "x" (CX + 76) " y" (this.LT + 16) " w" (CW - 240) " h20", "", C, 11, Theme.Text, 700)
        e.s := UI.Text(g, "x" (CX + 76) " y" (this.LT + 38) " w" (CW - 240) " h30", "", C, 9, Theme.Muted)
        e.b := Btn.Add(g, "x" (CX + CW - 150) " y" (this.LT + 19) " w134 h38", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "ghost", 9, Icon.Add, C)

        ; ================= пагинация =================
        py := H - 46
        Mk(x, glyph) {
            s := UI.Box(g, x, py, 28, 28, Theme.Field, 8, "+0x100")
            t := UI.IconText(g, "x" x " y" py " w28 h28 +0x200", glyph, Theme.Field, 8, Theme.Muted)
            return {s: s, t: t, page: 0}
        }
        this.PgPrev := Mk(CX, Icon.ChevL)
        this.PgPrev.s.OnEvent("Click", (*) => MainUI.PageBy(-1))
        loop 7 {
            s := UI.Box(g, CX, py, 28, 28, Theme.Field, 8, "+0x100")
            t := UI.Text(g, "x" CX " y" py " w28 h28 +0x200 Center", "", Theme.Field, 9, Theme.Muted, 600)
            slot := {s: s, t: t, page: 0}
            s.OnEvent("Click", this.Pager(A_Index))
            this.PgSlots.Push(slot)
        }
        this.PgNext := Mk(CX, Icon.ChevR)
        this.PgNext.s.OnEvent("Click", (*) => MainUI.PageBy(1))
        this.PgInfo := UI.Text(g, "x" CX " y" py " w" CW " h28 +0x200 Right", "", B, 8, Theme.Faint)

        ; ================= правая панель =================
        PX := this.PX, PW := this.PW
        px := PX + 18, pw := PW - 36
        UI.Frame(g, PX, 120, PW, H - 136, C, 14)
        d := this.D
        d.px := px, d.pw := pw
        d.foot := H >= 640
        footH := d.foot ? 34 : 0
        bb := H - 30 - footH
        d.yDel := bb - 30, d.yShare := d.yDel - 36, d.yDup := d.yShare - 36, d.yMain := d.yDup - 40
        d.yS2 := d.yMain - 12 - 26, d.yS1 := d.yS2 - 32

        d.ic := UI.IconText(g, "x" px " y138 w38 h38", "", Theme.AccentSoft, 12, Theme.Accent)
        Theme.Round(d.ic, 38, 38, 10)
        d.name := UI.Text(g, "x" (px + 50) " y140 w" (pw - 110) " h22", "", C, 12, Theme.Text, 700)
        d.keyf := UI.Frame(g, px + 50, 141, 40, 20, Theme.Field, 6, Theme.KeyLine)
        d.key := UI.Text(g, "x" (px + 50) " y141 w40 h20 +0x200 Center", "", Theme.Field, 8, Theme.Text, 700, Theme.Mono)
        d.keb := UI.IconText(g, "x" (px + pw - 24) " y138 w24 h24 +0x100", Icon.More, C, 9, Theme.Muted)
        d.keb.OnEvent("Click", (*) => MainUI.DetailMenu())
        d.st := UI.Text(g, "x" px " y186 w80 h20 +0x200 Center", "", Theme.SuccessBg, 8, Theme.Success, 700)
        Theme.Round(d.st, 80, 20, 10)
        d.catb := UI.Box(g, px, 186, 70, 20, Theme.AccentSoft, 10)
        d.cat := UI.Text(g, "x" px " y186 w70 h20 +0x200 Center", "", Theme.AccentSoft, 8, Theme.Accent, 600)
        d.hint := UI.Text(g, "x" px " y186 w" pw " h44", "", C, 9, Theme.Muted)
        d.compact := H < 640
        if !d.compact {
            d.dlbl := UI.Text(g, "x" px " y218 w" pw " h16", "Описание", C, 9, Theme.Muted, 600)
            d.dfr := UI.Frame(g, px, 234, pw, 54, Theme.Bg, 8)
            d.desc := UI.Text(g, "x" (px + 12) " y240 w" (pw - 24) " h42", "", Theme.Bg, 9, Theme.Soft)
            d.plblY := 300, d.pvY := 316
        } else {
            d.dlbl := UI.Text(g, "x" px " y218 w" pw " h16", "Описание", C, 9, Theme.Muted, 600)
            d.dfr := UI.Frame(g, px, 234, pw, 54, Theme.Bg, 8)
            d.desc := UI.Text(g, "x" (px + 12) " y240 w" (pw - 24) " h42", "", Theme.Bg, 9, Theme.Soft)
            d.plblY := 218, d.pvY := 234
        }
        pvH := d.yS1 - 10 - d.pvY
        d.plbl := UI.Text(g, "x" px " y" d.plblY " w" pw " h16", "Предпросмотр", C, 9, Theme.Muted, 600)
        d.pbox := UI.Box(g, px, d.pvY, pw, pvH, Theme.ChatBg, 10)
        d.rv := RichView(g, px + 10, d.pvY + 8, pw - 20, pvH - 16, Theme.ChatBg)

        ; статистика 2×2
        Cell(x, y, glyph) {
            ic := UI.IconText(g, "x" x " y" y " w26 h26", glyph, Theme.Field, 9, Theme.Muted)
            Theme.Round(ic, 26, 26, 7)
            l := UI.Text(g, "x" (x + 34) " y" (y - 2) " w" (pw // 2 - 40) " h14", "", C, 8, Theme.Muted)
            v := UI.Text(g, "x" (x + 34) " y" (y + 12) " w" (pw // 2 - 40) " h16", "", C, 9, Theme.Text, 600)
            return {ic: ic, l: l, v: v}
        }
        d.s1 := Cell(px, d.yS1, Icon.Doc)
        d.s2 := Cell(px + pw // 2, d.yS1, Icon.Keyboard)
        d.s3 := Cell(px, d.yS2, Icon.Folder)
        d.s4 := Cell(px + pw // 2, d.yS2, Icon.Clock)

        d.main := Btn.Add(g, "x" px " y" d.yMain " w" pw " h36", "Редактировать", (*) => MainUI.EditSelected(), "primary", 10, Icon.Edit, C)
        d.b1 := Btn.Add(g, "x" px " y" d.yDup " w" pw " h30", "Дублировать", (*) => MainUI.DuplicateSelected(), "ghost", 9, Icon.Copy, C)
        d.b2 := Btn.Add(g, "x" px " y" d.yShare " w" pw " h30", "Поделиться", (*) => MainUI.ShareSelected(), "ghost", 9, Icon.Share, C)
        d.b3 := Btn.Add(g, "x" px " y" d.yDel " w" pw " h30", "Удалить", (*) => MainUI.DeleteSelected(), "danger", 9, Icon.Delete, C)

        d.f1l := UI.Text(g, "x" px " y" (bb + 6) " w" (pw // 2) " h14", "Последние изменения", C, 8, Theme.Faint)
        d.f1v := UI.Text(g, "x" px " y" (bb + 19) " w" (pw // 2) " h14", "", C, 9, Theme.Soft, 600)
        d.f2l := UI.Text(g, "x" (px + pw // 2) " y" (bb + 6) " w" (pw // 2) " h14", "Автор", C, 8, Theme.Faint)
        d.f2v := UI.Text(g, "x" (px + pw // 2) " y" (bb + 19) " w" (pw // 2) " h14", "Вы", C, 9, Theme.Soft, 600)

        g.OnEvent("Close", (*) => MainUI.G.Hide())
        g.OnEvent("Escape", (*) => MainUI.OnEsc())
        g.OnEvent("ContextMenu", ObjBindMethod(this, "OnContext"))
        OnMessage(0x20A, ObjBindMethod(this, "OnWheel"))

        ; горячие клавиши внутри окна
        HotIf((*) => MainUI.G && WinActive("ahk_id " MainUI.G.Hwnd))
        Hotkey("^f", (*) => (MainUI.SearchE.Focus(), SendMessage(0xB1, 0, -1, MainUI.SearchE)))
        Hotkey("^k", (*) => (MainUI.SearchE.Focus(), SendMessage(0xB1, 0, -1, MainUI.SearchE)))
        Hotkey("^n", (*) => Editor.Open("", MainUI.CurCat))
        Hotkey("^i", (*) => Share.ImportDialog())
        HotIf((*) => MainUI.G && WinActive("ahk_id " MainUI.G.Hwnd) && !MainUI.InSearch())
        Hotkey("Delete", (*) => MainUI.DeleteSelected())
        Hotkey("Enter", (*) => MainUI.EditSelected())
        Hotkey("^d", (*) => MainUI.DuplicateSelected())
        Hotkey("^a", (*) => MainUI.SelectAll())
        Hotkey("Up", (*) => MainUI.MoveSel(-1))
        Hotkey("Down", (*) => MainUI.MoveSel(1))
        HotIf()

        Theme.Dark(g)
        g.Show("w" W " h" H " Hide")
        this.GameFn := ObjBindMethod(this, "UpdateGame")
        SetTimer(this.GameFn, 4000)
        this.UpdateStatus()
        this.UpdateProfile()
        this.Refresh()
    }

    static InSearch() {
        try return ControlGetFocus("ahk_id " this.G.Hwnd) = this.SearchE.Hwnd
        return false
    }

    static NavClicker(i) {
        return (*) => MainUI.OnNav(i)
    }
    static CardClicker(i) {
        return (*) => MainUI.OnCard(i)
    }
    static CardOpener(i) {
        return (*) => (MainUI.Cards[i].id != "" ? Editor.Open(MainUI.Cards[i].id) : 0)
    }
    static KebClicker(i) {
        return (*) => MainUI.OnKeb(i)
    }
    static Switcher(i) {
        return (state) => MainUI.OnCardSwitch(i, state)
    }
    static Pager(i) {
        return (*) => MainUI.OnPage(i)
    }

    static OnKeb(i) {
        id := this.Cards[i].id
        if id = ""
            return
        if !this.Sel.Has(id)
            this.SelectId(id)
        this.CardMenu(id).Show()
    }

    static DetailMenu() {
        ids := this.SelectedIds()
        if ids.Length
            this.CardMenu(ids[1]).Show()
    }

    static OnPage(i) {
        p := this.PgSlots[i].page
        if p {
            this.Offset := (p - 1) * this.CardN
            this.RenderCards()
        }
    }

    static PageBy(dir) {
        this.Offset += dir * this.CardN
        this.RenderCards()
    }

    static ClearSearch() {
        this.SearchE.Value := ""
        this.Offset := 0
        this.Refresh()
        this.SearchE.Focus()
    }

    static OnEsc() {
        if Trim(this.SearchE.Value) != ""
            return this.ClearSearch()
        if this.Sel.Count {
            this.Sel := Map()
            this.RenderCards()
            return this.UpdateDetail()
        }
        this.G.Hide()
    }

    ; ================= обновление =================
    static UpdateStatus() {
        if !this.G
            return
        on := Keys.Enabled
        this.StDot.SetFont("c" (on ? Theme.Success : Theme.Danger))
        this.StText.SetFont("c" (on ? Theme.Success : Theme.Danger))
        this.StText.Value := on ? "Биндер активен" : "На паузе"
        this.EnableSw.Set(on)
        for c in [this.StDot, this.StText]
            c.Redraw()
        this.UpdateGame()
    }

    static UpdateGame() {
        if !this.G
            return
        s := Store.Data["settings"]
        exe := String(s["gameExe"])
        this.GameName.Value := InStr(exe, "gta_sa") ? "GTA SAMP RP" : exe
        gameRunning := false
        try gameRunning := WinExist("ahk_exe " exe) != 0
        this.GameSt.SetFont("c" (gameRunning ? Theme.Success : Theme.Faint))
        this.GameSt.Value := gameRunning ? "● Подключен" : "○ Не в игре"
        for c in [this.GameName, this.GameSt]
            c.Redraw()
    }

    static UpdateProfile() {
        if !this.G
            return
        p := Store.Data["profile"]
        nick := String(p["nick"])
        this.ProfName.Value := nick != "" ? StrReplace(nick, "_", " ") : "Укажите ник"
        this.ProfInfo.Value := p["rank"] != "" ? p["rank"] : "профиль не заполнен"
        this.ProfId.Value := p["id"] != "" ? "ID: " p["id"] : "ID не указан"
        ini := ""
        for part in StrSplit(StrReplace(nick, " ", "_"), "_")
            if part != "" && StrLen(ini) < 2
                ini .= StrUpper(SubStr(part, 1, 1))
        this.Avatar.Value := ini != "" ? ini : "?"
    }

    static Refresh() {
        if !this.G
            return
        found := false
        for c in Store.Data["categories"]
            if c = this.CurCat
                found := true
        if !found
            this.CurCat := ""

        this.NavItems := [{label: "Главная", cat: "", n: Store.Data["binds"].Length, glyph: Icon.Home}]
        for c in Store.Data["categories"]
            this.NavItems.Push({label: c, cat: c, n: Store.CountIn(c), glyph: Icon.ForCat(c)})

        q := StrLower(Trim(this.SearchE.Value))
        this.SearchX.Visible := q != ""
        this.Rows := []
        for b in Store.Data["binds"] {
            if this.CurCat != "" && b["category"] != this.CurCat
                continue
            if q != "" && !InStr(StrLower(b["name"] " " b["lines"] " " b["hotkey"] " " Keys.Pretty(b["hotkey"])), q)
                continue
            this.Rows.Push(b["id"])
        }
        keep := Map()
        for id in this.Rows
            if this.Sel.Has(id)
                keep[id] := 1
        this.Sel := keep

        this.TitleT.Value := this.CurCat = "" ? "Все бинды" : this.CurCat
        this.TitleI.Value := this.CurCat = "" ? Icon.Home : Icon.ForCat(this.CurCat)
        this.CountT.Move(this.CX + 54 + Min(UI.TextW(this.TitleT.Value, 15, 700), 300) + 16, 31, this.CW - 60, 20)
        n := this.Rows.Length
        if q != ""
            this.CountT.Value := "Найдено " n " " this.Plural(n, "бинд", "бинда", "биндов") " по запросу «" Trim(this.SearchE.Value) "»"
        else {
            k := this.Sel.Count
            this.CountT.Value := n " " this.Plural(n, "бинд", "бинда", "биндов") (k ? "  ·  " k " " this.Plural(k, "выбран", "выбрано", "выбрано") : "")
        }
        this.RenderNav()
        this.RenderCards()
        this.UpdateDetail()
    }

    static Plural(n, one, few, many) {
        n := Mod(Abs(n), 100)
        if n >= 11 && n <= 14
            return many
        n := Mod(n, 10)
        return n = 1 ? one : (n >= 2 && n <= 4) ? few : many
    }

    static RenderNav() {
        maxOff := Max(0, this.NavItems.Length - this.NavN)
        this.NavOffset := Min(Max(this.NavOffset, 0), maxOff)
        loop this.NavN {
            nav := this.Navs[A_Index]
            idx := this.NavOffset + A_Index
            show := idx <= this.NavItems.Length
            for k in ["plate", "ic", "name", "cnt"]
                nav.%k%.Visible := show
            if !show {
                nav.item := 0, nav.bar.Visible := false
                continue
            }
            it := this.NavItems[idx]
            nav.item := it
            nav.ic.Value := it.glyph
            nav.name.Value := it.label
            nav.cnt.Value := it.n
            this.PaintNav(A_Index)
        }
    }

    static PaintNav(i) {
        nav := this.Navs[i]
        if !nav.item
            return
        on := nav.item.cat = this.CurCat
        hv := this.HoverNav = i
        bg := on ? Theme.Card : hv ? Theme.CardHover : Theme.Side
        UI.Paint(nav.plate, bg)
        nav.bar.Visible := on
        nav.ic.SetFont("c" (on ? Theme.Accent : hv ? Theme.Soft : Theme.Muted))
        nav.name.SetFont((on ? "w600 c" Theme.Text : "w500 c" (hv ? Theme.Text : Theme.Soft)))
        nav.cnt.SetFont("c" (on ? Theme.Accent : Theme.Faint))
        UI.Paint(nav.ic, bg), UI.Paint(nav.name, bg), UI.Paint(nav.cnt, bg)
        if on
            nav.bar.Redraw()
    }

    ; первые значимые строки бинда (без комментариев и пауз)
    static FirstLines(b, n := 2) {
        out := []
        for ln in StrSplit(b["lines"], "`n") {
            t := Trim(ln)
            if t = "" || SubStr(t, 1, 1) = "#" || RegExMatch(t, "i)^{wait")
                continue
            out.Push(t)
            if out.Length = n
                break
        }
        return out
    }

    static RenderCards() {
        maxOff := Max(0, this.Rows.Length - this.CardN)
        this.Offset := Min(Max(this.Offset, 0), maxOff)
        parts := ["plate", "title", "key", "cat", "sub1", "sub2", "cnt", "keb", "chk"]
        loop this.CardN {
            card := this.Cards[A_Index]
            idx := this.Offset + A_Index
            show := idx <= this.Rows.Length
            card.fr.o.Visible := show, card.fr.i.Visible := show
            card.keyf.o.Visible := show, card.keyf.i.Visible := show
            card.catb.Visible := show
            for k in parts
                card.%k%.Visible := show
            card.sw.Track.Visible := show, card.sw.Knob.Visible := show, card.sw.Lbl.Visible := show
            if !show {
                card.id := ""
                continue
            }
            b := Store.Find(this.Rows[idx])
            card.id := b["id"]
            steps := Sender.Plan(b)
            lines := this.FirstLines(b)
            maxc := (this.CW - 302) // 6
            l1 := lines.Length ? lines[1] : "нет строк для отправки"
            l2 := lines.Length > 1 ? lines[2] : ""
            card.plate.Value := Icon.ForCat(b["category"])
            card.title.Value := b["name"]
            card.title.SetFont("c" (b["enabled"] ? Theme.Text : Theme.Muted))
            card.sub1.Value := StrLen(l1) > maxc ? SubStr(l1, 1, maxc - 1) "…" : l1
            card.sub1.SetFont("c" (SubStr(l1, 1, 3) = "/me" ? Theme.AccentLine : Theme.Soft))
            card.sub2.Value := StrLen(l2) > maxc ? SubStr(l2, 1, maxc - 1) "…" : l2
            ; бейдж клавиши
            kx := this.CX + 62 + Min(UI.TextW(b["name"], 10, 600), this.CW - 322) + 10
            kt := b["hotkey"] != "" ? Keys.Pretty(b["hotkey"]) : "—"
            kw := Max(30, UI.TextW(kt, 8, 700, Theme.Mono) + 16)
            card.key.Value := kt
            card.key.SetFont("c" (b["hotkey"] = "" ? Theme.Faint : Theme.Text))
            ; бейдж категории
            ct := b["category"]
            cw2 := UI.TextW(ct, 8, 600) + 16
            card.cat.Value := ct
            this.MoveKeyBadge(card, kx, kw, this.LT + (A_Index - 1) * this.STEP, cw2)
            n := steps.Length
            card.cnt.Value := n " " this.Plural(n, "строка", "строки", "строк")
            card.sw.Set(b["enabled"])
            card.sw.Lbl.Value := b["enabled"] ? "Вкл" : "Выкл"
            card.sw.Lbl.SetFont("c" (b["enabled"] ? Theme.Soft : Theme.Faint))
            this.PaintCard(A_Index)
        }
        n := this.Rows.Length, e := this.E
        empty := !n
        for k in ["fr", "ic", "t", "s"]
            e.%k%.Visible := empty
        e.b.Show(empty)
        if empty {
            q := Trim(this.SearchE.Value)
            if q != "" {
                e.ic.Value := Icon.Search
                e.t.Value := "Ничего не найдено"
                e.s.Value := "Попробуйте изменить запрос или создайте новый бинд."
                e.b.Set("Создать бинд", Icon.Add, (*) => Editor.Open("", MainUI.CurCat))
            } else {
                e.ic.Value := this.CurCat = "" ? Icon.All : Icon.ForCat(this.CurCat)
                e.t.Value := this.CurCat = "" ? "Здесь пока пусто" : "В «" this.CurCat "» пока нет биндов"
                e.s.Value := "Создайте первый бинд или импортируйте код MEDBIND от другого игрока."
                e.b.Set("Создать бинд", Icon.Add, (*) => Editor.Open("", MainUI.CurCat))
            }
        }
        this.RenderPager()
    }

    static MoveKeyBadge(card, kx, kw, y, cw2) {
        card.keyf.o.Move(kx, y + 8, kw, 18)
        card.keyf.i.Move(kx + 1, y + 9, kw - 2, 16)
        Theme.Round(card.keyf.o, kw, 18, 6)
        Theme.Round(card.keyf.i, kw - 2, 16, 5)
        card.key.Move(kx, y + 8, kw, 18)
        cx := kx + kw + 8
        card.catb.Move(cx, y + 8, cw2, 18)
        Theme.Round(card.catb, cw2, 18, 6)
        card.cat.Move(cx, y + 8, cw2, 18)
    }

    static RenderPager() {
        n := this.Rows.Length
        pages := Max(1, Ceil(n / this.CardN))
        cur := Min(this.Offset // this.CardN + 1, pages)
        show := pages > 1 && n > 0
        cnt := Min(7, pages)
        start := Max(1, Min(cur - 3, pages - cnt + 1))
        total := 64 + cnt * 36
        x := this.CX + (this.CW - total) // 2
        this.PgPrev.s.Visible := show, this.PgPrev.t.Visible := show
        this.PgNext.s.Visible := show, this.PgNext.t.Visible := show
        this.PgPrev.s.Move(x, this.H - 46), this.PgPrev.t.Move(x, this.H - 46)
        UI.Paint(this.PgPrev.s, cur > 1 ? Theme.Field : Theme.Bg)
        this.PgPrev.t.SetFont("c" (cur > 1 ? Theme.Muted : Theme.Faint))
        x2 := x + 36
        loop 7 {
            slot := this.PgSlots[A_Index]
            si := A_Index
            on := si <= cnt
            slot.s.Visible := show && on, slot.t.Visible := show && on
            if !on {
                slot.page := 0
                continue
            }
            p := start + si - 1
            slot.page := p
            sx := x2 + (si - 1) * 36
            slot.s.Move(sx, this.H - 46), slot.t.Move(sx, this.H - 46)
            slot.t.Value := p
            act := p = cur
            UI.Paint(slot.s, act ? Theme.AccentSoft : Theme.Field)
            slot.t.SetFont("c" (act ? Theme.Accent : Theme.Muted))
        }
        nx := x + 36 + cnt * 36
        this.PgNext.s.Move(nx, this.H - 46), this.PgNext.t.Move(nx, this.H - 46)
        UI.Paint(this.PgNext.s, cur < pages ? Theme.Field : Theme.Bg)
        this.PgNext.t.SetFont("c" (cur < pages ? Theme.Muted : Theme.Faint))
        from := n ? this.Offset + 1 : 0
        to := Min(n, this.Offset + this.CardN)
        this.PgInfo.Value := n ? "Показано " (to - from + 1) " из " n " биндов" : ""
    }

    static PaintCard(i) {
        card := this.Cards[i]
        if card.id = ""
            return
        sel := this.Sel.Has(card.id)
        hv := this.HoverCard = i
        bg := sel ? Theme.CardSel : hv ? Theme.CardHover : Theme.Card
        UI.Paint(card.fr.o, sel ? Theme.Accent : hv ? Theme.LineHover : Theme.Line)
        UI.Paint(card.fr.i, bg)
        for k in ["title", "sub1", "sub2", "cnt"]
            UI.Paint(card.%k%, bg)
        UI.Paint(card.plate, Theme.Field)
        UI.Paint(card.keb, bg)
        UI.Paint(card.sw.Lbl, bg)
        card.chk.Visible := sel
        if sel
            card.chk.Redraw()
    }

    static Hovered(kind, i, on) {
        if kind = "card" {
            old := this.HoverCard
            this.HoverCard := on ? i : (this.HoverCard = i ? 0 : this.HoverCard)
            if old && old != i
                this.PaintCard(old)
            this.PaintCard(i)
        } else {
            old := this.HoverNav
            this.HoverNav := on ? i : (this.HoverNav = i ? 0 : this.HoverNav)
            if old && old != i
                this.PaintNav(old)
            this.PaintNav(i)
        }
    }

    ; правая панель: обзор / один бинд / несколько
    static UpdateDetail() {
        d := this.D
        ids := this.SelectedIds()
        one := ids.Length = 1
        showOne := [d.keyf.o, d.keyf.i, d.key, d.keb, d.st, d.catb, d.cat, d.dlbl, d.dfr.o, d.dfr.i, d.desc]
        showStats := [d.s1.ic, d.s1.l, d.s1.v, d.s2.ic, d.s2.l, d.s2.v, d.s3.ic, d.s3.l, d.s3.v, d.s4.ic, d.s4.l, d.s4.v]
        showFoot := [d.f1l, d.f1v, d.f2l, d.f2v]
        for c in showOne
            c.Visible := one
        if d.compact
            d.dlbl.Visible := false, d.dfr.o.Visible := false, d.dfr.i.Visible := false, d.desc.Visible := false
        for c in showStats
            c.Visible := one
        for c in showFoot
            c.Visible := one && d.foot
        d.hint.Visible := !one
        if !ids.Length {
            d.ic.Value := Icon.Home
            d.name.Value := "Ничего не выбрано"
            d.hint.Value := "Выберите бинд в списке — здесь появятся описание и предпросмотр. Двойной клик — редактор."
            d.plbl.Value := "Горячие клавиши"
            d.rv.Set(Preview.Overview())
            d.main.Show(false), d.b1.Show(false), d.b2.Show(false), d.b3.Show(false)
            return
        }
        if !one {
            d.ic.Value := Icon.All
            d.name.Value := ids.Length " " this.Plural(ids.Length, "бинд", "бинда", "биндов")
            d.hint.Value := "Ctrl + клик — добавить или убрать, Shift + клик — диапазон, Esc — снять выбор."
            d.plbl.Value := "Список"
            d.rv.Set(Preview.List(ids))
            d.main.Show(true)
            d.main.Set("Поделиться (" ids.Length ")", Icon.Share, (*) => MainUI.ShareSelected())
            d.b1.Show(true), d.b1.Set("Перенести", Icon.Move, (*) => MainUI.MoveMenu())
            d.b2.Show(true), d.b2.Set("Вкл / выкл", Icon.Power, (*) => MainUI.ToggleSelected())
            d.b3.Show(true), d.b3.Set("Удалить", Icon.Delete)
            return
        }
        b := Store.Find(ids[1])
        px := d.px, pw := d.pw
        d.ic.Value := Icon.ForCat(b["category"])
        d.name.Value := b["name"]
        kt := b["hotkey"] != "" ? Keys.Pretty(b["hotkey"]) : "нет клавиши"
        kw := Min(120, Max(34, UI.TextW(kt, 8, 700, Theme.Mono) + 16))
        kx := px + 50 + Min(UI.TextW(b["name"], 12, 700), pw - 110) + 10
        d.keyf.o.Move(kx, 141, kw, 20)
        d.keyf.i.Move(kx + 1, 142, kw - 2, 18)
        Theme.Round(d.keyf.o, kw, 20, 6)
        Theme.Round(d.keyf.i, kw - 2, 18, 5)
        d.key.Move(kx, 141, kw, 20)
        d.key.Value := kt
        d.key.SetFont("c" (b["hotkey"] = "" ? Theme.Faint : Theme.Text))
        on := b["enabled"]
        d.st.Value := on ? "● Активен" : "○ Выкл"
        d.st.SetFont("c" (on ? Theme.Success : Theme.Danger))
        UI.Paint(d.st, on ? Theme.SuccessBg : Theme.DangerBg)
        stw := Max(64, UI.TextW(d.st.Value, 8, 700) + 20)
        d.st.Move(px, 186, stw, 20)
        Theme.Round(d.st, stw, 20, 10)
        cw2 := UI.TextW(b["category"], 8, 600) + 16
        d.catb.Move(px + stw + 8, 186, cw2, 20)
        Theme.Round(d.catb, cw2, 20, 10)
        d.cat.Move(px + stw + 8, 186, cw2, 20)
        d.cat.Value := b["category"]
        ; описание — первые значимые строки
        lines := this.FirstLines(b)
        desc := ""
        for t in lines
            desc .= (desc != "" ? "`n" : "") t
        d.desc.Value := desc != "" ? desc : "Описания нет — добавьте строки в редакторе."
        d.plbl.Value := "Предпросмотр"
        d.rv.Set(Preview.Chat(b))
        ; статистика
        steps := Sender.Plan(b)
        d.s1.l.Value := "Строк", d.s1.v.Value := steps.Length
        d.s2.l.Value := "Горячая клавиша", d.s2.v.Value := b["hotkey"] != "" ? Keys.Pretty(b["hotkey"]) : "—"
        d.s3.l.Value := "Категория", d.s3.v.Value := b["category"]
        d.s4.l.Value := "Пауза", d.s4.v.Value := Format("{:.1f} с", Store.Num(b["delay"], 1300) / 1000)
        ; кнопки
        d.main.Show(true)
        d.main.Set("Редактировать", Icon.Edit, (*) => MainUI.EditSelected())
        d.b1.Show(true), d.b1.Set("Дублировать", Icon.Copy, (*) => MainUI.DuplicateSelected())
        d.b2.Show(true), d.b2.Set("Поделиться", Icon.Share, (*) => MainUI.ShareSelected())
        d.b3.Show(true), d.b3.Set("Удалить", Icon.Delete)
        d.f1v.Value := this.When(b["id"])
        for c in [d.key, d.st, d.cat]
            c.Redraw()
    }

    static Touch(id) {
        this.Touched[id] := A_Now
    }

    static When(id) {
        if !this.Touched.Has(id)
            return "—"
        t := this.Touched[id]
        return SubStr(t, 1, 8) = SubStr(A_Now, 1, 8) ? "Сегодня, " FormatTime(t, "HH:mm") : FormatTime(t, "dd.MM HH:mm")
    }

    static SelectedIds() {
        ids := []
        for id in this.Rows
            if this.Sel.Has(id)
                ids.Push(id)
        return ids
    }

    static IndexOfRow(id) {
        for i, rid in this.Rows
            if rid = id
                return i
        return 0
    }

    static SelectId(id, *) {
        if !this.IndexOfRow(id) {         ; бинд скрыт фильтром — показать все
            this.CurCat := "", this.SearchE.Value := ""
            this.Refresh()
        }
        this.Sel := Map(id, 1)
        this.Anchor := id
        if i := this.IndexOfRow(id) {
            if i <= this.Offset
                this.Offset := i - 1
            else if i > this.Offset + this.CardN
                this.Offset := i - this.CardN
        }
        this.RenderCards()
        this.UpdateDetail()
    }

    static SelectAll() {
        this.Sel := Map()
        for id in this.Rows
            this.Sel[id] := 1
        this.RenderCards()
        this.UpdateDetail()
    }

    static MoveSel(dir) {
        if !this.Rows.Length
            return
        ids := this.SelectedIds()
        i := ids.Length ? this.IndexOfRow(ids[dir > 0 ? ids.Length : 1]) + dir : 1
        i := Min(Max(i, 1), this.Rows.Length)
        this.SelectId(this.Rows[i])
    }

    ; ================= события =================
    static OnCard(i) {
        id := this.Cards[i].id
        if id = ""
            return
        if GetKeyState("Ctrl") {
            if this.Sel.Has(id)
                this.Sel.Delete(id)
            else
                this.Sel[id] := 1
            this.Anchor := id
        } else if GetKeyState("Shift") && this.Anchor != "" && (a := this.IndexOfRow(this.Anchor)) {
            b := this.IndexOfRow(id)
            this.Sel := Map()
            loop Abs(b - a) + 1
                this.Sel[this.Rows[Min(a, b) + A_Index - 1]] := 1
        } else {
            this.Sel := Map(id, 1)
            this.Anchor := id
        }
        this.RenderCards()
        this.UpdateDetail()
    }

    static OnCardSwitch(i, on) {
        id := this.Cards[i].id
        if id = ""
            return
        if b := Store.Find(id) {
            b["enabled"] := on ? 1 : 0
            this.Touch(id)
            Store.Save()
            Keys.Apply()
            this.Refresh()
        }
    }

    static OnNav(i) {
        it := this.Navs[i].item
        if !it
            return
        this.CurCat := it.cat
        this.Offset := 0
        this.Sel := Map()
        this.Refresh()
    }

    static OnWheel(wParam, lParam, msg, hwnd) {
        if !this.G
            return
        try MouseGetPos(&mx, , &win)
        catch
            return
        if win != this.G.Hwnd
            return
        step := ((wParam >> 16) & 0xFFFF) > 0x7FFF ? 1 : -1
        s := A_ScreenDPI / 96
        if mx < this.SW * s {
            this.NavOffset -= step
            this.RenderNav()
        } else if mx > this.PX * s {
            SendMessage(0xB5, step > 0 ? 0 : 1, 0, this.D.rv.C)    ; EM_SCROLL
        } else {
            this.Offset -= step
            this.RenderCards()
        }
        return 0
    }

    static OnContext(g, ctrl, item, isRightClick, x, y) {
        if !IsObject(ctrl) || !this.Hwnds.Has(ctrl.Hwnd)
            return
        hit := this.Hwnds[ctrl.Hwnd]
        if hit.t = "card" {
            id := this.Cards[hit.i].id
            if id = ""
                return
            if !this.Sel.Has(id)
                this.SelectId(id)
            this.CardMenu(id).Show()
        } else {
            it := this.Navs[hit.i].item
            if !it || it.cat = ""
                return
            name := it.cat
            m := Menu()
            m.Add("Новый бинд здесь", (*) => Editor.Open("", name))
            m.Add("Изменить категорию…", (*) => MainUI.RenameCategory(name))
            m.Add()
            m.Add("Удалить категорию", (*) => MainUI.DeleteCategory(name))
            m.Show()
        }
    }

    static CardMenu(id) {
        b := Store.Find(id)
        ids := this.SelectedIds()
        m := Menu()
        if ids.Length = 1 {
            m.Add("Редактировать`tEnter", (*) => Editor.Open(id))
            m.Add("Дублировать`tCtrl+D", (*) => MainUI.DuplicateSelected())
            m.Add(b["enabled"] ? "Выключить" : "Включить", (*) => MainUI.ToggleBind(id))
        } else {
            m.Add("Включить / выключить", (*) => MainUI.ToggleSelected())
        }
        m.Add("Поделиться", (*) => Share.ExportDialog(ids))
        if Store.Data["categories"].Length > 1
            m.Add("Перенести в", this.CatMenu(ids))
        m.Add()
        m.Add("Удалить`tDelete", (*) => MainUI.DeleteSelected())
        return m
    }

    static CatMenu(ids) {
        sub := Menu()
        for c in Store.Data["categories"]
            sub.Add(c, this.Mover(ids, c))
        return sub
    }

    static MoveMenu() {
        ids := this.SelectedIds()
        if ids.Length
            this.CatMenu(ids).Show()
    }

    ; ================= действия =================
    static NewCategory() {
        r := Dialogs.Category("Новая категория", "", "folder", this.G)
        if !r
            return
        Store.EnsureCategory(r.name)
        Store.SetCatIcon(r.name, r.icon)
        Store.Save()
        this.CurCat := r.name
        this.Sel := Map()
        this.Refresh()
        Toast.Show("Категория «" r.name "» добавлена", "Категории", , "success")
    }

    static RenameCategory(old) {
        r := Dialogs.Category("Изменить категорию", old, Store.CatIcon(old), this.G)
        if !r
            return
        if r.name != old
            Store.RenameCategory(old, r.name)
        Store.SetCatIcon(r.name, r.icon)
        Store.Save()
        this.CurCat := r.name
        this.Refresh()
    }

    static DeleteCategory(name) {
        n := Store.CountIn(name)
        text := "Категория «" name "» будет удалена." (n ? "`nБинды (" n ") не пропадут — они перейдут в первую категорию." : "")
        if !Dialogs.Confirm("Удалить категорию?", text, "Удалить", true, this.G)
            return
        fb := Store.DeleteCategory(name)
        Store.Save()
        this.CurCat := ""
        this.Refresh()
        Toast.Show(n ? "Бинды перемещены в «" fb "»" : "Категория удалена", "Категория удалена", , "success")
    }

    static EditSelected() {
        ids := this.SelectedIds()
        if ids.Length
            Editor.Open(ids[1])
    }

    static DuplicateSelected() {
        ids := this.SelectedIds()
        if !ids.Length
            return
        c := Store.Duplicate(ids[1])
        Store.Save()
        this.Refresh()
        if c {
            this.Touch(c["id"])
            this.SelectId(c["id"])
        }
        Toast.Show("Копия создана без клавиши — назначьте её в редакторе", "Дублировано", , "success")
    }

    static DeleteSelected() {
        ids := this.SelectedIds()
        if !ids.Length
            return
        what := ids.Length = 1 ? "Бинд «" Store.Find(ids[1])["name"] "»" : "Выбранные бинды (" ids.Length ")"
        if !Dialogs.Confirm(ids.Length = 1 ? "Удалить бинд?" : "Удалить бинды?", what " будут удалены. Предыдущая версия файла останется в binder.backup.json.", "Удалить", true, this.G)
            return
        for id in ids
            Store.Remove(id)
        Store.Save()
        Keys.Apply()
        this.Sel := Map()
        this.Refresh()
        Toast.Show("Удалено: " ids.Length, "Бинды удалены", , "success")
    }

    static ShareSelected() {
        ids := this.SelectedIds()
        if !ids.Length
            ids := this.Rows.Clone()
        Share.ExportDialog(ids)
    }

    static ToggleBind(id) {
        if b := Store.Find(id) {
            b["enabled"] := !b["enabled"]
            this.Touch(id)
            Store.Save()
            Keys.Apply()
            this.Refresh()
        }
    }

    static ToggleSelected() {
        ids := this.SelectedIds()
        if !ids.Length
            return
        anyOff := false
        for id in ids
            if !Store.Find(id)["enabled"]
                anyOff := true
        for id in ids {
            Store.Find(id)["enabled"] := anyOff
            this.Touch(id)
        }
        Store.Save()
        Keys.Apply()
        this.Refresh()
        Toast.Show((anyOff ? "Включено: " : "Выключено: ") ids.Length, "Статус биндов", , anyOff ? "success" : "info")
    }

    static Mover(ids, cat) {
        return (*) => MainUI.MoveTo(ids, cat)
    }

    static MoveTo(ids, cat) {
        for id in ids
            if b := Store.Find(id) {
                b["category"] := cat
                this.Touch(id)
            }
        Store.Save()
        this.Refresh()
        Toast.Show("Перемещено в «" cat "»: " ids.Length, "Категория", , "success")
    }
}

; наведение на карточку / категорию
class SlotHover {
    __New(kind, i) {
        this.Kind := kind, this.I := i
    }
    Enter() {
        MainUI.Hovered(this.Kind, this.I, true)
    }
    Leave() {
        MainUI.Hovered(this.Kind, this.I, false)
    }
}


; ==================== Editor ====================

; ============================================================
;  Редактор бинда: «Основное» · «Текст» · живой предпросмотр чата
;  Одна строка текста = одно сообщение в чат
; ============================================================
class Editor {
    static Cur := 0          ; {g, save} для Ctrl+S / Ctrl+Enter
    static HkDone := false

    static Open(id := "", category := "") {
        if Editor.Cur {               ; уже открыт — просто показать
            try WinActivate("ahk_id " Editor.Cur.g.Hwnd)
            return
        }
        isNew := id = ""
        src := isNew ? Store.NewBind(category != "" ? category : Store.Data["categories"][1]) : Store.Find(id)
        if !src
            return
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        wh := (b - t) / (A_ScreenDPI / 96)
        EW := 1060, EH := Round(Min(720, Max(600, wh - 50)))
        B := Theme.Bg, C := Theme.Card
        st := {orig: "", dirty: false, last: ""}
        g := UI.NewGui(isNew ? "Новый бинд" : "Редактирование бинда")

        ; ---------- шапка ----------
        hi := UI.IconText(g, "x32 y24 w40 h40", isNew ? Icon.Add : Icon.Edit, Theme.AccentSoft, 13, Theme.Accent)
        Theme.Round(hi, 40, 40, 12)
        UI.Text(g, "x86 y22 w420 h26", isNew ? "Новый бинд" : "Редактирование", B, 14, Theme.Text, 700)
        UI.Text(g, "x86 y48 w420 h18", "Каждая строка текста уходит в чат отдельным сообщением", B, 9, Theme.Muted)
        dirtyT := UI.Text(g, "x520 y30 w132 h22 +0x200 Center", "●  ИЗМЕНЕНО", Theme.WarningBg, 8, Theme.Warning, 700)
        Theme.Round(dirtyT, 132, 22, 11)
        dirtyT.Visible := false

        ; ---------- основное ----------
        UI.Frame(g, 32, 84, 620, 168, C, 12)
        UI.Label(g, "x52 y100 w360 h16", "НАЗВАНИЕ", C)
        nameE := UI.Field(g, 52, 118, 360, 40, src["name"], "Limit60")
        UI.Cue(nameE, "Например: Лечение пациента")
        UI.Label(g, "x428 y100 w204 h16", "КАТЕГОРИЯ", C)
        catP := Picker(g, 428, 118, 204, 40, src["category"], () => Store.Data["categories"], true, (v) => Icon.ForCat(v))
        UI.Label(g, "x52 y172 w240 h16", "ГОРЯЧАЯ КЛАВИША", C)
        hkF := KeyField(g, 52, 190, 240, 42, src["hotkey"])
        keyI := UI.IconText(g, "x304 y190 w20 h42", Icon.Check, C, 10, Theme.Success)
        keyT := UI.Text(g, "x328 y190 w170 h42 +0x200", "", C, 8, Theme.Success, 600)
        enSw := SwitchCtl(g, 512, 197, 120, "Активен", src["enabled"], C)

        ; ---------- текст ----------
        UI.Label(g, "x32 y268 w300 h16", "ТЕКСТ БИНДА", B)
        UI.Text(g, "x352 y266 w300 h18 Right", "клик по чипу — вставить в курсор", B, 8, Theme.Faint)
        hT := EH - 326 - 100
        g.SetFont("s10 w400 q5", Theme.Mono)
        tf := UI.Frame(g, 32, 326, 620, hT, Theme.Field, 10)
        UI.Box(g, 33, 327, 46, hT - 2, Theme.Gutter, 9)
        UI.Box(g, 60, 327, 19, hT - 2, Theme.Gutter, 0)
        gutT := UI.Text(g, "x33 y336 w38 h" (hT - 20) " Right", "", Theme.Gutter, 10, Theme.Faint, 400, Theme.Mono)
        g.SetFont("s10 w400 q5 c" Theme.Text, Theme.Mono)
        textE := g.AddEdit("x92 y336 w552 h" (hT - 20) " -E0x200 Multi WantReturn WantTab +0x200000 Background" Theme.Field, StrReplace(src["lines"], "`n", "`r`n"))
        Theme.DarkCtrl(textE)
        UI.FocusRing(textE, tf.o)

        x := 32
        for c in ["{nick}", "{name}", "{rank}", "{org}", "{id}", "{time}", "{date}"] {
            w := UI.TextW(c, 9, 600) + 22
            Btn.Add(g, "x" x " y288 w" w " h28", c, this.Inserter(textE, c), "chip", 9, , B)
            x += w + 6
        }
        x += 8
        Btn.Add(g, "x" x " y288 w86 h28", "Пауза", (*) => Editor.AddLine(textE, "{wait 1000}"), "violet", 9, Icon.Clock, B)
        x += 92
        Btn.Add(g, "x" x " y288 w" (652 - x) " h28", "Без Enter", (*) => Editor.AppendToLine(textE, " {noenter}"), "violet", 9, Icon.Enter, B)

        ty := 326 + hT + 10
        Btn.Add(g, "x32 y" ty " w128 h32", "Строка", (*) => Editor.AddLine(textE, ""), "ghost", 9, Icon.Add, B)
        Btn.Add(g, "x168 y" ty " w150 h32", "Удалить строку", (*) => Editor.DeleteLine(textE), "ghost", 9, Icon.Delete, B)
        UI.Text(g, "x360 y" ty " w176 h32 +0x200 Right", "Пауза между строками", B, 9, Theme.Soft)
        delayE := UI.Field(g, 546, ty, 76, 32, src["delay"], "Number Limit5 Center")
        UI.Text(g, "x626 y" ty " w26 h32 +0x200", "мс", B, 9, Theme.Muted)
        UI.Text(g, "x32 y" (ty + 42) " w620 h16", "#  — комментарий (не отправляется)   ·   {wait 2000} отдельной строкой — своя пауза   ·   {noenter} — без Enter", B, 8, Theme.Faint)

        ; ---------- правая панель: предпросмотр и управление ----------
        UI.Box(g, 684, 0, EW - 684, EH, C, 0)
        UI.Box(g, 684, 0, 1, EH, Theme.Line, 0)
        UI.Label(g, "x708 y30 w328 h16", "ПРЕДПРОСМОТР ЧАТА", C)
        UI.Box(g, 708, 52, 328, EH - 52 - 200, Theme.ChatBg, 10)
        rv := RichView(g, 720, 64, 306, EH - 52 - 224, Theme.ChatBg)
        statT := UI.Text(g, "x708 y" (EH - 138) " w328 h18", "", C, 9, Theme.Muted)
        msgB := UI.Box(g, 708, EH - 112, 328, 30, Theme.DangerBg, 8)
        msgI := UI.IconText(g, "x716 y" (EH - 112) " w20 h30", Icon.Warning, Theme.DangerBg, 9, Theme.Danger)
        msgT := UI.Text(g, "x742 y" (EH - 112) " w288 h30 +0x200", "", Theme.DangerBg, 8, Theme.Danger, 600)
        for c in [msgB, msgI, msgT]
            c.Visible := false
        resetB := Btn.Add(g, "x708 y" (EH - 70) " w96 h42", "Сброс", Reset, "ghost", 10, Icon.Undo, C)
        Btn.Add(g, "x812 y" (EH - 70) " w96 h42", "Отмена", Close, "ghost", 10, , C)
        Btn.Add(g, "x916 y" (EH - 70) " w120 h42", "Сохранить", Save, "primary", 10, Icon.Save, C)
        UI.Text(g, "x708 y" (EH - 22) " w328 h16 Center", "Ctrl+S — сохранить   ·   Esc — закрыть", C, 8, Theme.Faint)

        syncFn := Sync
        nameE.OnEvent("Change", Upd)
        textE.OnEvent("Change", Upd)
        delayE.OnEvent("Change", Upd)
        hkF.OnChange := Upd
        catP.OnChange := Upd
        enSw.OnChange := Upd
        g.OnEvent("Close", Close)
        g.OnEvent("Escape", Close)

        if !Editor.HkDone {
            Editor.HkDone := true
            HotIf((*) => Editor.Cur && WinActive("ahk_id " Editor.Cur.g.Hwnd))
            Hotkey("^s", (*) => Editor.Cur.save())
            Hotkey("^Enter", (*) => Editor.Cur.save())
            HotIf()
        }
        Editor.Cur := {g: g, save: Save}

        UI.OpenModal(g, "w" EW " h" EH)
        st.orig := Snap()
        Upd()
        SetTimer(syncFn, 120)
        (isNew ? nameE : textE).Focus()

        Snap() {
            return nameE.Value "|" catP.Value "|" hkF.Value "|" enSw.State "|" delayE.Value "|" StrReplace(textE.Value, "`r")
        }

        Upd(*) {
            tmp := Map("lines", StrReplace(textE.Value, "`r"), "delay", Max(100, Store.Num(delayE.Value, 1300)), "name", nameE.Value, "hotkey", hkF.Value, "enabled", enSw.State, "category", catP.Value, "id", src["id"])
            rv.Set(Preview.Chat(tmp))
            steps := Sender.Plan(tmp)
            statT.Value := Preview.Stat(tmp)
            long := []
            for i, s in steps
                if StrLen(Sender.Resolve(s.text)) > 128
                    long.Push(i)
            if long.Length
                Msg("Сообщ. " Join(long) " длиннее 128 симв. — SAMP может обрезать", "warning")
            else
                Msg("")
            st.dirty := Snap() != st.orig
            dirtyT.Visible := st.dirty
            KeyInfo()
            Sync()
        }

        ; статус клавиши: сразу видно конфликт
        KeyInfo() {
            hk := hkF.Value
            if hk = ""
                return KeySay(Icon.Info, "Не назначена — бинд не сработает в игре", Theme.Muted)
            if Keys.IsSystem(hk)
                return KeySay(Icon.Error, "Занята системной функцией MedBind", Theme.Danger)
            if (who := Store.HotkeyOwner(hk, src["id"])) != ""
                return KeySay(Icon.Error, "Уже у бинда «" who "»", Theme.Danger)
            if RegExMatch(hk, "^[A-Z0-9]$")
                return KeySay(Icon.Warning, "Без Ctrl/Alt/Shift клавиша будет мешать печатать", Theme.Warning)
            KeySay(Icon.Check, "Свободна — можно сохранять", Theme.Success)
        }

        KeySay(glyph, text, color) {
            keyI.Value := glyph
            keyI.SetFont("c" color), keyT.SetFont("c" color)
            keyT.Value := text
            keyI.Redraw(), keyT.Redraw()
        }

        Msg(text, kind := "error") {
            show := text != ""
            for c in [msgB, msgI, msgT]
                c.Visible := show
            if !show
                return
            bg := kind = "error" ? Theme.DangerBg : Theme.WarningBg
            fg := kind = "error" ? Theme.Danger : Theme.Warning
            UI.Paint(msgB, bg), UI.Paint(msgI, bg), UI.Paint(msgT, bg)
            msgI.Value := kind = "error" ? Icon.Error : Icon.Warning
            msgI.SetFont("c" fg), msgT.SetFont("c" fg)
            msgT.Value := text
        }

        ; номера сообщений слева: # — комментарий, ⏱ — пауза
        Sync() {
            try {
                first := SendMessage(0xCE, 0, 0, textE)
                v := textE.Value
            } catch
                return
            key := first "|" v
            if key = st.last
                return
            st.last := key
            lines := StrSplit(StrReplace(v, "`r"), "`n")
            out := "", n := 0
            for i, ln in lines {
                t := Trim(ln)
                if t = ""
                    mark := ""
                else if SubStr(t, 1, 1) = "#"
                    mark := "#"
                else if RegExMatch(t, "i)^{wait")
                    mark := "⏱"
                else
                    mark := ++n
                if i > first
                    out .= mark "`n"
                if i > first + 60
                    break
            }
            gutT.Value := out
        }

        Reset(*) {
            if !st.dirty
                return
            if !Dialogs.Confirm("Сбросить изменения?", "Все поля вернутся к состоянию на момент открытия редактора.", "Сбросить", false, g)
                return
            nameE.Value := src["name"]
            catP.Set(src["category"], false)
            enSw.Set(src["enabled"])
            delayE.Value := src["delay"]
            textE.Value := StrReplace(src["lines"], "`n", "`r`n")
            hkF.Set(src["hotkey"])
            Upd()
        }

        Close(*) {
            if st.dirty && !Dialogs.Confirm("Закрыть без сохранения?", "Изменения в этом бинде будут потеряны.", "Закрыть", true, g)
                return true
            Shut()
            return true
        }

        Shut() {
            SetTimer(syncFn, 0)
            Editor.Cur := 0
            UI.CloseModal(g)
        }

        Save(*) {
            nm := Trim(nameE.Value)
            hk := hkF.Value
            ct := SubStr(Trim(catP.Value), 1, 30)
            if ct = ""
                ct := Store.Data["categories"][1]
            txt := Trim(StrReplace(textE.Value, "`r"), "`n")
            if nm = ""
                return Fail("Введите название бинда", nameE)
            if hk != "" && Keys.IsSystem(hk)
                return Fail("Клавиша " Keys.Pretty(hk) " занята системной функцией")
            if (who := Store.HotkeyOwner(hk, src["id"])) != ""
                return Fail("Клавиша " Keys.Pretty(hk) " уже у бинда «" who "»")
            if !Sender.Plan(Map("lines", txt, "delay", 1000)).Length
                return Fail("Добавьте хотя бы одну строку для отправки", textE)
            src["name"] := nm
            src["hotkey"] := hk
            src["category"] := ct
            src["lines"] := txt
            src["delay"] := Max(100, Store.Num(delayE.Value, 1300))
            src["enabled"] := enSw.State ? 1 : 0
            Store.EnsureCategory(ct)
            if isNew
                Store.Data["binds"].Push(src)
            Store.Save()
            Keys.Apply()
            MainUI.Touch(src["id"])
            Shut()
            MainUI.Refresh()
            MainUI.SelectId(src["id"])
            Toast.Show("«" nm "» сохранён" (hk != "" ? "  ·  " Keys.Pretty(hk) : ""), "Бинд сохранён", , "success")
        }

        Fail(text, focus := 0) {
            Msg(text, "error")
            SoundBeep(300, 120)
            if focus
                focus.Focus()
        }
    }

    static Inserter(edit, text) {
        return (*) => (EditPaste(text, edit), edit.Focus())
    }

    ; номер текущей строки (с 0) и её границы
    static LineAt(edit) {
        ln := SendMessage(0xC9, -1, 0, edit)                 ; EM_LINEFROMCHAR
        start := SendMessage(0xBB, ln, 0, edit)              ; EM_LINEINDEX
        len := SendMessage(0xC1, start, 0, edit)             ; EM_LINELENGTH
        return {ln: ln, start: start, end: start + len}
    }

    ; новая строка после текущей
    static AddLine(edit, text) {
        p := this.LineAt(edit)
        SendMessage(0xB1, p.end, p.end, edit)                ; EM_SETSEL
        EditPaste((edit.Value = "" ? "" : "`r`n") text, edit)
        edit.Focus()
    }

    static AppendToLine(edit, text) {
        p := this.LineAt(edit)
        SendMessage(0xB1, p.end, p.end, edit)
        EditPaste(text, edit)
        edit.Focus()
    }

    static DeleteLine(edit) {
        p := this.LineAt(edit)
        nxt := SendMessage(0xBB, p.ln + 1, 0, edit)
        if nxt = -1 || nxt = 0xFFFFFFFF {             ; последняя строка — забираем перевод строки перед ней
            a := p.start >= 2 ? p.start - 2 : 0
            SendMessage(0xB1, a, p.end, edit)
        } else
            SendMessage(0xB1, p.start, nxt, edit)
        SendMessage(0xC2, 1, StrPtr(""), edit)               ; EM_REPLACESEL (с отменой через Ctrl+Z)
        edit.Focus()
    }
}


; ==================== SettingsUI ====================

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
