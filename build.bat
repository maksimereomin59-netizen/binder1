@echo off
rem ============================================================
rem  MedBind - сборка / проверка сборки. Запуск двойным кликом.
rem
rem    build.bat                - пересобрать DoctorBinder.ahk из src\
rem    build.bat -Check         - проверить, что сборка актуальна (не менять файл)
rem    build.bat -Check -Compile- проверить + синтаксис через ahk2exe
rem ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
echo.
pause
