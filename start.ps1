# ============================================================
# start.ps1  |  GeneT - Instalador de Scripts
# Entrada: irm bit.ly/genet-lt-setup | iex
# Descarrega todos os scripts do GitHub para C:\GeneT\scripts\
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "ERRO: Executa este script como Administrador." -ForegroundColor Red
    exit 1
}

$ZipUrl      = "https://github.com/joaquimsantos-UC/genet-scripts/archive/refs/heads/main.zip"
$ZipTemp     = "$env:TEMP\genet-scripts.zip"
$ScriptsPath = "C:\GeneT\scripts"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GeneT - A descarregar scripts...       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Descarregar ZIP ────────────────────────────────────────────
Write-Host " A descarregar do GitHub..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipTemp -UseBasicParsing
} catch {
    Write-Host " ERRO ao descarregar: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ── Extrair ────────────────────────────────────────────────────
Write-Host " A extrair ficheiros..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "C:\GeneT" -Force | Out-Null

if (Test-Path $ScriptsPath) {
    Remove-Item $ScriptsPath -Recurse -Force
}

Expand-Archive -Path $ZipTemp -DestinationPath "C:\GeneT" -Force

# O GitHub extrai para uma pasta com o nome "genet-scripts-main"
$subpasta = Get-ChildItem "C:\GeneT" -Directory |
    Where-Object { $_.Name -like "genet-scripts-*" } |
    Select-Object -First 1

if ($subpasta) {
    Rename-Item $subpasta.FullName $ScriptsPath
} else {
    Write-Host " ERRO: nao foi possivel encontrar a pasta extraida." -ForegroundColor Red
    exit 1
}

# ── Limpeza ────────────────────────────────────────────────────
Remove-Item $ZipTemp -Force

# ── Resultado ──────────────────────────────────────────────────
Write-Host ""
Write-Host " Scripts prontos em: $ScriptsPath" -ForegroundColor Green
Write-Host ""
Write-Host " A abrir pasta..." -ForegroundColor Yellow
Start-Process explorer.exe $ScriptsPath
