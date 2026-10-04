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
