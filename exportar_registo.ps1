# ============================================================
# exportar_registo.ps1  |  GeneT - Exportar Registo do PC
# Envia registo para Google Sheet via Google Forms
# ============================================================

# ── Configuracao do Google Form ────────────────────────────────
$FormUrl = "https://docs.google.com/forms/d/e/1FAIpQLScNeg6Ksdp3yGnVriBDtfbzM21o064n8cjLbPdVLSq48ePtSg/formResponse"
$Fbzx    = "-4604633300964041180"

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

Add-Type -AssemblyName System.Web
function Encode($s) { [System.Web.HttpUtility]::UrlEncode([string]$s) }

$postData = "entry.1638171771=$(Encode $NomePc)" +
            "&entry.1817047519=$(Encode $NumSerie)" +
            "&entry.803403993=$(Encode $Modelo)" +
            "&entry.1448243464=$(Encode $MAC)" +
            "&entry.186649511=$(Encode $utilizador)" +
            "&entry.553911116=$(Encode $anydeskId)" +
            "&entry.1344745420=$(Encode $chave)" +
            "&entry.256400065=$(Encode $DataHoje)" +
            "&fvv=1" +
            "&fbzx=$Fbzx" +
            "&pageHistory=0" +
            "&partialResponse=%5Bnull%2Cnull%2C%22$Fbzx%22%5D" +
            "&submissionTimestamp=-1"

$resultado = & curl.exe -s -o NUL -w "%{http_code}" `
    -H "Content-Type: application/x-www-form-urlencoded" `
    -d $postData `
    $FormUrl 2>$null

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
