# ============================================================
#  MedBind — сборка однофайловой сборки DoctorBinder.ahk из src/
#
#  Использование (из корня репозитория, двойным кликом по build.bat):
#    build.bat                   — пересобрать DoctorBinder.ahk из src/
#    build.bat -Check            — не менять файл, только проверить, что сборка актуальна
#    build.bat -Check -Compile   — проверить + прогнать синтаксис через ahk2exe
#
#  Сборка = BOM + src\_header.ahk + 14 модулей (в порядке ниже) + src\_footer.ahk
# ============================================================
param(
    [switch]$Check,    # не записывать файл, а сравнить текущий DoctorBinder.ahk со src/
    [switch]$Compile   # дополнительно проверить синтаксис компиляцией (нужен AutoHotkey)
)

$ErrorActionPreference = 'Stop'

$root    = $PSScriptRoot
$srcDir  = Join-Path $root 'src'
$outFile = Join-Path $root 'DoctorBinder.ahk'
$eq      = '=' * 20

# Порядок модулей — тот же, что и в сборке.
$modules = @(
    'App', 'Json', 'Store', 'Sender', 'Keys', 'Share',
    'Theme', 'Controls', 'Dialogs', 'Preview', 'Toast',
    'MainUI', 'Editor', 'SettingsUI'
)

# Чтение части: убирает BOM, выравнивает переводы строк в LF.
function Read-Part([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Файл не найден: $path"
    }
    $text = [System.IO.File]::ReadAllText($path)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    return $text
}

# ---------- сборка ----------
$parts = New-Object System.Collections.Generic.List[string]
$parts.Add(Read-Part (Join-Path $srcDir '_header.ahk'))

foreach ($name in $modules) {
    $text = Read-Part (Join-Path $srcDir ($name + '.ahk'))
    $text = $text.TrimEnd("`n") + "`n"        # ровно один перевод строки в конце
    $parts.Add("; $eq $name $eq`n")           # заголовок секции
    $parts.Add("`n")                          # пустая строка
    $parts.Add($text)
    $parts.Add("`n`n")                        # пустые строки перед следующей секцией
}
$parts.Add(Read-Part (Join-Path $srcDir '_footer.ahk'))

$built = (-join $parts).Replace("`n", "`r`n") # в итоговой сборке — CRLF
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$builtBytes = $utf8Bom.GetBytes($built)

# ---------- проверка / запись ----------
if ($Check) {
    if (-not (Test-Path -LiteralPath $outFile)) {
        Write-Host "DoctorBinder.ahk не найден. Сначала соберите: build.bat" -ForegroundColor Red
        exit 1
    }
    $curBytes = [System.IO.File]::ReadAllBytes($outFile)
    if ([Convert]::ToBase64String($builtBytes) -ceq [Convert]::ToBase64String($curBytes)) {
        Write-Host "OK: DoctorBinder.ahk совпадает со src/ побайтово — сборка актуальна." -ForegroundColor Green
    } else {
        Write-Host "РАСХОЖДЕНИЕ: DoctorBinder.ahk отличается от src/." -ForegroundColor Red
        Write-Host "Чтобы обновить сборку, выполните: build.bat" -ForegroundColor Yellow
        # показать первые различия по строкам
        $la = ([System.Text.Encoding]::UTF8.GetString($curBytes).Replace("`r`n", "`n")) -split "`n"
        $lb = $built.Replace("`r`n", "`n") -split "`n"
        $max = [Math]::Max($la.Count, $lb.Count)
        $diffs = 0
        for ($i = 0; $i -lt $max; $i++) {
            $a = if ($i -lt $la.Count) { $la[$i] } else { '(нет строки)' }
            $b = if ($i -lt $lb.Count) { $lb[$i] } else { '(нет строки)' }
            if ($a -cne $b) {
                $diffs++
                if ($diffs -le 5) {
                    Write-Host ("  строка {0}:" -f ($i + 1))
                    Write-Host ("    в сборке: {0}" -f $a)
                    Write-Host ("    в src:    {0}" -f $b)
                }
            }
        }
        Write-Host ("  Всего строк с различиями: {0}" -f $diffs)
        exit 1
    }
} else {
    [System.IO.File]::WriteAllBytes($outFile, $builtBytes)
    Write-Host ("OK: собрано из {0} модулей, {1:N0} КБ -> DoctorBinder.ahk" -f $modules.Count, ($builtBytes.Length / 1KB)) -ForegroundColor Green
    Write-Host "   Запуск: двойной клик по DoctorBinder.ahk"
}

# ---------- синтаксическая проверка (опционально) ----------
if ($Compile) {
    $ahk2exe = $null
    $cmd = Get-Command 'ahk2exe' -ErrorAction SilentlyContinue
    if ($cmd) { $ahk2exe = $cmd.Source }
    if (-not $ahk2exe) {
        foreach ($c in @(
            (Join-Path $env:ProgramFiles 'AutoHotkey\ahk2exe.exe'),
            (Join-Path $env:LOCALAPPDATA 'AutoHotkey\ahk2exe.exe'),
            (Join-Path $env:ProgramFiles 'AutoHotkey v2\ahk2exe.exe')
        )) {
            if (Test-Path -LiteralPath $c) { $ahk2exe = $c; break }
        }
    }
    if (-not $ahk2exe) {
        Write-Host "ahk2exe не найден — синтаксическая проверка пропущена." -ForegroundColor Yellow
        Write-Host "Установите AutoHotkey (https://www.autohotkey.com) и повторите: build.bat -Check -Compile"
    } else {
        $tmp = Join-Path $env:TEMP ('medbind_check_' + [guid]::NewGuid().ToString('N') + '.exe')
        Write-Host "Компиляция для проверки синтаксиса: $ahk2exe"
        & $ahk2exe '/in' $outFile '/out' $tmp | Out-Null
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $tmp)) {
            Write-Host "OK: синтаксических ошибок в сборке нет." -ForegroundColor Green
            Remove-Item -LiteralPath $tmp -Force
        } else {
            Write-Host "СИНТАКСИС: ahk2exe не смог собрать DoctorBinder.ahk (код $LASTEXITCODE)." -ForegroundColor Red
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            exit 1
        }
    }
}
