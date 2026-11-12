@echo off
start "" /min powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0quota-widget.ps1"
