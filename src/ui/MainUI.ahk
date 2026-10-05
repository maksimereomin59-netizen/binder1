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
