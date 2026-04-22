# ============================================================
# setup_utilizador.ps1
# Fase 2 - Criacao do utilizador (na entrega do PC)
# Uso: .\setup_utilizador.ps1 -NomeUtilizador "joao.silva"
# ============================================================
param(
    [Parameter(Mandatory=$true)]
    [string]$NomeUtilizador
)

# Deteta automaticamente o nome do PC
$NomePc = $env:COMPUTERNAME

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GeneT Setup - Fase 2: Criacao de utilizador" -ForegroundColor Cyan
Write-Host " PC: $NomePc | Utilizador: $NomeUtilizador" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Criar conta standard ───────────────────────────────────
Write-Host "[1/3] A criar conta '$NomeUtilizador'..." -ForegroundColor Yellow
$passwordTemp = ConvertTo-SecureString "GeneT@2025!" -AsPlainText -Force
New-LocalUser $NomeUtilizador `
    -Password $passwordTemp `
    -FullName $NomeUtilizador `
    -Description "Utilizador GeneT" `
    -PasswordNeverExpires $false
Add-LocalGroupMember -Group "Users" -Member $NomeUtilizador

# Forcar mudanca de password no primeiro login
$user = [ADSI]"WinNT://./$NomeUtilizador"
$user.PasswordExpired = 1
$user.SetInfo()

# ── 2. Obter ID AnyDesk ───────────────────────────────────────
Write-Host "[2/3] A obter ID AnyDesk..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$anydeskId = ""
try {
    $anydeskId = & "C:\Program Files (x86)\AnyDesk\AnyDesk.exe" --get-id 2>$null
    if (-not $anydeskId) {
        $anydeskId = Get-Content "$env:APPDATA\AnyDesk\system.conf" -ErrorAction SilentlyContinue |
            Select-String "ad.anynet.id" |
            ForEach-Object { ($_ -split "=")[1].Trim() }
    }
} catch {}

if ($anydeskId) {
    Write-Host "  ID AnyDesk: $anydeskId" -ForegroundColor Green
} else {
    $anydeskId = "verificar manualmente"
    Write-Host "  AVISO: Nao foi possivel obter ID -- verifica o AnyDesk manualmente" -ForegroundColor Red
}

# ── 3. Atualizar registo ──────────────────────────────────────
Write-Host "[3/3] A atualizar registo..." -ForegroundColor Yellow
$DataEntrega = Get-Date -Format "dd/MM/yyyy"
"ENTREGA,$NomePc,$NomeUtilizador,$anydeskId,$DataEntrega" |
    Out-File "C:\GeneT\registo.csv" -Append -Encoding UTF8

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
