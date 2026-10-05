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
    static Bg := "090A10"
    static Side := "0C0D14"
    static Card := "12141D"
    static CardHover := "191A25"
    static CardSel := "20121D"
    static Field := "171923"
    static FieldHover := "20222E"
    static ChatBg := "0B0C12"
    static Gutter := "151620"
    ; линии
    static Line := "282A36"
    static LineHover := "414452"
    static KeyLine := "393B49"
    ; текст
    static Text := "E8EDF4"
    static Soft := "C9C8D3"
    static Muted := "9798A8"
    static Faint := "686A79"
    ; акценты
    static Accent := "F13C79"
    static AccentHover := "FF6394"
    static AccentPress := "D92C67"
    static AccentInk := "FFFFFF"
    static AccentLine := "D93670"
    static AccentSoft := "2A121E"
    static AccentSoftHover := "351522"
    static AccentSoftPress := "411A2B"
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
        wp := Round(w * s), hp := Round(h * s)
        ; Even device-pixel diameters keep left/right corner steps symmetric at 125%/150% DPI.
        d := Min(2 * Round(r * s), Min(wp, hp))
        if d > 0
            try WinSetRegion("0-0 w" wp " h" hp " r" d "-" d, ctrl)
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

    static Text(g, opts, text, bg, size := 10, color := "", weight := 400, font := "", solid := false) {
        g.SetFont("s" size " w" weight " q5 c" (color = "" ? Theme.Text : color), font = "" ? Theme.Font : font)
        back := solid ? " Background" bg : " BackgroundTrans"
        return g.AddText(opts back, text)
    }

    static Label(g, opts, text, bg) {
        return UI.Text(g, opts, text, bg, 8, Theme.Muted, 700)
    }

    static IconText(g, opts, glyph, bg, size := 10, color := "", solid := false) {
        return UI.Text(g, opts " +0x200 Center", glyph, bg, size, color = "" ? Theme.Muted : color, 400, Icon.Font, solid)
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
        b := UI.IconText(g, "x28 y26 w40 h40", glyph, bg, 13, fg, true)
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
        this.Ic := UI.Text(g, "x" p.x " y" p.y " w18 h" p.h " +0x100 +0x200 Center", glyph, bg, size, fg, 400, Icon.Font)
        this.Lb := UI.Text(g, "x" p.x " y" p.y " w" p.w " h" p.h " +0x100 +0x200 Center", label, bg, size, fg, 600)
        this.Parts := [this.Plate, this.Ic, this.Lb]
        this.Hv := PaintHover([this.Plate], bg, hv, pr)
        for c in this.Parts {
            c.OnEvent("Click", ObjBindMethod(this, "Fire"))
            Hover.Add(c, this.Hv, g.Hwnd)
        }
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
        this.Knob := g.AddText("x" (x + 3) " y" (y + 6) " w16 h16 +0x100 BackgroundFFFFFF")
        Theme.Round(this.Knob, 16, 16, 8)
        this.Lbl := UI.Text(g, "x" (x + 52) " y" y " w" (w - 52) " h28 +0x200 +0x100", label, bg, 10, Theme.Soft, 500)
        for c in [this.Track, this.Knob, this.Lbl]
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
        this.I := UI.IconText(g, "x" (x + 12) " y" (y + 1) " w18 h" (h - 2) " +0x100", "", Theme.Field, 10, Theme.Accent)
        this.I.Visible := !!iconFn
        this.T := UI.Text(g, "x" (x + off) " y" (y + 1) " w" (w - off - 34) " h" (h - 2) " +0x200 +0x100", value, Theme.Field, 10, Theme.Text, 500)
        this.A := UI.IconText(g, "x" (x + w - 32) " y" (y + 1) " w24 h" (h - 2) " +0x100", Icon.Down, Theme.Field, 8, Theme.Muted)
        for c in [this.I, this.T, this.A]
            c.OnEvent("Click", ObjBindMethod(this, "Open"))
        hv := {Enter: (*) => UI.Paint(this.Fr.o, Theme.LineHover), Leave: (*) => UI.Paint(this.Fr.o, Theme.Line)}
        for c in [this.I, this.T, this.A]
            Hover.Add(c, hv, g.Hwnd)
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
            c := UI.Text(g, "x" (x + 4 + (i - 1) * bw) " y" (y + 4) " w" bw " h" (h - 8) " +0x200 +0x100 Center", opt, Theme.Field, 10, Theme.Muted, 600, "", true)
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
    static SW := 252          ; ширина боковой навигации
    static PW := 320          ; компактный инспектор
    static PX := 0
    static CX := 0
    static CW := 0
    static LT := 176          ; верх списка карточек
    static STEP := 108
    static CH := 96
    static NavTop := 208
    static NavStep := 46
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
        this.W := Round(Min(1600, ww - 24))
        this.H := Round(Min(1000, wh - 20))
        this.SW := ww >= 1500 ? 276 : 252
        this.PW := ww >= 1500 ? 360 : 320
        this.CX := this.SW + 24
        this.PX := this.W - this.PW - 16
        this.CW := this.PX - 16 - this.CX
        this.NavN := Max(4, Min(10, (this.H - 260 - this.NavTop) // this.NavStep))
        this.CardN := Max(3, (this.H - 60 - this.LT) // this.STEP)
    }

    static Build() {
        Theme.Init()
        this.Layout()
        S := Theme.Side, B := Theme.Bg, C := Theme.Card, W := this.W, H := this.H
        g := Gui("-Resize -MaximizeBox", App.Name " " App.Version)
        g.BackColor := B
        g.MarginX := 0, g.MarginY := 0
        this.G := g

        ; ================= навигация =================
        UI.Box(g, 0, 0, this.SW, H, S, 0)
        UI.Box(g, this.SW, 0, 1, H, Theme.Line, 0)
        this.LogoIcon := UI.IconText(g, "x22 y18 w52 h52", Icon.Cat["health"], B, 22, Theme.Accent)
        UI.Text(g, "x82 y20 w142 h30", "MedBind", S, 20, Theme.Text, 700)
        UI.Text(g, "x228 y31 w35 h17", App.Version, S, 8, Theme.Accent, 700)
        UI.Text(g, "x84 y49 w168 h16", "GTA SAMP RP  ·  MINISTRY OF HEALTH", S, 7, Theme.Muted, 600)

        ; Статус — единая карточка, текст прозрачен и лежит на её поверхности.
        stFr := UI.Frame(g, 14, 92, this.SW - 28, 64, S, 12, Theme.Line, "+0x100")
        stb := stFr.i
        this.StDot := UI.Text(g, "x25 y99 w18 h26 +0x100 +0x200 Center", "●", S, 9, Theme.Success)
        this.StText := UI.Text(g, "x49 y98 w" (this.SW - 92) " h24 +0x100", "", S, 9, Theme.Success, 600)
        this.StVer := UI.Text(g, "x49 y121 w" (this.SW - 92) " h18 +0x100", "v" App.Version, S, 8, Theme.Muted)
        statusHover := PaintHover([stb], S, Theme.CardHover)
        for c in [stb, this.StDot, this.StText, this.StVer] {
            c.OnEvent("Click", (*) => Keys.ToggleEnabled())
            Hover.Add(c, statusHover, g.Hwnd)
        }
        UI.Divider(g, 16, 174, this.SW - 32)
        UI.Text(g, "x22 y183 w190 h16", "КАТЕГОРИИ", S, 8, Theme.Faint, 700)

        loop this.NavN {
            y := this.NavTop + (A_Index - 1) * this.NavStep
            navFr := UI.Frame(g, 10, y, this.SW - 20, 40, S, 11, Theme.Line, "+0x100")
            base := navFr.i
            bar := UI.Box(g, 13, y + 8, 3, 24, Theme.Accent, 2, "+0x100")
            ic := UI.IconText(g, "x24 y" y " w26 h40 +0x100", "", S, 12, Theme.Muted)
            name := UI.Text(g, "x60 y" y " w" (this.SW - 108) " h40 +0x100 +0x200", "", S, 10, Theme.Soft, 500)
            cnt := UI.Text(g, "x" (this.SW - 48) " y" y " w24 h40 +0x100 +0x200 Right", "", S, 9, Theme.Faint, 600)
            this.Navs.Push({plate: base, outline: navFr.o, bar: bar, ic: ic, name: name, cnt: cnt, item: 0})
            navIdx := A_Index
            navHover := SlotHover("nav", navIdx)
            for ctrl in [navFr.o, base, bar, ic, name, cnt] {
                ctrl.OnEvent("Click", this.NavClicker(navIdx))
                this.Hwnds[ctrl.Hwnd] := {t: "nav", i: navIdx}
                Hover.Add(ctrl, navHover, g.Hwnd)
            }
        }
        ya := this.NavTop + this.NavN * this.NavStep + 8
        abFr := UI.Frame(g, 10, ya, this.SW - 20, 38, S, 10, Theme.Line, "+0x100")
        ab := abFr.i
        ai := UI.IconText(g, "x24 y" ya " w26 h38 +0x100", Icon.Add, S, 11, Theme.Muted)
        at := UI.Text(g, "x60 y" ya " w" (this.SW - 82) " h38 +0x100 +0x200", "Добавить категорию", S, 9, Theme.Muted, 500)
        addCategoryHover := PaintHover([ab], S, Theme.CardHover)
        for c in [abFr.o, ab, ai, at] {
            c.OnEvent("Click", (*) => MainUI.NewCategory())
            Hover.Add(c, addCategoryHover, g.Hwnd)
        }

        ; Профиль, настройки и короткая подпись внизу панели.
        UI.Divider(g, 16, H - 150, this.SW - 32)
        pfFr := UI.Frame(g, 10, H - 140, this.SW - 20, 64, S, 12, Theme.Line, "+0x100")
        pf := pfFr.i
        this.Avatar := UI.Text(g, "x20 y" (H - 132) " w42 h42 +0x100 +0x200 Center", "?", Theme.AccentSoft, 11, Theme.Accent, 700, "", true)
        Theme.Round(this.Avatar, 42, 42, 21)
        this.ProfName := UI.Text(g, "x72 y" (H - 134) " w" (this.SW - 112) " h20", "", S, 10, Theme.Text, 600)
        this.ProfInfo := UI.Text(g, "x72 y" (H - 114) " w" (this.SW - 112) " h17", "", S, 8, Theme.Muted)
        this.ProfId := UI.Text(g, "x72 y" (H - 98) " w" (this.SW - 112) " h14", "", S, 7, Theme.Faint)
        pch := UI.IconText(g, "x" (this.SW - 38) " y" (H - 126) " w20 h38 +0x100 +0x200", Icon.ChevR, S, 9, Theme.Faint)
        profileHover := PaintHover([pf], S, Theme.CardHover)
        for c in [pfFr.o, pf, this.Avatar, this.ProfName, this.ProfInfo, this.ProfId, pch] {
            c.OnEvent("Click", (*) => SettingsUI.Open())
            Hover.Add(c, profileHover, g.Hwnd)
        }

        srFr := UI.Frame(g, 10, H - 64, this.SW - 20, 42, S, 11, Theme.Line, "+0x100")
        sr := srFr.i
        si := UI.IconText(g, "x22 y" (H - 64) " w24 h42 +0x100", Icon.Settings, S, 12, Theme.Muted)
        stt := UI.Text(g, "x58 y" (H - 64) " w" (this.SW - 84) " h42 +0x100 +0x200", "Настройки", S, 10, Theme.Soft, 500)
        settingsHover := PaintHover([sr], S, Theme.CardHover)
        for c in [srFr.o, sr, si, stt] {
            c.OnEvent("Click", (*) => SettingsUI.Open())
            Hover.Add(c, settingsHover, g.Hwnd)
        }
        UI.Text(g, "x18 y" (H - 18) " w196 h12", "С ЗАБОТОЙ О ВАШЕМ RP", S, 6, Theme.Faint, 700)
        UI.IconText(g, "x" (this.SW - 43) " y" (H - 22) " w22 h18", Icon.Cat["heart"], S, 10, Theme.Accent)

        ; ================= заголовок и действия =================
        CX := this.CX, CW := this.CW
        searchX := CX + 254
        this.HeaderTextW := Max(120, searchX - (CX + 58) - 14)
        this.TitleI := UI.IconText(g, "x" CX " y89 w46 h46", "", B, 20, Theme.Accent)
        this.TitleT := UI.Text(g, "x" (CX + 58) " y89 w" this.HeaderTextW " h28", "", B, 18, Theme.Text, 700)
        this.CountT := UI.Text(g, "x" (CX + 58) " y118 w" this.HeaderTextW " h18", "", B, 9, Theme.Muted)

        ; Статус игры, настройки и системные действия остаются доступны сверху.
        gcw := 210
        gcx := W - 16 - 38 - gcw
        this.GameHit := UI.Box(g, gcx, 8, gcw, 56, B, 0, "+0x100")
        this.GameDot := UI.Text(g, "x" gcx " y8 w18 h50 +0x100 +0x200 Center", "●", B, 8, Theme.Faint)
        this.GameName := UI.Text(g, "x" (gcx + 22) " y12 w" (gcw - 28) " h20 +0x100", "", B, 9, Theme.Text, 600)
        this.GameSt := UI.Text(g, "x" (gcx + 22) " y32 w" (gcw - 28) " h18 +0x100", "", B, 8, Theme.Muted)
        this.GameGear := UI.IconText(g, "x" (W - 48) " y10 w30 h42 +0x100", Icon.Settings, B, 13, Theme.Soft)
        for c in [this.GameHit, this.GameDot, this.GameName, this.GameSt, this.GameGear]
            c.OnEvent("Click", (*) => SettingsUI.Open())

        ty := 90
        createW := 156
        createX := W - 16 - createW
        Btn.Add(g, "x" createX " y" ty " w" createW " h46", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "primary", 9, Icon.Add)
        switchW := 124
        switchX := createX - switchW - 14
        this.EnableSw := SwitchCtl(g, switchX, ty + 9, switchW, "Биндер", Keys.Enabled, B, Theme.Accent)
        this.EnableSw.Lbl.SetFont("s8 w500 c" Theme.Soft, Theme.Font)
        this.EnableSw.OnChange := (*) => Keys.ToggleEnabled()
        impW := 112
        impX := switchX - impW - 14
        Btn.Add(g, "x" impX " y" ty " w" impW " h46", "Импорт", (*) => Share.ImportDialog(), "ghost", 9, Icon.Import)

        swd := impX - 12 - searchX
        sf := UI.Frame(g, searchX, ty, swd, 46, Theme.Field, 12)
        UI.IconText(g, "x" (searchX + 14) " y" (ty + 3) " w26 h40", Icon.Search, Theme.Field, 11, Theme.Muted)
        g.SetFont("s9 w400 q5 c" Theme.Text, Theme.Font)
        this.SearchE := g.AddEdit("x" (searchX + 48) " y" (ty + 13) " w" (swd - 142) " r1 -E0x200 -Multi Background" Theme.Field)
        Theme.DarkCtrl(this.SearchE)
        UI.Cue(this.SearchE, "Поиск по названию, содержимому или горячей клавише...")
        UI.FocusRing(this.SearchE, sf.o)
        hint := UI.Text(g, "x" (searchX + swd - 86) " y" (ty + 14) " w40 h18 +0x200 Center", "Ctrl+K", Theme.Field, 7, Theme.Faint, 600)
        this.SearchX := UI.IconText(g, "x" (searchX + swd - 38) " y" (ty + 5) " w28 h36 +0x100", Icon.Cancel, Theme.Field, 8, Theme.Muted)
        this.SearchX.OnEvent("Click", (*) => MainUI.ClearSearch())
        this.SearchX.Visible := false
        this.SearchE.OnEvent("Change", (*) => (MainUI.Offset := 0, MainUI.Refresh()))

        ; ================= карточки =================
        cardTextX := CX + 82
        cardMenuX := CX + CW - 32
        cardCheckX := cardMenuX - 36
        cardCountX := cardCheckX - 84
        cardStatusX := cardCountX - 98
        cardKeyX := cardStatusX - 82
        cardTextW := Max(180, cardKeyX - 12 - cardTextX)
        loop this.CardN {
            slotIdx := A_Index
            y := this.LT + (slotIdx - 1) * this.STEP
            fr := UI.Frame(g, CX, y, CW, this.CH, C, 14, Theme.Line, "+0x100")
            selBar := UI.Box(g, CX + 1, y + 16, 3, this.CH - 32, Theme.Accent, 2, "+0x100")
            selBar.Visible := false
            tile := UI.Box(g, CX + 14, y + 18, 58, 60, Theme.AccentSoft, 14)
            plate := UI.IconText(g, "x" (CX + 14) " y" (y + 18) " w58 h60", "", Theme.AccentSoft, 20, Theme.Accent)
            title := UI.Text(g, "x" cardTextX " y" (y + 10) " w" cardTextW " h22 +0x100", "", C, 11, Theme.Text, 650)
            sub1 := UI.Text(g, "x" cardTextX " y" (y + 35) " w" cardTextW " h17 +0x100", "", C, 9, Theme.Soft)
            sub2 := UI.Text(g, "x" cardTextX " y" (y + 52) " w" cardTextW " h17 +0x100", "", C, 9, Theme.Muted)
            catIc := UI.IconText(g, "x" cardTextX " y" (y + 75) " w16 h16", Icon.Folder, C, 8, Theme.Muted)
            cat := UI.Text(g, "x" (cardTextX + 21) " y" (y + 73) " w" (cardTextW - 21) " h18 +0x100", "", C, 8, Theme.Muted, 500)

            keyf := UI.Frame(g, cardKeyX, y + 31, 58, 34, Theme.Field, 10, Theme.KeyLine)
            key := UI.Text(g, "x" cardKeyX " y" (y + 31) " w58 h34 +0x100 +0x200 Center", "", Theme.Field, 8, Theme.Text, 700, Theme.Mono)
            statusBg := UI.Box(g, cardStatusX, y + 34, 88, 28, Theme.SuccessBg, 10)
            statusDot := UI.Text(g, "x" (cardStatusX + 5) " y" (y + 34) " w14 h28 +0x200 Center", "●", Theme.SuccessBg, 8, Theme.Success)
            status := UI.Text(g, "x" (cardStatusX + 21) " y" (y + 34) " w62 h28 +0x200", "Активен", Theme.SuccessBg, 8, Theme.Success, 600)
            countBg := UI.Box(g, cardCountX, y + 34, 72, 28, Theme.Field, 9)
            countIc := UI.IconText(g, "x" (cardCountX + 5) " y" (y + 34) " w16 h28", Icon.Clock, Theme.Field, 8, Theme.Muted)
            cnt := UI.Text(g, "x" (cardCountX + 22) " y" (y + 34) " w46 h28 +0x200 Right", "", Theme.Field, 8, Theme.Soft, 500)
            checkBg := UI.Box(g, cardCheckX, y + 35, 26, 26, Theme.Accent, 8, "+0x100")
            chk := UI.IconText(g, "x" cardCheckX " y" (y + 35) " w26 h26 +0x100", Icon.Check, Theme.Accent, 9, Theme.AccentInk)
            keb := UI.IconText(g, "x" cardMenuX " y" (y + 31) " w28 h32 +0x100", Icon.More, C, 12, Theme.Muted)
            this.Cards.Push({fr: fr, tile: tile, selBar: selBar, plate: plate, title: title, keyf: keyf, key: key, catIc: catIc, cat: cat, sub1: sub1, sub2: sub2, statusBg: statusBg, statusDot: statusDot, status: status, countBg: countBg, countIc: countIc, cnt: cnt, checkBg: checkBg, chk: chk, keb: keb, textW: cardTextW, keyX: cardKeyX, id: "", enabled: true})

            cardHover := SlotHover("card", slotIdx)
            for ctrl in [fr.o, fr.i, tile, plate, title, sub1, sub2, catIc, cat, keyf.o, keyf.i, key, statusBg, statusDot, status, countBg, countIc, cnt, keb] {
                ctrl.OnEvent("Click", this.CardClicker(slotIdx))
                ctrl.OnEvent("DoubleClick", this.CardOpener(slotIdx))
                this.Hwnds[ctrl.Hwnd] := {t: "card", i: slotIdx}
                Hover.Add(ctrl, cardHover, g.Hwnd)
            }
            for ctrl in [checkBg, chk] {
                ctrl.OnEvent("Click", this.ToggleCardClicker(slotIdx))
                this.Hwnds[ctrl.Hwnd] := {t: "card", i: slotIdx}
            }
            keb.OnEvent("Click", this.KebClicker(slotIdx))
        }

        ; пустое состояние списка
        e := this.E
        e.fr := UI.Frame(g, CX, this.LT, CW, 104, C, 14)
        e.ic := UI.IconText(g, "x" (CX + 18) " y" (this.LT + 26) " w48 h48", Icon.Search, Theme.AccentSoft, 15, Theme.Accent, true)
        e.t := UI.Text(g, "x" (CX + 82) " y" (this.LT + 23) " w" (CW - 285) " h24", "", C, 12, Theme.Text, 700)
        e.s := UI.Text(g, "x" (CX + 82) " y" (this.LT + 49) " w" (CW - 285) " h34", "", C, 9, Theme.Muted)
        e.b := Btn.Add(g, "x" (CX + CW - 164) " y" (this.LT + 31) " w144 h42", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "ghost", 9, Icon.Add, C)

        ; ================= пагинация =================
        py := H - 46
        Mk(x, glyph) {
            s := UI.Box(g, x, py, 28, 28, Theme.Field, 8, "+0x100")
            t := UI.IconText(g, "x" x " y" py " w28 h28 +0x100 +0x200", glyph, Theme.Field, 8, Theme.Muted)
            return {s: s, t: t, page: 0}
        }
        this.PgPrev := Mk(CX, Icon.ChevL)
        for c in [this.PgPrev.s, this.PgPrev.t]
            c.OnEvent("Click", (*) => MainUI.PageBy(-1))
        loop 7 {
            s := UI.Box(g, CX, py, 28, 28, Theme.Field, 8, "+0x100")
            t := UI.Text(g, "x" CX " y" py " w28 h28 +0x100 +0x200 Center", "", Theme.Field, 9, Theme.Muted, 600)
            slot := {s: s, t: t, page: 0}
            slotIdx := A_Index
            for c in [s, t]
                c.OnEvent("Click", this.Pager(slotIdx))
            this.PgSlots.Push(slot)
        }
        this.PgNext := Mk(CX, Icon.ChevR)
        for c in [this.PgNext.s, this.PgNext.t]
            c.OnEvent("Click", (*) => MainUI.PageBy(1))
        this.PgInfo := UI.Text(g, "x" CX " y" py " w" CW " h28 +0x200 Right", "", B, 8, Theme.Faint)

        ; ================= правая панель / инспектор =================
        PX := this.PX, PW := this.PW
        px := PX + 18, pw := PW - 36
        UI.Frame(g, PX, 172, PW, H - 188, C, 18, Theme.Line)
        d := this.D
        d.px := px, d.pw := pw
        d.yMain := H - 70
        d.ySecondary := H - 116
        d.yMeta := H - 160
        d.pvY := 378
        pvH := Max(104, d.yMeta - 16 - d.pvY)

        d.ic := UI.IconText(g, "x" px " y190 w42 h42", "", C, 17, Theme.Accent)
        d.name := UI.Text(g, "x" (px + 54) " y195 w" (pw - 88) " h28", "", C, 13, Theme.Text, 700)
        d.keb := UI.IconText(g, "x" (px + pw - 28) " y190 w28 h32 +0x100", Icon.More, C, 12, Theme.Muted)
        d.keb.OnEvent("Click", (*) => MainUI.DetailMenu())

        d.keyf := UI.Frame(g, px, 237, 74, 28, Theme.Field, 9, Theme.KeyLine)
        d.key := UI.Text(g, "x" px " y237 w74 h28 +0x200 Center", "", Theme.Field, 8, Theme.Text, 700, Theme.Mono)
        d.st := UI.Text(g, "x" (px + 86) " y237 w82 h28", "", C, 8, Theme.Success, 600)
        d.cat := UI.Text(g, "x" (px + 174) " y237 w" (pw - 174) " h28", "", C, 8, Theme.Accent, 600)

        d.dlbl := UI.Text(g, "x" px " y282 w" pw " h14", "ОПИСАНИЕ", C, 8, Theme.Muted, 700)
        d.desc := UI.Text(g, "x" px " y300 w" pw " h46", "", C, 9, Theme.Soft)
        d.plbl := UI.Text(g, "x" px " y356 w" pw " h16", "ПРЕДПРОСМОТР ЧАТА", C, 8, Theme.Muted, 700)
        d.pbox := UI.Box(g, px, d.pvY, pw, pvH, Theme.ChatBg, 12)
        d.rv := RichView(g, px + 10, d.pvY + 10, pw - 20, pvH - 20, Theme.ChatBg)
        d.meta := UI.Text(g, "x" px " y" d.yMeta " w" pw " h20", "", C, 8, Theme.Muted)
        d.hint := UI.Text(g, "x" px " y282 w" pw " h48", "", C, 9, Theme.Muted)

        d.main := Btn.Add(g, "x" px " y" d.yMain " w" pw " h42", "Редактировать", (*) => MainUI.EditSelected(), "primary", 9, Icon.Edit, C)
        actionGap := 8
        actionW := (pw - actionGap * 2) // 3
        d.b1 := Btn.Add(g, "x" px " y" d.ySecondary " w" actionW " h32", "Дублировать", (*) => MainUI.DuplicateSelected(), "ghost", 8, Icon.Copy, C)
        d.b2 := Btn.Add(g, "x" (px + actionW + actionGap) " y" d.ySecondary " w" actionW " h32", "Поделиться", (*) => MainUI.ShareSelected(), "ghost", 8, Icon.Share, C)
        d.b3 := Btn.Add(g, "x" (px + (actionW + actionGap) * 2) " y" d.ySecondary " w" actionW " h32", "Удалить", (*) => MainUI.DeleteSelected(), "danger", 8, Icon.Delete, C)

        ; Пустое состояние в стиле примера: быстрый старт, метаданные и подпись.
        d.emptyIcon := UI.IconText(g, "x" (px + (pw - 64) // 2) " y198 w64 h64", Icon.Cat["health"], Theme.AccentSoft, 23, Theme.Accent, true)
        Theme.Round(d.emptyIcon, 64, 64, 32)
        d.emptyTitle := UI.Text(g, "x" (px + 8) " y273 w" (pw - 16) " h26 +0x200 Center", "Выберите бинд", C, 13, Theme.Text, 700)
        d.emptyHint := UI.Text(g, "x" (px + 16) " y304 w" (pw - 32) " h38 +0x200 Center", "Кликните на бинд из списка, чтобы увидеть его содержание и отредактировать.", C, 8, Theme.Muted)

        d.quickFr := UI.Frame(g, px, 352, pw, 74, Theme.Bg, 13, Theme.Line, "+0x100")
        d.quickIcon := UI.IconText(g, "x" (px + 12) " y368 w42 h42", Icon.Cat["bolt"], Theme.AccentSoft, 14, Theme.Accent, true)
        Theme.Round(d.quickIcon, 42, 42, 21)
        d.quickTitle := UI.Text(g, "x" (px + 68) " y360 w" (pw - 84) " h20", "Быстрое создание", Theme.Bg, 9, Theme.Text, 600)
        d.quickText := UI.Text(g, "x" (px + 68) " y381 w" (pw - 84) " h34", "Используйте кнопку «Создать бинд» для добавления нового.", Theme.Bg, 8, Theme.Muted)
        d.quickHover := PaintHover([d.quickFr.i], Theme.Bg, Theme.FieldHover)
        for c in [d.quickFr.o, d.quickFr.i, d.quickIcon, d.quickTitle, d.quickText] {
            c.OnEvent("Click", (*) => Editor.Open("", MainUI.CurCat))
            Hover.Add(c, d.quickHover, g.Hwnd)
        }
        d.emptyLabel := UI.Text(g, "x" px " y440 w" pw " h16", "ИНФОРМАЦИЯ О БИНДЕ", C, 8, Theme.Faint, 700)
        d.emptyRows := []
        info := [
            {glyph: Icon.Folder, label: "Категория"},
            {glyph: Icon.Keyboard, label: "Горячая клавиша"},
            {glyph: Icon.Clock, label: "Статус"},
            {glyph: Icon.Doc, label: "Строки"},
            {glyph: Icon.Cat["bolt"], label: "Тип статистики"}
        ]
        loop info.Length {
            item := info[A_Index]
            ry := 458 + (A_Index - 1) * 30
            ric := UI.IconText(g, "x" px " y" ry " w20 h28", item.glyph, C, 9, Theme.Muted)
            rl := UI.Text(g, "x" (px + 28) " y" ry " w" (pw - 132) " h28", item.label, C, 8, Theme.Muted)
            rv := UI.Text(g, "x" (px + pw - 100) " y" ry " w100 h28 +0x200 Right", "—", C, 8, Theme.Text, 600)
            sep := UI.Divider(g, px + 28, ry + 29, pw - 28)
            d.emptyRows.Push({ic: ric, label: rl, value: rv, sep: sep})
        }
        d.footer := UI.Text(g, "x" (px + 10) " y" (H - 86) " w" (pw - 20) " h34 +0x200 Center", "« Хороший медик`nвсегда рядом. »", C, 10, Theme.Accent, 600)
        d.footerLeft := UI.Divider(g, px + 46, H - 27, 42)
        d.footerIcon := UI.IconText(g, "x" (px + (pw - 24) // 2) " y" (H - 41) " w24 h20", Icon.Cat["heart"], C, 12, Theme.Accent)
        d.footerRight := UI.Divider(g, px + pw - 88, H - 27, 42)

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
    static ToggleCardClicker(i) {
        return (*) => MainUI.FlipCard(i)
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
        this.StDot.SetFont("c" (on ? Theme.Success : Theme.Faint))
        this.StText.SetFont("c" (on ? Theme.Success : Theme.Faint))
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
        this.GameName.Value := InStr(exe, "gta_sa") ? "GTA SAMP RP" : this.FitText(exe, 140, 9, 600)
        gameRunning := false
        try gameRunning := WinExist("ahk_exe " exe) != 0
        this.GameDot.SetFont("c" (gameRunning ? Theme.Success : Theme.Faint))
        this.GameSt.SetFont("c" (gameRunning ? Theme.Success : Theme.Muted))
        this.GameSt.Value := gameRunning ? "Игра запущена" : "Не в игре · настройки"
        for c in [this.GameDot, this.GameName, this.GameSt]
            c.Redraw()
    }

    static UpdateProfile() {
        if !this.G
            return
        p := Store.Data["profile"]
        nick := String(p["nick"])
        this.ProfName.Value := this.FitText(nick != "" ? StrReplace(nick, "_", " ") : "Укажите ник", this.SW - 112, 9, 600)
        this.ProfInfo.Value := this.FitText(p["rank"] != "" ? p["rank"] : "профиль не заполнен", this.SW - 112, 8, 400)
        this.ProfId.Value := this.FitText(p["id"] != "" ? "ID: " p["id"] : "ID не указан", this.SW - 112, 7, 400)
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

        this.TitleT.Value := this.FitText(this.CurCat = "" ? "Все бинды" : this.CurCat, this.HeaderTextW, 18, 700)
        this.TitleI.Value := this.CurCat = "" ? Icon.Home : Icon.ForCat(this.CurCat)
        n := this.Rows.Length
        if q != ""
            countText := "Найдено " n " " this.Plural(n, "бинд", "бинда", "биндов") " по запросу «" Trim(this.SearchE.Value) "»"
        else {
            k := this.Sel.Count
            countText := n " " this.Plural(n, "бинд", "бинда", "биндов") (k ? "  ·  " k " выбрано" : "")
        }
        this.CountT.Value := this.FitText(countText, this.HeaderTextW, 9, 400)
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
            for k in ["plate", "outline", "ic", "name", "cnt"]
                nav.%k%.Visible := show
            if !show {
                nav.item := 0, nav.bar.Visible := false
                continue
            }
            it := this.NavItems[idx]
            nav.item := it
            nav.ic.Value := it.glyph
            nav.name.Value := this.FitText(it.label, this.SW - 108, 10, 500)
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
        bg := on ? Theme.AccentSoft : hv ? Theme.CardHover : Theme.Side
        edge := on ? Theme.AccentLine : hv ? Theme.LineHover : Theme.Line
        UI.Paint(nav.outline, edge)
        UI.Paint(nav.plate, bg)
        nav.bar.Visible := on
        nav.ic.SetFont("c" (on ? Theme.Accent : hv ? Theme.Soft : Theme.Muted))
        nav.name.SetFont((on ? "w600 c" Theme.Text : "w500 c" (hv ? Theme.Text : Theme.Soft)))
        nav.cnt.SetFont("c" (on ? Theme.Accent : Theme.Faint))
        for c in [nav.ic, nav.name, nav.cnt]
            c.Redraw()
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

    static FitText(text, width, size := 9, weight := 400, font := "") {
        text := Trim(String(text))
        if text = "" || width <= 0
            return ""
        if UI.TextW(text, size, weight, font) <= width
            return text
        while StrLen(text) && UI.TextW(text "…", size, weight, font) > width {
            if RegExMatch(text, "s)^(.*)\s+\S+$", &m) && m[1] != ""
                text := RTrim(m[1])
            else
                text := SubStr(text, 1, -1)
        }
        return text = "" ? "…" : RTrim(text) "…"
    }

    static RenderCards() {
        maxOff := Max(0, this.Rows.Length - this.CardN)
        this.Offset := Min(Max(this.Offset, 0), maxOff)
        parts := ["tile", "plate", "title", "key", "catIc", "cat", "sub1", "sub2", "statusBg", "statusDot", "status", "countBg", "countIc", "cnt", "checkBg", "chk", "keb", "selBar"]
        loop this.CardN {
            card := this.Cards[A_Index]
            idx := this.Offset + A_Index
            show := idx <= this.Rows.Length
            card.fr.o.Visible := show, card.fr.i.Visible := show
            card.keyf.o.Visible := show, card.keyf.i.Visible := show
            for k in parts
                card.%k%.Visible := show
            if !show {
                card.id := ""
                continue
            }
            b := Store.Find(this.Rows[idx])
            card.id := b["id"]
            steps := Sender.Plan(b)
            lines := this.FirstLines(b, 2)
            y := this.LT + (A_Index - 1) * this.STEP
            l1 := lines.Length ? lines[1] : "Нет строк для отправки"
            l2 := lines.Length > 1 ? lines[2] : ""

            card.plate.Value := Icon.ForCat(b["category"])
            card.title.Value := this.FitText(b["name"], card.textW, 11, 650)
            card.sub1.Value := this.FitText(l1, card.textW, 9, 400)
            card.sub1.SetFont("c" (SubStr(l1, 1, 3) = "/me" ? Theme.Accent : Theme.Soft))
            card.sub2.Value := this.FitText(l2, card.textW, 9, 400)
            card.cat.Value := this.FitText(b["category"], card.textW - 21, 8, 500)

            kt := b["hotkey"] != "" ? StrReplace(Keys.Pretty(b["hotkey"]), " + ", "+") : "—"
            kw := Min(72, Max(40, UI.TextW(kt, 8, 700, Theme.Mono) + 14))
            card.key.Value := this.FitText(kt, kw - 8, 8, 700, Theme.Mono)
            card.key.SetFont("s8 c" (b["hotkey"] = "" ? Theme.Faint : Theme.Text), Theme.Mono)
            this.MoveKeyBadge(card, card.keyX, kw, y)

            n := steps.Length
            card.cnt.Value := n " " this.Plural(n, "строка", "строки", "строк")
            card.enabled := !!b["enabled"]
            card.status.Value := card.enabled ? "Активен" : "Выключен"
            card.status.SetFont("c" (card.enabled ? Theme.Success : Theme.Muted))
            card.chk.Value := card.enabled ? Icon.Check : Icon.Cancel
            card.chk.SetFont("c" (card.enabled ? Theme.AccentInk : Theme.Muted), Icon.Font)
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
                e.t.Value := this.CurCat = "" ? "Здесь пока пусто" : "В «" (this.FitText(this.CurCat, this.CW - 300, 11, 700)) "» пока нет биндов"
                e.s.Value := "Создайте первый бинд или импортируйте код MEDBIND от другого игрока."
                e.b.Set("Создать бинд", Icon.Add, (*) => Editor.Open("", MainUI.CurCat))
            }
        }
        this.RenderPager()
    }

    static MoveKeyBadge(card, kx, kw, y) {
        card.keyf.o.Move(kx, y + 31, kw, 34)
        card.keyf.i.Move(kx + 1, y + 1 + 31, kw - 2, 32)
        Theme.Round(card.keyf.o, kw, 34, 10)
        Theme.Round(card.keyf.i, kw - 2, 32, 9)
        card.key.Move(kx, y + 31, kw, 34)
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
        infoX := x + total + 12
        infoW := Max(1, this.CX + this.CW - infoX)
        this.PgInfo.Move(infoX, this.H - 46, infoW, 28)
        this.PgInfo.Visible := n > 0 && infoW >= 70
        this.PgInfo.Value := n ? this.FitText("Показано " (to - from + 1) " из " n " биндов", infoW, 8, 400) : ""
    }

    static PaintCard(i) {
        card := this.Cards[i]
        if card.id = ""
            return
        sel := this.Sel.Has(card.id)
        hv := this.HoverCard = i
        bg := sel ? Theme.CardSel : hv ? Theme.CardHover : Theme.Card
        edge := sel ? Theme.AccentLine : hv ? Theme.LineHover : Theme.Line
        UI.Paint(card.fr.o, edge)
        UI.Paint(card.fr.i, bg)
        card.selBar.Visible := sel
        if sel
            card.selBar.Redraw()
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

    static StatType(b) {
        lines := this.FirstLines(b, 1)
        if !lines.Length
            return "—"
        if RegExMatch(lines[1], "i)^/(do|me)\b", &m)
            return "/" StrLower(m[1])
        return "Текст"
    }

    ; правая панель: пустое состояние / один бинд / несколько
    static UpdateDetail() {
        d := this.D
        ids := this.SelectedIds()
        one := ids.Length = 1
        multi := ids.Length > 1
        selected := one || multi

        for c in [d.ic, d.name, d.keb]
            c.Visible := selected
        for c in [d.keyf.o, d.keyf.i, d.key, d.st, d.cat, d.dlbl, d.desc, d.meta]
            c.Visible := one
        d.hint.Visible := multi
        d.plbl.Visible := selected
        d.pbox.Visible := selected
        d.rv.Visible := selected
        for c in [d.emptyIcon, d.emptyTitle, d.emptyHint, d.emptyLabel, d.quickFr.o, d.quickFr.i, d.quickIcon, d.quickTitle, d.quickText, d.footer, d.footerIcon, d.footerLeft, d.footerRight]
            c.Visible := !selected
        d.main.Show(selected), d.b1.Show(selected), d.b2.Show(selected), d.b3.Show(selected)
        for row in d.emptyRows
            for c in [row.ic, row.label, row.value, row.sep]
                c.Visible := !selected

        if !selected {
            d.emptyTitle.Value := "Выберите бинд"
            d.emptyHint.Value := "Кликните на бинд из списка, чтобы увидеть его содержание и отредактировать."
            sample := this.Rows.Length ? Store.Find(this.Rows[1]) : 0
            if sample {
                steps := Sender.Plan(sample)
                values := [sample["category"], sample["hotkey"] != "" ? Keys.Pretty(sample["hotkey"]) : "—", sample["enabled"] ? "Активен" : "Выключен", steps.Length, this.StatType(sample)]
            } else {
                values := ["—", "—", "—", "—", "—"]
            }
            for i, row in d.emptyRows
                row.value.Value := this.FitText(values[i], 96, 8, 600)
            return
        }
        if multi {
            d.ic.Value := Icon.All
            d.name.Value := this.FitText(ids.Length " выбрано", d.pw - 92, 13, 700)
            d.hint.Value := "Ctrl + клик — изменить выбор  ·  Shift + клик — диапазон  ·  Esc — снять выбор"
            d.plbl.Value := "СПИСОК ВЫБРАННОГО"
            d.rv.Set(Preview.List(ids))
            d.main.Set("Поделиться (" ids.Length ")", Icon.Share, (*) => MainUI.ShareSelected())
            d.b1.Set("Перенести", Icon.Move, (*) => MainUI.MoveMenu())
            d.b2.Set("Вкл / выкл", Icon.Power, (*) => MainUI.ToggleSelected())
            d.b3.Set("Удалить", Icon.Delete, (*) => MainUI.DeleteSelected())
            return
        }

        b := Store.Find(ids[1])
        px := d.px, pw := d.pw
        d.ic.Value := Icon.ForCat(b["category"])
        d.name.Value := this.FitText(b["name"], pw - 92, 13, 700)

        kt := b["hotkey"] != "" ? StrReplace(Keys.Pretty(b["hotkey"]), " + ", "+") : "без клавиши"
        kw := Min(90, Max(50, UI.TextW(kt, 8, 700, Theme.Mono) + 16))
        d.keyf.o.Move(px, 237, kw, 28)
        d.keyf.i.Move(px + 1, 238, kw - 2, 26)
        Theme.Round(d.keyf.o, kw, 28, 9)
        Theme.Round(d.keyf.i, kw - 2, 26, 8)
        d.key.Move(px, 237, kw, 28)
        d.key.Value := this.FitText(kt, kw - 8, 8, 700, Theme.Mono)
        d.key.SetFont("s8 c" (b["hotkey"] = "" ? Theme.Faint : Theme.Text), Theme.Mono)

        enabled := !!b["enabled"]
        d.st.Value := enabled ? "● Активен" : "○ Выключен"
        d.st.SetFont("c" (enabled ? Theme.Success : Theme.Muted))
        d.st.Move(px + kw + 12, 237, 82, 28)
        catX := px + kw + 102
        catW := Max(24, pw - kw - 102)
        d.cat.Value := "• " this.FitText(b["category"], catW - 10, 8, 600)
        d.cat.Move(catX, 237, catW, 28)
        d.cat.SetFont("c" Theme.Accent)

        lines := this.FirstLines(b, 2)
        desc := ""
        for line in lines
            desc .= (desc != "" ? "`n" : "") this.FitText(line, pw, 9, 400)
        d.desc.Value := desc != "" ? desc : "Описания нет — добавьте строки в редакторе."
        d.plbl.Value := "ПРЕДПРОСМОТР ЧАТА"
        d.rv.Set(Preview.Chat(b))

        steps := Sender.Plan(b)
        delayText := Format("{:.1f}", Store.Num(b["delay"], 1300) / 1000) " с"
        metaText := Preview.Msgs(steps.Length) "   ·   " b["category"] "   ·   " delayText "   ·   " this.When(b["id"])
        d.meta.Value := this.FitText(metaText, pw, 8, 400)

        d.main.Set("Редактировать", Icon.Edit, (*) => MainUI.EditSelected())
        d.b1.Set("Дублировать", Icon.Copy, (*) => MainUI.DuplicateSelected())
        d.b2.Set("Поделиться", Icon.Share, (*) => MainUI.ShareSelected())
        d.b3.Set("Удалить", Icon.Delete, (*) => MainUI.DeleteSelected())
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

    static FlipCard(i) {
        id := this.Cards[i].id
        if id = ""
            return
        if b := Store.Find(id)
            this.OnCardSwitch(i, !b["enabled"])
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
        hi := UI.IconText(g, "x32 y24 w40 h40", isNew ? Icon.Add : Icon.Edit, Theme.AccentSoft, 13, Theme.Accent, true)
        Theme.Round(hi, 40, 40, 12)
        UI.Text(g, "x86 y22 w420 h26", isNew ? "Новый бинд" : "Редактирование", B, 14, Theme.Text, 700)
        UI.Text(g, "x86 y48 w420 h18", "Каждая строка текста уходит в чат отдельным сообщением", B, 9, Theme.Muted)
        dirtyT := UI.Text(g, "x520 y30 w132 h22 +0x200 Center", "●  ИЗМЕНЕНО", Theme.WarningBg, 8, Theme.Warning, 700, "", true)
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
