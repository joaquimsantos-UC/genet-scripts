# ============================================================
# exportar_registo.ps1  |  GeneT - Exportar Registo do PC
# Envia registo para Google Sheet via Google Forms
# ============================================================

# ── Configuracao do Google Form ────────────────────────────────
$FormUrl               = "https://docs.google.com/forms/d/e/1FAIpQLScNeg6Ksdp3yGnVriBDtfbzM21o064n8cjLbPdVLSq48ePtSg/formResponse"
$entry_Nome_PC         = "entry.1096512323"
$entry_No_Serie        = "entry.1107045509"
$entry_Modelo          = "entry.1619347434"
$entry_MAC_Address     = "entry.1161066532"
$entry_Utilizador      = "entry.432592008"
$entry_ID_AnyDesk      = "entry.733110054"
$entry_Chave_BitLocker = "entry.965104426"
$entry_Data            = "entry.953842874"

# ── Recolher informacao ────────────────────────────────────────
$NomePc   = $env:COMPUTERNAME
$NumSerie = (Get-WmiObject Win32_BIOS).SerialNumber
$Modelo   = (Get-WmiObject Win32_ComputerSystem).Model
$MAC      = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).MacAddress
$DataHoje = Get-Date -Format "dd/MM/yyyy"

$chave = (Get-BitLockerVolume -MountPoint "C:").KeyProtector |
    Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" } |
    Select-Object -ExpandProperty RecoveryPassword
if (-not $chave) { $chave = "PENDENTE - verificar manualmente" }

$anydeskId = ""
try {
    $anydeskId = Get-Content "$env:PROGRAMDATA\AnyDesk\system.conf" -ErrorAction Stop |
        Select-String "ad.anynet.id" |
        ForEach-Object { ($_ -split "=")[1].Trim() }
} catch {}
if (-not $anydeskId) { $anydeskId = "verificar manualmente" }

$utilizador = Get-LocalUser |
    Where-Object {
        $_.Enabled -eq $true -and
        $_.Name -notin @("Administrator","Administrador","DefaultAccount","Guest","WDAGUtilityAccount")
    } |
    Select-Object -ExpandProperty Name |
    Select-Object -First 1
if (-not $utilizador) { $utilizador = "por atribuir" }

# ── Mostrar resumo ─────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GeneT - Exportar Registo               " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " PC:          $NomePc"     -ForegroundColor White
Write-Host " No Serie:    $NumSerie"   -ForegroundColor White
Write-Host " Modelo:      $Modelo"     -ForegroundColor White
Write-Host " MAC:         $MAC"        -ForegroundColor White
Write-Host " Utilizador:  $utilizador" -ForegroundColor White
Write-Host " AnyDesk ID:  $anydeskId"  -ForegroundColor White
Write-Host " BitLocker:   $chave"      -ForegroundColor Yellow
Write-Host ""

# ── Enviar para Google Forms ───────────────────────────────────
Write-Host " A enviar registo..." -ForegroundColor Yellow

$body = @{
    $entry_Nome_PC         = $NomePc
    $entry_No_Serie        = $NumSerie
    $entry_Modelo          = $Modelo
    $entry_MAC_Address     = $MAC
    $entry_Utilizador      = $utilizador
    $entry_ID_AnyDesk      = $anydeskId
    $entry_Chave_BitLocker = $chave
    $entry_Data            = $DataHoje
}

# ── Enviar para Google Forms ───────────────────────────────────
Write-Host " A enviar registo..." -ForegroundColor Yellow

$formData = "entry.1096512323={0}&entry.1107045509={1}&entry.1619347434={2}&entry.1161066532={3}&entry.432592008={4}&entry.733110054={5}&entry.965104426={6}&entry.953842874={7}" -f `
    [Uri]::EscapeDataString($NomePc),
    [Uri]::EscapeDataString($NumSerie),
    [Uri]::EscapeDataString($Modelo),
    [Uri]::EscapeDataString($MAC),
    [Uri]::EscapeDataString($utilizador),
    [Uri]::EscapeDataString($anydeskId),
    [Uri]::EscapeDataString($chave),
    [Uri]::EscapeDataString($DataHoje)

$resultado = & curl.exe -s -o NUL -w "%{http_code}" -X POST -d $formData $FormUrl 2>$null

if ($resultado -match "^[23]") {
    Write-Host ""
    Write-Host " Registo enviado com sucesso!" -ForegroundColor Green
    Write-Host " Ver em: https://docs.google.com/spreadsheets/d/17K9hNQGHgFMGAkdn62PEDGVfPC2DLQ4W5lryOF7bZDw" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host ""
    Write-Host " ERRO ao enviar (HTTP $resultado)" -ForegroundColor Red
    Write-Host ""
}
