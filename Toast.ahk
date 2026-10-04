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
