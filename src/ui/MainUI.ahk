; ============================================================
;  Главное окно: сайдбар · шапка · список карточек · правая панель
;  Композиция рассчитана на 1366×768 … 1920×1080 и выше
; ============================================================
class MainUI {
    static G := 0
    static W := 1200
    static H := 700
    static SW := 220          ; компактная навигация
    static PW := 300          ; правая панель не забирает ширину у списка
    static PX := 0
    static CX := 0
    static CW := 0
    static LT := 126          ; верх списка карточек
    static STEP := 74
    static CH := 68
    static NavTop := 136
    static NavStep := 31
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
        this.PW := this.W >= 1180 ? 300 : 276
        this.CX := this.SW + 24
        this.PX := this.W - this.PW - 16
        this.CW := this.PX - 16 - this.CX
        this.NavN := Max(4, Min(10, (this.H - 320) // this.NavStep))
        this.CardN := Max(3, (this.H - 56 - this.LT) // this.STEP)
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
        this.LogoIcon := UI.IconText(g, "x16 y16 w38 h38", Icon.Cat["health"], Theme.AccentSoft, 15, Theme.Accent)
        Theme.Round(this.LogoIcon, 38, 38, 12)
        UI.Text(g, "x64 y17 w140 h22", "MedBind", S, 14, Theme.Text, 700)
        UI.Text(g, "x65 y39 w138 h14", "DOCTOR BINDER  ·  " App.Version, S, 7, Theme.Muted, 600)

        ; Нажатие на статус включает или выключает биндер.
        stb := UI.Box(g, 12, 62, this.SW - 24, 32, S, 8, "+0x100")
        this.StDot := UI.Text(g, "x20 y62 w14 h32 +0x100 +0x200 Center", "●", S, 8, Theme.Success)
        this.StText := UI.Text(g, "x38 y62 w" (this.SW - 102) " h32 +0x100 +0x200", "", S, 8, Theme.Success, 600)
        this.StVer := UI.Text(g, "x" (this.SW - 59) " y62 w39 h32 +0x100 +0x200 Right", "v" App.Version, S, 8, Theme.Faint, 600)
        statusHover := PaintHover([stb, this.StDot, this.StText, this.StVer], S, Theme.CardHover)
        for c in [stb, this.StDot, this.StText, this.StVer] {
            c.OnEvent("Click", (*) => Keys.ToggleEnabled())
            Hover.Add(c, statusHover, g.Hwnd)
        }
        UI.Divider(g, 16, 106, this.SW - 32)
        UI.Text(g, "x18 y114 w180 h14", "КАТЕГОРИИ", S, 7, Theme.Faint, 700)

        loop this.NavN {
            y := this.NavTop + (A_Index - 1) * this.NavStep
            base := UI.Box(g, 12, y, this.SW - 24, 30, S, 8, "+0x100")
            bar := UI.Box(g, 12, y + 7, 2, 16, Theme.Accent, 1, "+0x100")
            ic := UI.IconText(g, "x22 y" y " w20 h30 +0x100", "", S, 10, Theme.Muted)
            name := UI.Text(g, "x48 y" y " w" (this.SW - 94) " h30 +0x100 +0x200", "", S, 9, Theme.Soft, 500)
            cnt := UI.Text(g, "x" (this.SW - 42) " y" y " w24 h30 +0x100 +0x200 Right", "", S, 8, Theme.Faint, 600)
            this.Navs.Push({plate: base, bar: bar, ic: ic, name: name, cnt: cnt, item: 0})
            navIdx := A_Index
            navHover := SlotHover("nav", navIdx)
            for ctrl in [base, bar, ic, name, cnt] {
                ctrl.OnEvent("Click", this.NavClicker(navIdx))
                this.Hwnds[ctrl.Hwnd] := {t: "nav", i: navIdx}
                Hover.Add(ctrl, navHover, g.Hwnd)
            }
        }
        ya := this.NavTop + this.NavN * this.NavStep + 6
        ab := UI.Box(g, 12, ya, this.SW - 24, 30, S, 8, "+0x100")
        ai := UI.IconText(g, "x22 y" ya " w20 h30 +0x100", Icon.Add, S, 9, Theme.Muted)
        at := UI.Text(g, "x48 y" ya " w" (this.SW - 70) " h30 +0x100 +0x200", "Добавить категорию", S, 9, Theme.Muted, 500)
        addCategoryHover := PaintHover([ab, ai, at], S, Theme.CardHover)
        for c in [ab, ai, at] {
            c.OnEvent("Click", (*) => MainUI.NewCategory())
            Hover.Add(c, addCategoryHover, g.Hwnd)
        }

        ; Профиль и настройки — внизу, без лишних вложенных плашек.
        UI.Divider(g, 16, H - 122, this.SW - 32)
        pf := UI.Box(g, 12, H - 114, this.SW - 24, 50, S, 8, "+0x100")
        this.Avatar := UI.Text(g, "x20 y" (H - 105) " w34 h34 +0x100 +0x200 Center", "?", Theme.AccentSoft, 9, Theme.Accent, 700)
        Theme.Round(this.Avatar, 34, 34, 17)
        this.ProfName := UI.Text(g, "x64 y" (H - 108) " w" (this.SW - 94) " h16", "", S, 9, Theme.Text, 600)
        this.ProfInfo := UI.Text(g, "x64 y" (H - 91) " w" (this.SW - 94) " h13", "", S, 8, Theme.Muted)
        this.ProfId := UI.Text(g, "x64 y" (H - 77) " w" (this.SW - 94) " h12", "", S, 7, Theme.Faint)
        pch := UI.IconText(g, "x" (this.SW - 34) " y" (H - 105) " w18 h34 +0x100 +0x200", Icon.ChevR, S, 8, Theme.Faint)
        profileHover := PaintHover([pf, this.ProfName, this.ProfInfo, this.ProfId, pch], S, Theme.CardHover)
        for c in [pf, this.Avatar, this.ProfName, this.ProfInfo, this.ProfId, pch] {
            c.OnEvent("Click", (*) => SettingsUI.Open())
            Hover.Add(c, profileHover, g.Hwnd)
        }

        sr := UI.Box(g, 12, H - 54, this.SW - 24, 34, S, 8, "+0x100")
        si := UI.IconText(g, "x22 y" (H - 54) " w20 h34 +0x100", Icon.Settings, S, 10, Theme.Muted)
        stt := UI.Text(g, "x48 y" (H - 54) " w" (this.SW - 70) " h34 +0x100 +0x200", "Настройки", S, 9, Theme.Soft, 500)
        settingsHover := PaintHover([sr, si, stt], S, Theme.CardHover)
        for c in [sr, si, stt] {
            c.OnEvent("Click", (*) => SettingsUI.Open())
            Hover.Add(c, settingsHover, g.Hwnd)
        }

        ; ================= заголовок =================
        CX := this.CX, CW := this.CW
        this.TitleI := UI.IconText(g, "x" CX " y18 w36 h36", "", Theme.AccentSoft, 13, Theme.Accent)
        Theme.Round(this.TitleI, 36, 36, 11)
        this.TitleT := UI.Text(g, "x" (CX + 48) " y17 w" (Min(CW - 80, 380)) " h22", "", B, 14, Theme.Text, 700)
        this.CountT := UI.Text(g, "x" (CX + 48) " y41 w" (CW - 56) " h16", "", B, 8, Theme.Muted)

        ; Статус игры показывается текстом, без отдельной тёмной карточки.
        gcw := 170
        gcx := W - 16 - gcw
        this.GameHit := UI.Box(g, gcx, 16, gcw, 44, B, 0, "+0x100")
        this.GameDot := UI.Text(g, "x" gcx " y17 w18 h40 +0x100 +0x200 Center", "●", B, 8, Theme.Faint)
        this.GameName := UI.Text(g, "x" (gcx + 22) " y18 w" (gcw - 26) " h18 +0x100", "", B, 9, Theme.Text, 600)
        this.GameSt := UI.Text(g, "x" (gcx + 22) " y36 w" (gcw - 26) " h16 +0x100", "", B, 8, Theme.Muted)
        for c in [this.GameHit, this.GameDot, this.GameName, this.GameSt]
            c.OnEvent("Click", (*) => SettingsUI.Open())

        ; ================= поиск и действия =================
        ty := 72
        createX := W - 16 - 144
        Btn.Add(g, "x" createX " y" ty " w144 h38", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "primary", 9, Icon.Add)
        this.EnableSw := SwitchCtl(g, createX - 104, ty + 5, 92, "Биндер", Keys.Enabled, B, Theme.Success)
        this.EnableSw.Lbl.SetFont("s8 w500 c" Theme.Soft, Theme.Font)
        this.EnableSw.OnChange := (*) => Keys.ToggleEnabled()
        impX := createX - 104 - 12 - 98
        Btn.Add(g, "x" impX " y" ty " w98 h38", "Импорт", (*) => Share.ImportDialog(), "ghost", 9, Icon.Import)
        swd := impX - 12 - CX
        sf := UI.Frame(g, CX, ty, swd, 38, Theme.Field, 10)
        UI.IconText(g, "x" (CX + 12) " y" (ty - 1) " w20 h40", Icon.Search, Theme.Field, 10, Theme.Muted)
        g.SetFont("s9 w400 q5 c" Theme.Text, Theme.Font)
        this.SearchE := g.AddEdit("x" (CX + 40) " y" (ty + 8) " w" (swd - 136) " r1 -E0x200 -Multi Background" Theme.Field)
        Theme.DarkCtrl(this.SearchE)
        UI.Cue(this.SearchE, "Поиск по названию, содержимому или горячей клавише...")
        UI.FocusRing(this.SearchE, sf.o)
        hint := UI.Text(g, "x" (CX + swd - 84) " y" (ty + 10) " w38 h18 +0x200 Center", "Ctrl+K", Theme.Field, 7, Theme.Faint, 600)
        this.SearchX := UI.IconText(g, "x" (CX + swd - 38) " y" (ty + 1) " w28 h36 +0x100", Icon.Cancel, Theme.Field, 8, Theme.Muted)
        this.SearchX.OnEvent("Click", (*) => MainUI.ClearSearch())
        this.SearchX.Visible := false
        this.SearchE.OnEvent("Change", (*) => (MainUI.Offset := 0, MainUI.Refresh()))

        ; ================= карточки =================
        cardTextX := CX + 60
        cardMenuX := CX + CW - 36
        cardSwitchX := cardMenuX - 92
        cardCountX := cardSwitchX - 82
        cardCatX := cardCountX - 78
        cardKeyX := cardCatX - 90
        cardTextW := Max(150, cardKeyX - 10 - cardTextX)
        cardCatW := 68
        loop this.CardN {
            slotIdx := A_Index
            y := this.LT + (slotIdx - 1) * this.STEP
            fr := UI.Frame(g, CX, y, CW, this.CH, C, 11, Theme.Line, "+0x100")
            selBar := UI.Box(g, CX + 1, y + 10, 2, this.CH - 20, Theme.Accent, 1, "+0x100")
            selBar.Visible := false
            plate := UI.IconText(g, "x" (CX + 14) " y" (y + 16) " w34 h36 +0x100", "", C, 14, Theme.Accent)
            title := UI.Text(g, "x" cardTextX " y" (y + 8) " w" cardTextW " h18 +0x100", "", C, 10, Theme.Text, 650)
            sub1 := UI.Text(g, "x" cardTextX " y" (y + 29) " w" cardTextW " h15 +0x100", "", C, 8, Theme.Soft)
            sub2 := UI.Text(g, "x" cardTextX " y" (y + 44) " w" cardTextW " h15 +0x100", "", C, 8, Theme.Muted)
            keyf := UI.Frame(g, cardKeyX, y + 23, 52, 22, Theme.Field, 7, Theme.KeyLine)
            key := UI.Text(g, "x" cardKeyX " y" (y + 23) " w52 h22 +0x100 +0x200 Center", "", Theme.Field, 8, Theme.Text, 700, Theme.Mono)
            cat := UI.Text(g, "x" cardCatX " y" (y + 23) " w" cardCatW " h22 +0x100", "", C, 8, Theme.Accent, 600)
            cnt := UI.Text(g, "x" cardCountX " y" (y + 23) " w72 h22 +0x100 +0x200 Right", "", C, 8, Theme.Muted, 500)
            sw := SwitchCtl(g, cardSwitchX, y + 20, 84, "Вкл", true, C, Theme.Success)
            sw.Lbl.SetFont("s8 w500 c" Theme.Soft, Theme.Font)
            sw.OnChange := this.Switcher(slotIdx)
            keb := UI.IconText(g, "x" cardMenuX " y" (y + 22) " w24 h24 +0x100", Icon.More, C, 10, Theme.Muted)
            this.Cards.Push({fr: fr, selBar: selBar, plate: plate, title: title, keyf: keyf, key: key, cat: cat, sub1: sub1, sub2: sub2, cnt: cnt, sw: sw, keb: keb, textW: cardTextW, keyX: cardKeyX, catX: cardCatX, catW: cardCatW, id: ""})

            cardHover := SlotHover("card", slotIdx)
            for ctrl in [fr.o, fr.i, plate, title, sub1, sub2, keyf.o, keyf.i, key, cat, cnt, selBar] {
                ctrl.OnEvent("Click", this.CardClicker(slotIdx))
                ctrl.OnEvent("DoubleClick", this.CardOpener(slotIdx))
                this.Hwnds[ctrl.Hwnd] := {t: "card", i: slotIdx}
                Hover.Add(ctrl, cardHover, g.Hwnd)
            }
            keb.OnEvent("Click", this.KebClicker(slotIdx))
            this.Hwnds[keb.Hwnd] := {t: "card", i: slotIdx}
            Hover.Add(keb, cardHover, g.Hwnd)
        }

        ; пустое состояние списка
        e := this.E
        e.fr := UI.Frame(g, CX, this.LT, CW, 88, C, 12)
        e.ic := UI.IconText(g, "x" (CX + 16) " y" (this.LT + 22) " w44 h44", Icon.Search, Theme.AccentSoft, 14, Theme.Accent)
        Theme.Round(e.ic, 44, 44, 22)
        e.t := UI.Text(g, "x" (CX + 76) " y" (this.LT + 20) " w" (CW - 250) " h22", "", C, 11, Theme.Text, 700)
        e.s := UI.Text(g, "x" (CX + 76) " y" (this.LT + 44) " w" (CW - 250) " h30", "", C, 8, Theme.Muted)
        e.b := Btn.Add(g, "x" (CX + CW - 150) " y" (this.LT + 25) " w134 h38", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "ghost", 9, Icon.Add, C)

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

        ; ================= правая панель =================
        PX := this.PX, PW := this.PW
        px := PX + 16, pw := PW - 32
        UI.Frame(g, PX, 120, PW, H - 136, C, 14)
        d := this.D
        d.px := px, d.pw := pw
        d.yMain := H - 68
        d.ySecondary := H - 112
        d.yMeta := H - 153
        d.pvY := 314
        pvH := Max(72, d.yMeta - 14 - d.pvY)

        ; Заголовок и компактная строка статуса.
        d.ic := UI.IconText(g, "x" px " y138 w36 h36", "", C, 15, Theme.Accent)
        d.name := UI.Text(g, "x" (px + 46) " y141 w" (pw - 78) " h24", "", C, 12, Theme.Text, 700)
        d.keb := UI.IconText(g, "x" (px + pw - 24) " y138 w24 h24 +0x100", Icon.More, C, 10, Theme.Muted)
        d.keb.OnEvent("Click", (*) => MainUI.DetailMenu())
        d.keyf := UI.Frame(g, px, 183, 52, 22, Theme.Field, 7, Theme.KeyLine)
        d.key := UI.Text(g, "x" px " y183 w52 h22 +0x200 Center", "", Theme.Field, 8, Theme.Text, 700, Theme.Mono)
        d.st := UI.Text(g, "x" (px + 64) " y183 w82 h22", "", C, 8, Theme.Success, 600)
        d.cat := UI.Text(g, "x" (px + 152) " y183 w" (pw - 152) " h22", "", C, 8, Theme.Accent, 600)

        d.dlbl := UI.Text(g, "x" px " y218 w" pw " h14", "ОПИСАНИЕ", C, 7, Theme.Muted, 700)
        d.desc := UI.Text(g, "x" px " y236 w" pw " h46", "", C, 9, Theme.Soft)
        d.plbl := UI.Text(g, "x" px " y294 w" pw " h16", "ПРЕДПРОСМОТР", C, 7, Theme.Muted, 700)
        d.pbox := UI.Box(g, px, d.pvY, pw, pvH, Theme.ChatBg, 10)
        d.rv := RichView(g, px + 8, d.pvY + 8, pw - 16, pvH - 16, Theme.ChatBg)
        d.meta := UI.Text(g, "x" px " y" d.yMeta " w" pw " h18", "", C, 8, Theme.Muted)

        d.main := Btn.Add(g, "x" px " y" d.yMain " w" pw " h36", "Редактировать", (*) => MainUI.EditSelected(), "primary", 9, Icon.Edit, C)
        actionGap := 8
        actionW := (pw - actionGap * 2) // 3
        d.b1 := Btn.Add(g, "x" px " y" d.ySecondary " w" actionW " h30", "Дублировать", (*) => MainUI.DuplicateSelected(), "ghost", 8, Icon.Copy, C)
        d.b2 := Btn.Add(g, "x" (px + actionW + actionGap) " y" d.ySecondary " w" actionW " h30", "Поделиться", (*) => MainUI.ShareSelected(), "ghost", 8, Icon.Share, C)
        d.b3 := Btn.Add(g, "x" (px + (actionW + actionGap) * 2) " y" d.ySecondary " w" actionW " h30", "Удалить", (*) => MainUI.DeleteSelected(), "danger", 8, Icon.Delete, C)

        ; Чистое пустое состояние без горячих клавиш, занимающих весь предпросмотр.
        d.emptyIcon := UI.IconText(g, "x" (px + (pw - 48) // 2) " y260 w48 h48", Icon.Search, Theme.AccentSoft, 16, Theme.Accent)
        Theme.Round(d.emptyIcon, 48, 48, 16)
        d.emptyTitle := UI.Text(g, "x" (px + 8) " y320 w" (pw - 16) " h22 +0x200 Center", "Выберите бинд", C, 11, Theme.Text, 700)
        d.emptyHint := UI.Text(g, "x" (px + 12) " y348 w" (pw - 24) " h44 +0x200 Center", "Выберите карточку в списке, чтобы увидеть описание и предпросмотр.", C, 8, Theme.Muted)
        d.emptyKeys := UI.Text(g, "x" (px + 8) " y400 w" (pw - 16) " h28 +0x200 Center", "Двойной клик — редактировать  ·  ПКМ — действия", C, 7, Theme.Faint)
        d.hint := UI.Text(g, "x" px " y218 w" pw " h46", "", C, 8, Theme.Muted)

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
        this.ProfName.Value := this.FitText(nick != "" ? StrReplace(nick, "_", " ") : "Укажите ник", this.SW - 94, 9, 600)
        this.ProfInfo.Value := this.FitText(p["rank"] != "" ? p["rank"] : "профиль не заполнен", this.SW - 94, 8, 400)
        this.ProfId.Value := this.FitText(p["id"] != "" ? "ID: " p["id"] : "ID не указан", this.SW - 94, 7, 400)
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

        this.TitleT.Value := this.FitText(this.CurCat = "" ? "Все бинды" : this.CurCat, Min(this.CW - 80, 380), 14, 700)
        this.TitleI.Value := this.CurCat = "" ? Icon.Home : Icon.ForCat(this.CurCat)
        n := this.Rows.Length
        if q != ""
            countText := "Найдено " n " " this.Plural(n, "бинд", "бинда", "биндов") " по запросу «" Trim(this.SearchE.Value) "»"
        else {
            k := this.Sel.Count
            countText := n " " this.Plural(n, "бинд", "бинда", "биндов") (k ? "  ·  " k " выбрано" : "")
        }
        this.CountT.Value := this.FitText(countText, this.CW - 56, 8, 400)
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
            nav.name.Value := this.FitText(it.label, this.SW - 94, 9, 500)
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

    static FitText(text, width, size := 9, weight := 400, font := "") {
        text := String(text)
        if text = "" || width <= 0
            return ""
        if UI.TextW(text, size, weight, font) <= width
            return text
        ellipsis := "…"
        while StrLen(text) && UI.TextW(text "…", size, weight, font) > width
            text := SubStr(text, 1, -1)
        return text = "" ? ellipsis : RTrim(text) ellipsis
    }

    static RenderCards() {
        maxOff := Max(0, this.Rows.Length - this.CardN)
        this.Offset := Min(Max(this.Offset, 0), maxOff)
        parts := ["plate", "title", "key", "cat", "sub1", "sub2", "cnt", "keb", "selBar"]
        loop this.CardN {
            card := this.Cards[A_Index]
            idx := this.Offset + A_Index
            show := idx <= this.Rows.Length
            card.fr.o.Visible := show, card.fr.i.Visible := show
            card.keyf.o.Visible := show, card.keyf.i.Visible := show
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
            lines := this.FirstLines(b, 2)
            y := this.LT + (A_Index - 1) * this.STEP
            l1 := lines.Length ? lines[1] : "Нет строк для отправки"
            l2 := lines.Length > 1 ? lines[2] : ""
            card.plate.Value := Icon.ForCat(b["category"])
            card.title.Value := this.FitText(b["name"], card.textW, 10, 650)
            card.title.SetFont("c" (b["enabled"] ? Theme.Text : Theme.Muted))
            card.sub1.Value := this.FitText(l1, card.textW, 8, 400)
            card.sub1.SetFont("c" (SubStr(l1, 1, 3) = "/me" ? Theme.Accent : Theme.Soft))
            card.sub2.Value := this.FitText(l2, card.textW, 8, 400)

            ; Горячая клавиша — единственный текстовый бейдж в карточке.
            kt := b["hotkey"] != "" ? StrReplace(Keys.Pretty(b["hotkey"]), " + ", "+") : "—"
            kw := Min(80, Max(40, UI.TextW(kt, 7, 700, Theme.Mono) + 14))
            card.key.Value := this.FitText(kt, kw - 8, 7, 700, Theme.Mono)
            card.key.SetFont("s7 c" (b["hotkey"] = "" ? Theme.Faint : Theme.Text), Theme.Mono)
            this.MoveKeyBadge(card, card.keyX, kw, y)

            catPrefix := "• "
            catText := this.FitText(b["category"], card.catW - UI.TextW(catPrefix, 8, 600), 8, 600)
            card.cat.Value := catPrefix catText
            card.cat.SetFont("c" Theme.Accent)
            card.cat.Move(card.catX, y + 23, card.catW, 22)

            n := steps.Length
            card.cnt.Value := n " " this.Plural(n, "строка", "строки", "строк")
            card.sw.Set(b["enabled"])
            card.sw.Lbl.Value := b["enabled"] ? "Вкл" : "Выкл"
            card.sw.Lbl.SetFont("s8 w500 c" (b["enabled"] ? Theme.Soft : Theme.Faint), Theme.Font)
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
        card.keyf.o.Move(kx, y + 23, kw, 22)
        card.keyf.i.Move(kx + 1, y + 1 + 23, kw - 2, 20)
        Theme.Round(card.keyf.o, kw, 22, 7)
        Theme.Round(card.keyf.i, kw - 2, 20, 6)
        card.key.Move(kx, y + 23, kw, 22)
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
        bg := hv && !sel ? Theme.CardHover : Theme.Card
        UI.Paint(card.fr.o, sel ? Theme.AccentLine : hv ? Theme.LineHover : Theme.Line)
        UI.Paint(card.fr.i, bg)
        for k in ["plate", "title", "sub1", "sub2", "cat", "cnt", "keb"]
            UI.Paint(card.%k%, bg)
        UI.Paint(card.selBar, Theme.Accent)
        UI.Paint(card.sw.Lbl, bg)
        UI.Paint(card.keyf.i, Theme.Field)
        UI.Paint(card.key, Theme.Field)
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

    ; правая панель: обзор / один бинд / несколько
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
        for c in [d.emptyIcon, d.emptyTitle, d.emptyHint, d.emptyKeys]
            c.Visible := !selected
        d.main.Show(selected), d.b1.Show(selected), d.b2.Show(selected), d.b3.Show(selected)

        if !selected {
            d.emptyTitle.Value := "Выберите бинд"
            d.emptyHint.Value := "Выберите карточку в списке, чтобы увидеть описание и предпросмотр."
            d.emptyKeys.Value := "Двойной клик — редактировать  ·  ПКМ — действия"
            return
        }
        if multi {
            d.ic.Value := Icon.All
            d.name.Value := this.FitText(ids.Length " выбрано", d.pw - 82, 12, 700)
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
        d.name.Value := this.FitText(b["name"], pw - 82, 12, 700)

        kt := b["hotkey"] != "" ? StrReplace(Keys.Pretty(b["hotkey"]), " + ", "+") : "без клавиши"
        kw := Min(96, Max(48, UI.TextW(kt, 7, 700, Theme.Mono) + 14))
        keyText := this.FitText(kt, kw - 8, 7, 700, Theme.Mono)
        d.keyf.o.Move(px, 183, kw, 22)
        d.keyf.i.Move(px + 1, 184, kw - 2, 20)
        Theme.Round(d.keyf.o, kw, 22, 7)
        Theme.Round(d.keyf.i, kw - 2, 20, 6)
        d.key.Move(px, 183, kw, 22)
        d.key.Value := keyText
        d.key.SetFont("s7 c" (b["hotkey"] = "" ? Theme.Faint : Theme.Text), Theme.Mono)

        enabled := b["enabled"]
        d.st.Value := enabled ? "● Активен" : "○ Выключен"
        d.st.SetFont("c" (enabled ? Theme.Success : Theme.Faint))
        d.st.Move(px + kw + 10, 183, 82, 22)
        catX := px + kw + 98
        catW := Max(24, pw - kw - 98)
        catPrefix := "• "
        d.cat.Value := catPrefix this.FitText(b["category"], catW - UI.TextW(catPrefix, 8, 600), 8, 600)
        d.cat.Move(catX, 183, catW, 22)
        d.cat.SetFont("c" Theme.Accent)

        lines := this.FirstLines(b, 2)
        desc := ""
        for line in lines
            desc .= (desc != "" ? "`n" : "") this.FitText(line, pw - 2, 9, 400)
        d.desc.Value := desc != "" ? desc : "Описания нет — добавьте строки в редакторе."
        d.plbl.Value := "ПРЕДПРОСМОТР"
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
