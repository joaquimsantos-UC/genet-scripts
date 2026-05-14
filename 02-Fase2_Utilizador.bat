@echo off
title GeneT - Fase 2: Criar Utilizador

net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

color 0B
echo.
echo ========================================
echo  GeneT - Fase 2: Criar Utilizador
echo ========================================
echo.
set /p user="Nome do utilizador (ex: joao.silva): "
echo.
echo A criar conta...
PowerShell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup_utilizador.ps1" -NomeUtilizador "%user%"
echo.
pause
