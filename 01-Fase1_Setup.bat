@echo off
title GeneT - Fase 1: Configuracao Inicial

net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

color 0B
echo.
echo ========================================
echo  GeneT - Fase 1: Configuracao Inicial
echo ========================================
echo.
set /p numero="Numero do PC (ex: 1 para GeneT-LT-001): "
echo.
echo A iniciar configuracao...
PowerShell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup_inicial.ps1" -Numero %numero%
echo.
echo ========================================
echo  PASSO FINAL: Configurar AnyDesk
echo ========================================
echo.
echo 1. Vai a Definicoes (icone engrenagem)
echo 2. Clica em Seguranca
echo 3. Em "Acesso autonomo" clica em "Definir password"
echo 4. Introduz a password de acesso remoto
echo 5. Fecha o AnyDesk
echo.
echo A abrir o AnyDesk...
start "" "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
echo.
pause
