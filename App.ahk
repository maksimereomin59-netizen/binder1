class App {
    static Name := "MedBind"
    static Version := "4.0"
}

Join(arr, sep := ", ") {
    out := ""
    for i, v in arr
        out .= (i > 1 ? sep : "") v
    return out
}
