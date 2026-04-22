# ============================================================
# start.ps1 — GeneT Menu de Configuração
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
    Write-Host "   GeneT — Menu de Configuração" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [1] Fase 1 — Configuração inicial" -ForegroundColor White
    Write-Host " [2] Fase 2 — Criar utilizador" -ForegroundColor White
    Write-Host " [3] Atualizar todo o software" -ForegroundColor White
    Write-Host " [4] Ver log de atualizações remotas" -ForegroundColor White
    Write-Host " [0] Sair" -ForegroundColor Gray
    Write-Host ""
    $opcao = Read-Host "Escolhe uma opção"

    switch ($opcao) {

        "1" {
            $num = Read-Host "Número do PC (ex: 1 para GeneT-LT-001)"
            Download-And-Run "setup_inicial.ps1" "-Numero $num"
        }

        "2" {
            $num  = Read-Host "Número do PC (ex: 1 para GeneT-LT-001)"
            $user = Read-Host "Nome do utilizador (ex: joao.silva)"
            Download-And-Run "setup_utilizador.ps1" "-Numero $num -NomeUtilizador $user"
        }

        "3" {
            Write-Host "`nA atualizar todo o software..." -ForegroundColor Yellow
            winget upgrade --all --silent --accept-package-agreements
            Write-Host "✅ Concluído!" -ForegroundColor Green
            Read-Host "`nPressiona Enter para continuar"
        }

        "4" {
            if (Test-Path "C:\GeneT\update.log") {
                Write-Host "`n--- Log de atualizações remotas ---" -ForegroundColor Cyan
                Get-Content "C:\GeneT\update.log" | Select-Object -Last 20
            } else {
                Write-Host "`n⚠️  Ainda não há registos de atualização." -ForegroundColor Yellow
            }
            Read-Host "`nPressiona Enter para continuar"
        }

        "0" {
            Write-Host "`nSaindo..." -ForegroundColor Gray
        }

        default {
            Write-Host "`n⚠️  Opção inválida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }

} while ($opcao -ne "0")
