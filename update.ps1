# ============================================================
# update.ps1 - GeneT Remote Management
# Repositorio: github.com/joaquimsantos-UC/genet-scripts
#
# Edita este ficheiro para distribuir comandos a todos os PCs.
# Os PCs verificam e executam este script de hora em hora
# quando estiverem inativos.
# ============================================================

# Regista execucao no log local
$logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - update.ps1 executado'
$logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8

# ── Cartao de Cidadao ─────────────────────────────────────────
$instalado = Get-WmiObject -Class Win32_Product |
    Where-Object { $_.Name -like "*Autenticacao.gov*" -or $_.Name -like "*Cartao de Cidadao*" }

if (-not $instalado) {
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - A instalar Cartao de Cidadao...'
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8

    $url  = "https://aplicacoes.autenticacao.gov.pt/apps/Autenticacao.gov_Win_x64_signed.msi"
    $dest = "C:\GeneT\CartaoCidadao.msi"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i `"$dest`" /qn /norestart" -Wait
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
        $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - Cartao de Cidadao instalado com sucesso'
        $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
    } catch {
        $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - ERRO ao instalar Cartao de Cidadao: ' + $_.Exception.Message
        $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
    }
} else {
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - Cartao de Cidadao ja instalado - a saltar'
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
}

# ── Adiciona comandos abaixo desta linha ──────────────────────


# ─────────────────────────────────────────────────────────────
