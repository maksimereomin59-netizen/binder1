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
