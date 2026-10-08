# MedBind 4.0

AutoHotkey v2 script with an HTML/WebView2 interface for managing bind sequences.

## Запуск в Windows

1. Установите **AutoHotkey v2** (рекомендуется x64).
2. Проверьте, что установлен **Microsoft Edge WebView2 Runtime**. Обычно он уже есть в Windows 11 и актуальных Windows 10; если его нет, установите Evergreen Runtime с [официальной страницы Microsoft](https://developer.microsoft.com/microsoft-edge/webview2/).
3. Распакуйте проект целиком и не отделяйте `lib` от `MedBind.ahk`.
4. Запустите `MedBind.ahk`. Текущий скрипт сам запрашивает права администратора.

Файлы `doctor_config.ini` и `ui.html` должны оставаться рядом со скриптом. Библиотеки AutoHotkey и загрузчик WebView2 уже включены в `lib`, поэтому отдельно скачивать их не нужно. В `ui.html` пока остаются внешние ссылки на Font Awesome и Google Fonts: без интернета приложение работает, но часть иконок и шрифт Inter могут не загрузиться.

## Структура `lib`

- `WebView2/WebView2.ahk` — обёртка WebView2 для AutoHotkey.
- `Promise.ahk`, `ComVar.ahk` — её обязательные зависимости.
- `WebView2/32bit` и `WebView2/64bit` — загрузчики для 32- и 64-битного AutoHotkey.
- `AHK2-LIB-LICENSE.txt` и `WebView2/README.md` — лицензия и сведения об исходной библиотеке.

Версия и источники зависимостей описаны в [`lib/README.md`](lib/README.md).