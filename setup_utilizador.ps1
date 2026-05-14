# ============================================================
# setup_utilizador.ps1  |  GeneT - Fase 2: Criar Utilizador
# Uso: .\setup_utilizador.ps1 -NomeUtilizador "joao.silva"
# ============================================================
param(
    [string]$NomeUtilizador = ""
)

$NomePc = $env:COMPUTERNAME

if (-not $NomeUtilizador) {
    Write-Host "ERRO: Nome de utilizador nao fornecido." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GeneT Setup - Fase 2: Criar utilizador" -ForegroundColor Cyan
Write-Host " PC: $NomePc | Utilizador: $NomeUtilizador" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Criar conta ─────────────────────────────────────────────
Write-Host "[1/3] A criar conta '$NomeUtilizador'..." -ForegroundColor Yellow
$passwordTemp = ConvertTo-SecureString "GeneT@2025!" -AsPlainText -Force

New-LocalUser -Name $NomeUtilizador `
    -Password $passwordTemp `
    -FullName $NomeUtilizador `
    -Description "Utilizador GeneT"

$grupos = @("Utilizadores", "Users")
$adicionado = $false
foreach ($grupo in $grupos) {
    try {
        Add-LocalGroupMember -Group $grupo -Member $NomeUtilizador -ErrorAction Stop
        Write-Host "  Adicionado ao grupo '$grupo'" -ForegroundColor Gray
        $adicionado = $true
        break
    } catch {}
}
if (-not $adicionado) {
    Write-Host "  AVISO: Nao foi possivel adicionar ao grupo de utilizadores" -ForegroundColor Yellow
}

try {
    $userObj = [ADSI]"WinNT://$env:COMPUTERNAME/$NomeUtilizador,user"
    $userObj.PasswordExpired = 1
    $userObj.SetInfo()
    Write-Host "  Password expira no primeiro login" -ForegroundColor Gray
} catch {
    Write-Host "  AVISO: Nao foi possivel forcar mudanca de password" -ForegroundColor Yellow
}

# ── 2. ID AnyDesk ──────────────────────────────────────────────
Write-Host "[2/3] A obter ID AnyDesk..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$anydeskId = ""
try {
    $anydeskId = & "C:\Program Files (x86)\AnyDesk\AnyDesk.exe" --get-id 2>$null
    if (-not $anydeskId) {
        $anydeskId = Get-Content "$env:PROGRAMDATA\AnyDesk\system.conf" -ErrorAction SilentlyContinue |
            Select-String "ad.anynet.id" |
            ForEach-Object { ($_ -split "=")[1].Trim() }
    }
} catch {}

if ($anydeskId) {
    Write-Host "  ID AnyDesk: $anydeskId" -ForegroundColor Green
} else {
    $anydeskId = "verificar manualmente"
    Write-Host "  AVISO: Nao foi possivel obter ID AnyDesk" -ForegroundColor Red
}

# ── 3. Resumo ──────────────────────────────────────────────────
Write-Host "[3/3] A concluir..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " CONCLUIDO!" -ForegroundColor Green
Write-Host " PC:             $NomePc" -ForegroundColor Green
Write-Host " Utilizador:     $NomeUtilizador" -ForegroundColor Green
Write-Host " Password temp.: GeneT@2025!" -ForegroundColor Green
Write-Host " ID AnyDesk:     $anydeskId" -ForegroundColor Green
Write-Host " ATUALIZA O EXCEL COM ESTES DADOS!" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
