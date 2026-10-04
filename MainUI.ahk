; ============================================================
;  Главное окно: сайдбар · список карточек · панель выбранного бинда
;  Размер окна подбирается под экран (1366×768 … 1920×1080 и выше)
; ============================================================
class MainUI {
    static G := 0
    static W := 1200
    static H := 700
    static SW := 240           ; ширина сайдбара
    static PW := 320           ; ширина правой панели
    static PX := 0
    static CX := 0
    static CW := 0
    static LT := 146           ; верх списка карточек
    static STEP := 62
    static CH := 54
    static NavTop := 160
    static NavStep := 36
    static CardN := 7
    static NavN := 8
    static Cards := []
    static Navs := []
    static Hwnds := Map()      ; hwnd -> {t: "card"|"nav", i}
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
        this.W := Round(Min(1280, ww - 16, Max(1100, ww - 120)))
        this.H := Round(Min(820, wh - 16, Max(600, wh - 60)))
        this.PW := this.W >= 1240 ? 330 : 300
        this.CX := this.SW + 28
        this.PX := this.W - this.PW - 20
        this.CW := this.PX - 20 - this.CX
        this.CardN := Max(4, (this.H - this.LT - 40) // this.STEP)
        this.NavN := Max(3, (this.H - this.NavTop - 110) // this.NavStep)
    }

    static Build() {
        Theme.Init()
        this.Layout()
        S := Theme.Side, B := Theme.Bg, C := Theme.Card, W := this.W, H := this.H
        g := Gui("-MaximizeBox", App.Name " — Doctor Binder")
        g.BackColor := B
        g.MarginX := 0, g.MarginY := 0
        this.G := g

        ; ================= сайдбар =================
        UI.Box(g, 0, 0, this.SW, H, S, 0)
        UI.Box(g, this.SW, 0, 1, H, Theme.Line, 0)
        lg := UI.IconText(g, "x20 y22 w38 h38", Icon.Cat["health"], Theme.AccentSoft, 15, Theme.Accent)
        Theme.Round(lg, 38, 38, 11)
        UI.Text(g, "x70 y21 w160 h22", "MedBind", S, 13, Theme.Text, 700)
        UI.Text(g, "x70 y43 w160 h16", "Doctor Binder  ·  v" App.Version, S, 8, Theme.Muted)

        ; индикатор активности (клик — вкл / выкл)
        st := UI.Frame(g, 16, 76, 208, 36, C, 9, , "+0x100")
        this.StDot := UI.Text(g, "x30 y76 w14 h36 +0x200", "●", C, 9, Theme.Success)
        this.StText := UI.Text(g, "x46 y76 w100 h36 +0x200", "", C, 9, Theme.Text, 600)
        this.StKey := UI.Text(g, "x146 y76 w66 h36 +0x200 Right", "", C, 8, Theme.Faint, 600, Theme.Mono)
        st.i.OnEvent("Click", (*) => Keys.ToggleEnabled())
        Hover.Add(st.i, PaintHover([st.i, this.StDot, this.StText, this.StKey], C, Theme.CardHover), g.Hwnd)

        UI.Label(g, "x24 y134 w140 h16", "КАТЕГОРИИ", S)
        Btn.Add(g, "x192 y128 w28 h26", "", (*) => MainUI.NewCategory(), "subtle", 9, Icon.Add, S)
        loop this.NavN {
            y := this.NavTop + (A_Index - 1) * this.NavStep
            base := UI.Box(g, 12, y, 216, 32, S, 8, "+0x100")
            bar := UI.Box(g, 12, y + 8, 3, 16, Theme.Accent, 2)
            ic := UI.IconText(g, "x24 y" y " w20 h32", "", S, 10, Theme.Muted)
            name := UI.Text(g, "x52 y" y " w124 h32 +0x200", "", S, 10, Theme.Soft, 500)
            cnt := UI.Text(g, "x180 y" (y + 7) " w36 h18 +0x200 Center", "", S, 8, Theme.Faint, 600)
            Theme.Round(cnt, 36, 18, 9)
            this.Navs.Push({plate: base, bar: bar, ic: ic, name: name, cnt: cnt, item: 0})
            base.OnEvent("Click", this.NavClicker(A_Index))
            this.Hwnds[base.Hwnd] := {t: "nav", i: A_Index}
            Hover.Add(base, SlotHover("nav", A_Index), g.Hwnd)
        }

        ; профиль + настройки
        UI.Divider(g, 16, H - 86, 208)
        pf := UI.Box(g, 12, H - 72, 168, 52, S, 10, "+0x100")
        this.Avatar := UI.Text(g, "x22 y" (H - 64) " w36 h36 +0x200 Center", "?", Theme.VioletSoft, 10, Theme.Violet, 700)
        Theme.Round(this.Avatar, 36, 36, 18)
        this.ProfName := UI.Text(g, "x68 y" (H - 65) " w108 h20", "", S, 10, Theme.Text, 600)
        this.ProfInfo := UI.Text(g, "x68 y" (H - 45) " w108 h16", "", S, 8, Theme.Muted)
        pf.OnEvent("Click", (*) => SettingsUI.Open())
        Hover.Add(pf, PaintHover([pf, this.ProfName, this.ProfInfo], S, Theme.Card), g.Hwnd)
        Btn.Add(g, "x186 y" (H - 64) " w38 h36", "", (*) => SettingsUI.Open(), "subtle", 11, Icon.Settings, S)

        ; ================= шапка =================
        CX := this.CX, CW := this.CW, R := CX + CW
        this.TitleI := UI.IconText(g, "x" CX " y26 w36 h36", "", Theme.AccentSoft, 13, Theme.Accent)
        Theme.Round(this.TitleI, 36, 36, 10)
        this.TitleT := UI.Text(g, "x" (CX + 48) " y22 w" (CW - 330) " h28", "", B, 16, Theme.Text, 700)
        this.CountT := UI.Text(g, "x" (CX + 48) " y49 w" (CW - 330) " h18", "", B, 9, Theme.Muted)
        Btn.Add(g, "x" (R - 278) " y24 w116 h40", "Импорт", (*) => Share.ImportDialog(), "ghost", 10, Icon.Import)
        Btn.Add(g, "x" (R - 154) " y24 w154 h40", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "primary", 10, Icon.Add)

        ; поиск
        sf := UI.Frame(g, CX, 84, CW, 44, Theme.Field, 10)
        UI.IconText(g, "x" (CX + 14) " y85 w20 h42", Icon.Search, Theme.Field, 11, Theme.Muted)
        g.SetFont("s10 w400 q5 c" Theme.Text, Theme.Font)
        this.SearchE := g.AddEdit("x" (CX + 44) " y96 w" (CW - 150) " r1 -E0x200 -Multi Background" Theme.Field)
        Theme.DarkCtrl(this.SearchE)
        UI.Cue(this.SearchE, "Поиск по названию, тексту или клавише")
        UI.FocusRing(this.SearchE, sf.o)
        this.SearchX := UI.IconText(g, "x" (R - 100) " y85 w24 h42 +0x100", Icon.Cancel, Theme.Field, 8, Theme.Muted)
        this.SearchX.OnEvent("Click", (*) => MainUI.ClearSearch())
        this.SearchX.Visible := false
        hint := UI.Text(g, "x" (R - 70) " y96 w56 h20 +0x200 Center", "Ctrl+F", Theme.FieldHover, 8, Theme.Muted, 600)
        Theme.Round(hint, 56, 20, 6)
        this.SearchE.OnEvent("Change", (*) => (MainUI.Offset := 0, MainUI.Refresh()))

        ; ================= карточки =================
        tx := CX + 50, tw := CW - 50 - 250
        loop this.CardN {
            y := this.LT + (A_Index - 1) * this.STEP
            fr := UI.Frame(g, CX, y, CW, this.CH, C, 10, , "+0x100")
            bar := UI.Box(g, CX + 1, y + 12, 3, this.CH - 24, Theme.Accent, 2)
            chk := UI.IconText(g, "x" (CX + 16) " y" (y + 17) " w20 h20", "", Theme.Field, 8, Theme.AccentInk)
            Theme.Round(chk, 20, 20, 10)
            title := UI.Text(g, "x" tx " y" (y + 8) " w" tw " h20", "", C, 10, Theme.Text, 600)
            sub := UI.Text(g, "x" tx " y" (y + 29) " w" tw " h18", "", C, 9, Theme.Muted)
            catI := UI.IconText(g, "x" (R - 236) " y" (y + 8) " w16 h20", "", C, 8, Theme.Muted)
            cat := UI.Text(g, "x" (R - 216) " y" (y + 8) " w100 h20 +0x200", "", C, 9, Theme.Soft, 500)
            cnt := UI.Text(g, "x" (R - 236) " y" (y + 29) " w120 h18", "", C, 8, Theme.Faint)
            key := UI.Text(g, "x" (R - 106) " y" (y + 14) " w92 h26 +0x200 Center", "", Theme.Field, 9, Theme.Accent, 700, Theme.Mono)
            Theme.Round(key, 92, 26, 7)
            this.Cards.Push({fr: fr, bar: bar, chk: chk, title: title, sub: sub, catI: catI, cat: cat, cnt: cnt, key: key, id: "", tw: tw})
            fr.i.OnEvent("Click", this.CardClicker(A_Index))
            fr.i.OnEvent("DoubleClick", this.CardOpener(A_Index))
            this.Hwnds[fr.i.Hwnd] := {t: "card", i: A_Index}
            Hover.Add(fr.i, SlotHover("card", A_Index), g.Hwnd)
        }

        ; пустые состояния
        e := this.E, ey := this.LT + 60
        e.ic := UI.IconText(g, "x" (CX + CW // 2 - 28) " y" ey " w56 h56", Icon.Folder, C, 18, Theme.Accent)
        Theme.Round(e.ic, 56, 56, 16)
        e.t := UI.Text(g, "x" CX " y" (ey + 72) " w" CW " h26 Center", "", B, 13, Theme.Text, 700)
        e.s := UI.Text(g, "x" (CX + 40) " y" (ey + 102) " w" (CW - 80) " h40 Center", "", B, 9, Theme.Muted)
        e.b := Btn.Add(g, "x" (CX + CW // 2 - 85) " y" (ey + 152) " w170 h40", "Создать бинд", (*) => Editor.Open("", MainUI.CurCat), "chip", 10, Icon.Add)
        this.ScrollT := UI.Text(g, "x" CX " y" (H - 30) " w" CW " h18 Center", "", B, 8, Theme.Faint)

        ; ================= правая панель =================
        PX := this.PX, px := PX + 22, pw := this.PW - 44
        UI.Frame(g, PX, 24, this.PW, H - 48, C, 14)
        d := this.D, d.px := px, d.pw := pw
        d.lbl := UI.Label(g, "x" px " y44 w" pw " h16", "", C)
        d.name := UI.Text(g, "x" px " y64 w" pw " h28", "", C, 14, Theme.Text, 700)
        d.key := UI.Text(g, "x" px " y102 w90 h26 +0x200 Center", "", Theme.Field, 9, Theme.Accent, 700, Theme.Mono)
        d.catI := UI.IconText(g, "x" px " y102 w16 h26", "", C, 8, Theme.Muted)
        d.cat := UI.Text(g, "x" px " y102 w120 h26 +0x200", "", C, 9, Theme.Soft, 500)
        d.st := UI.Text(g, "x" (px + pw - 84) " y104 w84 h22 +0x200 Center", "", Theme.SuccessBg, 8, Theme.Success, 700)
        Theme.Round(d.st, 84, 22, 11)
        d.hint := UI.Text(g, "x" px " y100 w" pw " h38", "", C, 9, Theme.Muted)
        UI.Divider(g, px, 144, pw)
        d.plbl := UI.Label(g, "x" px " y158 w" pw " h16", "", C)
        UI.Box(g, px, 180, pw, H - 348, Theme.ChatBg, 10)
        d.rv := RichView(g, px + 14, 192, pw - 24, H - 372, Theme.ChatBg)
        d.stats := UI.Text(g, "x" px " y" (H - 160) " w" pw " h18", "", C, 8, Theme.Faint)
        d.main := Btn.Add(g, "x" px " y" (H - 132) " w" pw " h40", "Редактировать", (*) => MainUI.EditSelected(), "primary", 10, Icon.Edit, C)
        bw := (pw - 52) // 2
        d.b1 := Btn.Add(g, "x" px " y" (H - 82) " w" bw " h36", "Дублировать", (*) => MainUI.DuplicateSelected(), "ghost", 9, Icon.Copy, C)
        d.b2 := Btn.Add(g, "x" (px + bw + 8) " y" (H - 82) " w" bw " h36", "Поделиться", (*) => MainUI.ShareSelected(), "ghost", 9, Icon.Share, C)
        d.b3 := Btn.Add(g, "x" (px + pw - 36) " y" (H - 82) " w36 h36", "", (*) => MainUI.DeleteSelected(), "danger", 10, Icon.Delete, C)

        g.OnEvent("Close", (*) => MainUI.G.Hide())
        g.OnEvent("Escape", (*) => MainUI.OnEsc())
        g.OnEvent("ContextMenu", ObjBindMethod(this, "OnContext"))
        OnMessage(0x20A, ObjBindMethod(this, "OnWheel"))

        ; горячие клавиши внутри окна
        HotIf((*) => MainUI.G && WinActive("ahk_id " MainUI.G.Hwnd))
        Hotkey("^f", (*) => (MainUI.SearchE.Focus(), SendMessage(0xB1, 0, -1, MainUI.SearchE)))
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
        this.StText.Value := on ? "Биндер активен" : "На паузе"
        this.StKey.Value := Keys.Pretty(Store.Data["settings"]["hkToggle"])
        for c in [this.StDot, this.StText, this.StKey]
            c.Redraw()
    }

    static UpdateProfile() {
        if !this.G
            return
        p := Store.Data["profile"]
        nick := String(p["nick"])
        this.ProfName.Value := nick != "" ? StrReplace(nick, "_", " ") : "Укажите ник"
        this.ProfInfo.Value := (p["rank"] != "" ? p["rank"] : "профиль не заполнен") (p["id"] != "" ? "  ·  ID " p["id"] : "")
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

        this.NavItems := [{label: "Все бинды", cat: "", n: Store.Data["binds"].Length, glyph: Icon.All}]
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
        this.TitleI.Value := this.CurCat = "" ? Icon.All : Icon.ForCat(this.CurCat)
        n := this.Rows.Length
        if q != ""
            this.CountT.Value := "Найдено " n " " this.Plural(n, "бинд", "бинда", "биндов") " по запросу «" Trim(this.SearchE.Value) "»"
        else {
            act := 0
            for id in this.Rows
                act += Store.Find(id)["enabled"] ? 1 : 0
            this.CountT.Value := n " " this.Plural(n, "бинд", "бинда", "биндов") (n ? "  ·  " act " активн" (act = 1 ? "ый" : "ых") : "")
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
        bg := on ? Theme.CardSel : hv ? Theme.Card : Theme.Side
        UI.Paint(nav.plate, bg)
        nav.bar.Visible := on
        nav.ic.SetFont("c" (on ? Theme.Accent : hv ? Theme.Soft : Theme.Muted))
        nav.name.SetFont((on ? "w600 c" Theme.Text : "w500 c" (hv ? Theme.Text : Theme.Soft)))
        nav.cnt.SetFont("c" (on ? Theme.Accent : Theme.Faint))
        UI.Paint(nav.ic, bg), UI.Paint(nav.name, bg)
        UI.Paint(nav.cnt, on ? Theme.AccentSoft : hv ? Theme.Field : Theme.Card)
        if on
            nav.bar.Redraw()
    }

    static RenderCards() {
        maxOff := Max(0, this.Rows.Length - this.CardN)
        this.Offset := Min(Max(this.Offset, 0), maxOff)
        parts := ["title", "sub", "catI", "cat", "cnt", "key", "chk"]
        loop this.CardN {
            card := this.Cards[A_Index]
            idx := this.Offset + A_Index
            show := idx <= this.Rows.Length
            card.fr.o.Visible := show, card.fr.i.Visible := show
            for k in parts
                card.%k%.Visible := show
            if !show {
                card.id := "", card.bar.Visible := false
                continue
            }
            b := Store.Find(this.Rows[idx])
            card.id := b["id"]
            steps := Sender.Plan(b)
            first := steps.Length ? Sender.Resolve(steps[1].text) : "нет строк для отправки"
            maxc := card.tw // 7
            card.title.Value := b["name"]
            card.title.SetFont("c" (b["enabled"] ? Theme.Text : Theme.Muted))
            card.sub.Value := StrLen(first) > maxc ? SubStr(first, 1, maxc - 1) "…" : first
            card.catI.Value := Icon.ForCat(b["category"])
            card.cat.Value := b["category"]
            card.cnt.Value := (b["enabled"] ? "" : "выключен  ·  ") Preview.Msgs(steps.Length)
            card.cnt.SetFont("c" (b["enabled"] ? Theme.Faint : Theme.Danger))
            card.key.Value := b["hotkey"] != "" ? Keys.Pretty(b["hotkey"]) : "—"
            card.key.SetFont("c" (b["hotkey"] = "" ? Theme.Faint : b["enabled"] ? Theme.Accent : Theme.Muted))
            this.PaintCard(A_Index)
        }
        n := this.Rows.Length, e := this.E
        empty := !n
        for c in [e.ic, e.t, e.s]
            c.Visible := empty
        e.b.Show(empty)
        if empty {
            q := Trim(this.SearchE.Value)
            if q != "" {
                e.ic.Value := Icon.Search
                e.t.Value := "Ничего не найдено"
                e.s.Value := "По запросу «" q "» нет биндов. Ищите по названию, тексту или клавише (например «F5»)."
                e.b.Set("Очистить поиск", Icon.Cancel, (*) => MainUI.ClearSearch())
            } else {
                e.ic.Value := this.CurCat = "" ? Icon.All : Icon.ForCat(this.CurCat)
                e.t.Value := this.CurCat = "" ? "Здесь пока пусто" : "В «" this.CurCat "» пока нет биндов"
                e.s.Value := "Создайте первый бинд или импортируйте код MEDBIND от другого игрока."
                e.b.Set("Создать бинд", Icon.Add, (*) => Editor.Open("", MainUI.CurCat))
            }
        }
        this.ScrollT.Value := n > this.CardN ? (this.Offset + 1) "–" Min(n, this.Offset + this.CardN) " из " n "   ·   колёсико — прокрутка" : ""
    }

    static PaintCard(i) {
        card := this.Cards[i]
        if card.id = ""
            return
        sel := this.Sel.Has(card.id)
        hv := this.HoverCard = i
        bg := sel ? Theme.CardSel : hv ? Theme.CardHover : Theme.Card
        UI.Paint(card.fr.o, sel ? Theme.AccentLine : hv ? Theme.LineHover : Theme.Line)
        UI.Paint(card.fr.i, bg)
        for k in ["title", "sub", "catI", "cat", "cnt"]
            UI.Paint(card.%k%, bg)
        card.chk.Value := sel ? Icon.Check : ""
        UI.Paint(card.chk, sel ? Theme.Accent : hv ? Theme.FieldHover : Theme.Field)
        UI.Paint(card.key, sel ? Theme.AccentSoft : Theme.Field)
        card.bar.Visible := sel
        if sel
            card.bar.Redraw()
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
        for c in [d.key, d.catI, d.cat, d.st]
            c.Visible := one
        d.hint.Visible := !one
        if !ids.Length {
            d.lbl.Value := "ОБЗОР"
            d.name.Value := "Ничего не выбрано"
            d.hint.Value := "Выберите бинд в списке — здесь появится предпросмотр чата. Двойной клик — редактор."
            d.plbl.Value := "БЫСТРЫЙ СТАРТ"
            d.rv.Set(Preview.Overview())
            d.stats.Value := ""
            d.main.Set("Создать бинд", Icon.Add, (*) => Editor.Open("", MainUI.CurCat))
            d.b1.Set("Импорт", Icon.Import, (*) => Share.ImportDialog())
            d.b2.Set("Экспорт", Icon.Share, (*) => MainUI.ShareSelected())
            d.b3.Show(false)
            return
        }
        d.b3.Show(true)
        if !one {
            d.lbl.Value := "ВЫБРАНО"
            d.name.Value := ids.Length " " this.Plural(ids.Length, "бинд", "бинда", "биндов")
            d.hint.Value := "Ctrl + клик — добавить или убрать, Shift + клик — диапазон, Esc — снять выбор."
            d.plbl.Value := "СПИСОК"
            d.rv.Set(Preview.List(ids))
            d.stats.Value := ""
            d.main.Set("Поделиться (" ids.Length ")", Icon.Share, (*) => MainUI.ShareSelected())
            d.b1.Set("Перенести", Icon.Move, (*) => MainUI.MoveMenu())
            d.b2.Set("Вкл / выкл", Icon.Power, (*) => MainUI.ToggleSelected())
            return
        }
        b := Store.Find(ids[1])
        px := d.px, pw := d.pw
        d.lbl.Value := "ВЫБРАННЫЙ БИНД"
        d.name.Value := b["name"]
        kt := b["hotkey"] != "" ? Keys.Pretty(b["hotkey"]) : "нет клавиши"
        kw := Min(150, Max(56, UI.TextW(kt, 9, 700, Theme.Mono) + 24))
        d.key.Value := kt
        d.key.SetFont("c" (b["hotkey"] = "" ? Theme.Muted : Theme.Accent))
        d.key.Move(px, 102, kw, 26)
        Theme.Round(d.key, kw, 26, 7)
        d.catI.Move(px + kw + 10, 102)
        d.cat.Move(px + kw + 28, 102, pw - kw - 28 - 92)
        d.catI.Value := Icon.ForCat(b["category"])
        d.cat.Value := b["category"]
        on := b["enabled"]
        d.st.Value := on ? "●  АКТИВЕН" : "○  ВЫКЛ"
        d.st.SetFont("c" (on ? Theme.Success : Theme.Danger))
        UI.Paint(d.st, on ? Theme.SuccessBg : Theme.DangerBg)
        d.plbl.Value := "ПРЕДПРОСМОТР ЧАТА"
        d.rv.Set(Preview.Chat(b))
        d.stats.Value := Preview.Stat(b) "   ·   пауза " Format("{:.1f}", Store.Num(b["delay"], 1300) / 1000) " с"
        d.main.Set("Редактировать", Icon.Edit, (*) => MainUI.EditSelected())
        d.b1.Set("Дублировать", Icon.Copy, (*) => MainUI.DuplicateSelected())
        d.b2.Set("Поделиться", Icon.Share, (*) => MainUI.ShareSelected())
        for c in [d.key, d.catI, d.cat, d.st]
            c.Redraw()
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
        m := Menu()
        if hit.t = "card" {
            id := this.Cards[hit.i].id
            if id = ""
                return
            if !this.Sel.Has(id)
                this.SelectId(id)
            ids := this.SelectedIds()
            b := Store.Find(id)
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
        } else {
            it := this.Navs[hit.i].item
            if !it || it.cat = ""
                return
            name := it.cat
            m.Add("Новый бинд здесь", (*) => Editor.Open("", name))
            m.Add("Изменить категорию…", (*) => MainUI.RenameCategory(name))
            m.Add()
            m.Add("Удалить категорию", (*) => MainUI.DeleteCategory(name))
        }
        m.Show()
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
        if c
            this.SelectId(c["id"])
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
        for id in ids
            Store.Find(id)["enabled"] := anyOff
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
            if b := Store.Find(id)
                b["category"] := cat
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
