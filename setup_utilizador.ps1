# ============================================================
# setup_utilizador.ps1
# Fase 2 - Criacao do utilizador (na entrega do PC)
# Uso: .\setup_utilizador.ps1 -NomeUtilizador "joao.silva"
# ============================================================
param(
    [string]$NomeUtilizador = ""
)

$NomePc = $env:COMPUTERNAME

if (-not $NomeUtilizador) {
    Write-Host "ERRO: Nome de utilizador nao fornecido." -ForegroundColor Red
    Write-Host "Uso: .\setup_utilizador.ps1 -NomeUtilizador 'joao.silva'" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GeneT Setup - Fase 2: Criacao de utilizador" -ForegroundColor Cyan
Write-Host " PC: $NomePc | Utilizador: $NomeUtilizador" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Criar conta standard ───────────────────────────────────
Write-Host "[1/3] A criar conta '$NomeUtilizador'..." -ForegroundColor Yellow
$passwordTemp = ConvertTo-SecureString "GeneT@2025!" -AsPlainText -Force

New-LocalUser -Name $NomeUtilizador `
    -Password $passwordTemp `
    -FullName $NomeUtilizador `
    -Description "Utilizador GeneT"

# Adicionar ao grupo de utilizadores standard
# Tenta "Utilizadores" (PT) e "Users" (EN) para compatibilidade
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

# Forcar mudanca de password no primeiro login
try {
    $userObj = [ADSI]"WinNT://$env:COMPUTERNAME/$NomeUtilizador,user"
    $userObj.PasswordExpired = 1
    $userObj.SetInfo()
    Write-Host "  Password expirada -- utilizador tera de alterar no primeiro login" -ForegroundColor Gray
} catch {
    Write-Host "  AVISO: Nao foi possivel forcar mudanca de password" -ForegroundColor Yellow
}

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
