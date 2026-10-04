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
