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
