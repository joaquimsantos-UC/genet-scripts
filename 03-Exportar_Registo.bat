@echo off
title GeneT - Exportar Registo

net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

color 0B
echo.
echo ========================================
echo  GeneT - Exportar Registo do PC
echo ========================================
echo.
echo A recolher informacao do PC...
PowerShell -ExecutionPolicy Bypass -NoProfile -File "%~dp0exportar_registo.ps1"
echo.
pause
