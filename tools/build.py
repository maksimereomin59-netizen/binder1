#!/usr/bin/env python3
"""Assemble the standalone AutoHotkey launcher from the source modules."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DoctorBinder.ahk"

# Keep this list in dependency order. The generated script is a single-file
# distribution, while the editable source stays grouped under src/.
MODULES = (
    ("App", "src/core/App.ahk"),
    ("Json", "src/core/Json.ahk"),
    ("Store", "src/core/Store.ahk"),
    ("Sender", "src/core/Sender.ahk"),
    ("Keys", "src/core/Keys.ahk"),
    ("Share", "src/core/Share.ahk"),
    ("Theme", "src/ui/Theme.ahk"),
    ("Controls", "src/ui/Controls.ahk"),
    ("Dialogs", "src/ui/Dialogs.ahk"),
    ("Preview", "src/ui/Preview.ahk"),
    ("Toast", "src/ui/Toast.ahk"),
    ("MainUI", "src/ui/MainUI.ahk"),
    ("Editor", "src/ui/Editor.ahk"),
    ("SettingsUI", "src/ui/SettingsUI.ahk"),
)

HEADER = '''#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWorkingDir(A_ScriptDir)
DetectHiddenWindows(true)
if InStr(A_ScriptDir, A_Temp) && InStr(A_ScriptDir, ".zip") {
    MsgBox("Распакуйте архив в обычную папку и запустите DoctorBinder.ahk оттуда — иначе бинды не сохранятся.", "MedBind", "Icon!")
    ExitApp()
}

; ============================================================
;  MedBind 4.0 - биндер для медиков GTA SAMP RP
;  Запуск: двойной клик по этому файлу (нужен AutoHotkey v2)
; ============================================================

'''

TRAILER = '''A_IconTip := App.Name " " App.Version
A_TrayMenu.Delete()
A_TrayMenu.Add("Открыть MedBind", (*) => MainUI.Show())
A_TrayMenu.Add("Вкл / выкл биндер", (*) => Keys.ToggleEnabled())
A_TrayMenu.Add()
A_TrayMenu.Add("Перезапустить", (*) => Reload())
A_TrayMenu.Add("Выход", (*) => ExitApp())
A_TrayMenu.Default := "Открыть MedBind"

try {
    Theme.Init()
    Store.Load()
    Keys.Apply()
    MainUI.Show()
} catch Error as err {
    msg := "Не удалось запустить MedBind:`n`n" err.Message "`n`nФайл: " err.File "`nСтрока: " err.Line
    try Dialogs.Alert("Ошибка запуска", msg, "error")
    catch
        MsgBox(msg, App.Name, "Iconx")
    ExitApp(1)
}
'''


def read_ahk_source(relative_path: str) -> str:
    """Read UTF-8 AHK source and normalize it for reproducible bundling."""
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8-sig")
    return text.replace("\r\n", "\n").replace("\r", "\n").strip("\n")


def render_bundle() -> str:
    """Return the complete launcher as text, including its UTF-8 BOM."""
    chunks = [HEADER]
    for name, relative_path in MODULES:
        source = read_ahk_source(relative_path)
        chunks.append(f"; ==================== {name} ====================\n\n")
        chunks.append(source)
        # Keep clear separation between concatenated modules.
        chunks.append("\n\n\n")
    chunks.append(TRAILER)
    return "\ufeff" + "".join(chunks)


def bundle_bytes() -> bytes:
    """Use Windows-friendly CRLF line endings in the distributable file."""
    return render_bundle().replace("\n", "\r\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Собрать DoctorBinder.ahk из модулей в папке src/."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="только проверить, что DoctorBinder.ahk соответствует исходникам",
    )
    args = parser.parse_args()

    try:
        expected = bundle_bytes()
    except OSError as error:
        print(f"Не удалось прочитать исходники: {error}", file=sys.stderr)
        return 1

    if args.check:
        try:
            actual = OUTPUT.read_bytes()
        except OSError as error:
            print(f"Не удалось прочитать {OUTPUT.name}: {error}", file=sys.stderr)
            return 1
        if actual != expected:
            print(
                "DoctorBinder.ahk устарел или отличается от исходников. "
                "Выполните: python tools/build.py",
                file=sys.stderr,
            )
            return 1
        print("OK: DoctorBinder.ahk собран из актуальных исходников.")
        return 0

    OUTPUT.write_bytes(expected)
    print(f"Сборка обновлена: {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
