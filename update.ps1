# ============================================================
# update.ps1 — GeneT Remote Management
# Este ficheiro está em:
# https://github.com/joaquimsantos-UC/genet-scripts
#
# Edita este ficheiro para distribuir comandos a todos os PCs.
# Os PCs verificam e executam este script de hora em hora
# quando estiverem inativos.
#
# EXEMPLOS DE USO:
#
# Instalar software novo:
# winget install RustDesk.RustDesk --silent --accept-package-agreements
#
# Desinstalar software:
# winget uninstall AnyDesk.AnyDesk --silent
#
# Atualizar tudo:
# winget upgrade --all --silent
#
# Criar ficheiro de texto em todos os PCs:
# "mensagem" | Out-File "C:\GeneT\aviso.txt"
# ============================================================

# Regista execução no log local
"$(Get-Date -Format 'dd/MM/yyyy HH:mm') — update.ps1 executado" |
    Out-File "C:\GeneT\update.log" -Append -Encoding UTF8

# ── Adiciona os teus comandos abaixo desta linha ──────────────


# Verifica versão instalada vs versão disponível
$instalado = Get-WmiObject -Class Win32_Product | 
    Where-Object { $_.Name -like "*Autenticacao.gov*" }

$versaoInstalada = $instalado.Version  # ex: 3.13.0
$versaoAtual = "3.14.0"  # atualiza este valor quando sair nova versão

if (-not $instalado) {
    # Não está instalado - instala
    # ... bloco de instalação anterior
} elseif ($versaoInstalada -lt $versaoAtual) {
    # Está desatualizado - atualiza
    Write-Host "A atualizar Cartao de Cidadao de $versaoInstalada para $versaoAtual..."
    # ... bloco de instalação (o MSI trata da atualização automaticamente)
} else {
    Write-Host "Cartao de Cidadao esta atualizado ($versaoInstalada)."
}
