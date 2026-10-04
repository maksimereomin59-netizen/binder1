; Небольшой JSON-парсер: объекты -> Map, массивы -> Array
class Json {
    static Parse(text) {
        pos := 1
        value := this._Value(&text, &pos)
        this._Ws(&text, &pos)
        if pos <= StrLen(text)
            throw Error("JSON: лишние символы на позиции " pos)
        return value
    }

    static Stringify(v, indent := "  ", level := 0) {
        nl := indent = "" ? "" : "`n"
        colon := indent = "" ? ":" : ": "
        if v is Map {
            if v.Count = 0
                return "{}"
            out := "{"
            first := true
            for k, val in v {
                out .= (first ? "" : ",") nl this._Rep(indent, level + 1) this._Quote(String(k)) colon this.Stringify(val, indent, level + 1)
                first := false
            }
            return out nl this._Rep(indent, level) "}"
        }
        if v is Array {
            if v.Length = 0
                return "[]"
            out := "["
            for i, val in v
                out .= (i > 1 ? "," : "") nl this._Rep(indent, level + 1) this.Stringify(val, indent, level + 1)
            return out nl this._Rep(indent, level) "]"
        }
        if v is Number
            return String(v)
        return this._Quote(String(v))
    }

    static _Rep(s, n) {
        out := ""
        loop n
            out .= s
        return out
    }

    static _Quote(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`t", "\t")
        return '"' s '"'
    }

    static _Ws(&s, &p) {
        len := StrLen(s)
        while p <= len {
            c := SubStr(s, p, 1)
            if c != " " && c != "`t" && c != "`r" && c != "`n"
                break
            p++
        }
    }

    static _Value(&s, &p) {
        this._Ws(&s, &p)
        c := SubStr(s, p, 1)
        if c = "{" {
            obj := Map()
            p++
            this._Ws(&s, &p)
            if SubStr(s, p, 1) = "}" {
                p++
                return obj
            }
            loop {
                this._Ws(&s, &p)
                if SubStr(s, p, 1) != '"'
                    throw Error("JSON: ожидался ключ на позиции " p)
                key := this._String(&s, &p)
                this._Ws(&s, &p)
                if SubStr(s, p, 1) != ":"
                    throw Error("JSON: ожидалось ':' на позиции " p)
                p++
                obj[key] := this._Value(&s, &p)
                this._Ws(&s, &p)
                c := SubStr(s, p, 1)
                p++
                if c = "}"
                    return obj
                if c != ","
                    throw Error("JSON: ожидалось ',' или '}' на позиции " (p - 1))
            }
        }
        if c = "[" {
            arr := []
            p++
            this._Ws(&s, &p)
            if SubStr(s, p, 1) = "]" {
                p++
                return arr
            }
            loop {
                arr.Push(this._Value(&s, &p))
                this._Ws(&s, &p)
                c := SubStr(s, p, 1)
                p++
                if c = "]"
                    return arr
                if c != ","
                    throw Error("JSON: ожидалось ',' или ']' на позиции " (p - 1))
            }
        }
        if c = '"'
            return this._String(&s, &p)
        if RegExMatch(s, "-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", &m, p) && m.Pos = p {
            p += m.Len
            return (InStr(m[0], ".") || InStr(m[0], "e")) ? Float(m[0]) : Integer(m[0])
        }
        if SubStr(s, p, 4) == "true" {
            p += 4
            return 1
        }
        if SubStr(s, p, 5) == "false" {
            p += 5
            return 0
        }
        if SubStr(s, p, 4) == "null" {
            p += 4
            return ""
        }
        throw Error("JSON: неожиданный символ на позиции " p)
    }

    static _String(&s, &p) {
        p++
        out := ""
        len := StrLen(s)
        loop {
            if p > len
                throw Error("JSON: незакрытая строка")
            c := SubStr(s, p, 1)
            if c = '"' {
                p++
                return out
            }
            if c = "\" {
                n := SubStr(s, p + 1, 1)
                switch n, true {
                    case '"': out .= '"'
                    case "\": out .= "\"
                    case "/": out .= "/"
                    case "b": out .= Chr(8)
                    case "f": out .= Chr(12)
                    case "n": out .= "`n"
                    case "r": out .= "`r"
                    case "t": out .= "`t"
                    case "u":
                        out .= Chr(Integer("0x" SubStr(s, p + 2, 4)))
                        p += 4
                    default:
                        throw Error("JSON: неверная escape-последовательность")
                }
                p += 2
                continue
            }
            out .= c
            p++
        }
    }
}

; Base64 для кодов обмена (UTF-8)
class B64 {
    static Encode(str) {
        n := StrPut(str, "UTF-8")
        buf := Buffer(n)
        StrPut(str, buf, "UTF-8")
        flags := 0x40000001
        chars := 0
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", n - 1, "UInt", flags, "Ptr", 0, "UInt*", &chars)
        out := Buffer(chars * 2)
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", n - 1, "UInt", flags, "Ptr", out, "UInt*", &chars)
        return StrGet(out, "UTF-16")
    }

    static Decode(b64) {
        b64 := RegExReplace(b64, "\s")
        size := 0
        if !DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
            throw Error("код повреждён")
        buf := Buffer(size)
        DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", buf, "UInt*", &size, "Ptr", 0, "Ptr", 0)
        return StrGet(buf, size, "UTF-8")
    }
}
