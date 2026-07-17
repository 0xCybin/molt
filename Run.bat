@echo off
REM Cybin Molt. double-click to scan, review, and clean. it will ask for admin (click Yes).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Molt.ps1" %*
