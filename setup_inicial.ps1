# ============================================================
# setup_inicial.ps1
# Fase 1 - Configuracao inicial (sem utilizador definido)
# Uso: .\setup_inicial.ps1 -Numero 1
# ============================================================
param(
    [Parameter(Mandatory=$true)]
    [int]$Numero
)

$NomePc = "GeneT-LT-{0:D3}" -f $Numero
$UpdateURL = "https://raw.githubusercontent.com/joaquimsantos-UC/genet-scripts/refs/heads/main/update.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GeneT Setup - Fase 1: Configuracao inicial" -ForegroundColor Cyan
Write-Host " PC: $NomePc" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Renomear PC ───────────────────────────────────────────
Write-Host "[1/9] A renomear PC para $NomePc..." -ForegroundColor Yellow
Rename-Computer -NewName $NomePc -Force

# ── 2. Configuracoes de sistema ──────────────────────────────
Write-Host "[2/9] A aplicar configuracoes de sistema..." -ForegroundColor Yellow
Set-TimeZone -Id "GMT Standard Time"
try { Set-WinUILanguageOverride -Language pt-PT } catch {}
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
net user guest /active:no | Out-Null
$AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
$AUSettings.NotificationLevel = 4
$AUSettings.Save()

# ── 3. Instalar software base ─────────────────────────────────
Write-Host "[3/9] A instalar software..." -ForegroundColor Yellow
$apps = @(
    "Google.Chrome",
    "Mozilla.Firefox",
    "VideoLAN.VLC",
    "7zip.7zip",
    "Adobe.Acrobat.Reader.64-bit",
    "AnyDesk.AnyDesk",
    "IRISTeam.CartaodeCidadao"
)
foreach ($app in $apps) {
    Write-Host "  -> A instalar $app..." -ForegroundColor Gray
    winget install $app --silent --accept-package-agreements --accept-source-agreements 2>$null
}

# ── 4. Atualizacoes ───────────────────────────────────────────
Write-Host "[4/9] A atualizar Windows e software..." -ForegroundColor Yellow
winget upgrade --all --silent --accept-package-agreements 2>$null

# ── 5. Ativar BitLocker ───────────────────────────────────────
Write-Host "[5/9] A ativar BitLocker..." -ForegroundColor Yellow
$tpm = Get-Tpm
if ($tpm.TpmPresent -and $tpm.TpmReady) {
    Enable-BitLocker -MountPoint "C:" -EncryptionMethod Aes256 -TpmProtector -UsedSpaceOnly
    Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
} else {
    Write-Host "  AVISO: TPM nao disponivel - BitLocker ativado com password" -ForegroundColor Red
    $secPass = Read-Host "  Define password BitLocker" -AsSecureString
    Enable-BitLocker -MountPoint "C:" -EncryptionMethod Aes256 -PasswordProtector -Password $secPass
}

# ── 6. Exportar chave BitLocker ───────────────────────────────
Write-Host "[6/9] A exportar chave BitLocker..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$chave = (Get-BitLockerVolume -MountPoint "C:").KeyProtector |
    Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" } |
    Select-Object -ExpandProperty RecoveryPassword

if (-not $chave) { $chave = "PENDENTE - verificar manualmente" }

# ── 7. Gravar URL de atualizacao remota ──────────────────────
Write-Host "[7/9] A configurar atualizacao remota..." -ForegroundColor Yellow
[System.Environment]::SetEnvironmentVariable("GENET_UPDATE_URL", $UpdateURL, "Machine")
New-Item -ItemType Directory -Path "C:\GeneT" -Force | Out-Null

# ── 8. Criar tarefa agendada ──────────────────────────────────
Write-Host "[8/9] A criar tarefa agendada..." -ForegroundColor Yellow

$scriptContent = @'
$url = [System.Environment]::GetEnvironmentVariable('GENET_UPDATE_URL', 'Machine')
try {
    $conteudo = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    Invoke-Expression $conteudo
    $log = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - OK'
    $log | Out-File 'C:\GeneT\update.log' -Append
} catch {
    $log = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - ERRO: ' + $_.Exception.Message
    $log | Out-File 'C:\GeneT\update.log' -Append
}
'@

$scriptContent | Out-File "C:\GeneT\run_update.ps1" -Encoding UTF8

$action   = New-ScheduledTaskAction -Execute "PowerShell.exe" `
              -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\GeneT\run_update.ps1"
$trigger  = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 1) `
              -Once -At (Get-Date)
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfIdle -IdleDuration 00:10:00 `
              -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName "GeneT-Update" `
    -Action $action -Trigger $trigger -Settings $settings `
    -RunLevel Highest -Force | Out-Null

# ── 9. Guardar registo local ──────────────────────────────────
Write-Host "[9/9] A guardar registo..." -ForegroundColor Yellow
$NumSerie = (Get-WmiObject Win32_BIOS).SerialNumber
$Modelo   = (Get-WmiObject Win32_ComputerSystem).Model
$MAC      = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).MacAddress
$DataConf = Get-Date -Format "dd/MM/yyyy"
$linha = "$NomePc,$NumSerie,$Modelo,$MAC,$DataConf,,$chave,,,,,,,Configurado,"
$linha | Out-File "C:\GeneT\registo.csv" -Append -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " CONCLUIDO!" -ForegroundColor Green
Write-Host " PC:       $NomePc" -ForegroundColor Green
Write-Host " N Serie:  $NumSerie" -ForegroundColor Green
Write-Host " Chave BitLocker:" -ForegroundColor Green
Write-Host " $chave" -ForegroundColor Yellow
Write-Host " GUARDA ESTA CHAVE NO EXCEL ANTES DE CONTINUAR!" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Read-Host "Pressiona Enter para reiniciar o PC"
Restart-Computer -Force
