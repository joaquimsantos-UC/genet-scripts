# ============================================================
# start.ps1 - GeneT Menu de Configuracao
# Uso: irm bit.ly/genet-setup | iex
# ============================================================

$BaseURL = "https://raw.githubusercontent.com/joaquimsantos-UC/genet-scripts/refs/heads/main"

function Download-And-Run {
    param([string]$script, [string]$args)
    $url = "$BaseURL/$script"
    $dest = "C:\GeneT\$script"
    New-Item -ItemType Directory -Path "C:\GeneT" -Force | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    & powershell.exe -ExecutionPolicy Bypass -File $dest $args
}

do {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   GeneT -- Menu de Configuracao" -ForegroundColor Cyan
    Write-Host "   PC: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [1] Fase 1 -- Configuracao inicial" -ForegroundColor White
    Write-Host " [2] Fase 2 -- Criar utilizador" -ForegroundColor White
    Write-Host " [3] Atualizar todo o software" -ForegroundColor White
    Write-Host " [4] Ver log de atualizacoes remotas" -ForegroundColor White
    Write-Host " [0] Sair" -ForegroundColor Gray
    Write-Host ""
    $opcao = Read-Host "Escolhe uma opcao"

    switch ($opcao) {

        "1" {
            $num = Read-Host "Numero do PC (ex: 1 para GeneT-LT-001)"
            Download-And-Run "setup_inicial.ps1" "-Numero $num"
        }

        "2" {
            $user = Read-Host "Nome do utilizador (ex: joao.silva)"
            Download-And-Run "setup_utilizador.ps1" "-NomeUtilizador $user"
        }

        "3" {
            Write-Host ""
            Write-Host "A atualizar todo o software..." -ForegroundColor Yellow
            winget upgrade --all --source winget --silent --accept-package-agreements
            Write-Host "Concluido!" -ForegroundColor Green
            Read-Host "Pressiona Enter para continuar"
        }

        "4" {
            if (Test-Path "C:\GeneT\update.log") {
                Write-Host ""
                Write-Host "--- Log de atualizacoes remotas ---" -ForegroundColor Cyan
                Get-Content "C:\GeneT\update.log" | Select-Object -Last 20
            } else {
                Write-Host ""
                Write-Host "Ainda nao ha registos de atualizacao." -ForegroundColor Yellow
            }
            Read-Host "Pressiona Enter para continuar"
        }

        "0" {
            Write-Host ""
            Write-Host "Saindo..." -ForegroundColor Gray
        }

        default {
            Write-Host ""
            Write-Host "Opcao invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }

} while ($opcao -ne "0")
