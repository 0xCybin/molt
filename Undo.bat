@echo off
REM Cybin Molt. restore the Windows auto install settings to their defaults.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Molt.ps1" -Undo
