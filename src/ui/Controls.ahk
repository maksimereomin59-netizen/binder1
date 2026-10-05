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
