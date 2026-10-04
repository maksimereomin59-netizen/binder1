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
                col := RegExMatch(m[1], Preview.RpCmd) ? 6 : 5
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
