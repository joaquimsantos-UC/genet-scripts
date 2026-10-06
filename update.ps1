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

# ── Corrigir run_update.ps1 (encoding) ───────────────────────
$runUpdate = @'
$url = [System.Environment]::GetEnvironmentVariable('GENET_UPDATE_URL', 'Machine')
try {
    $conteudo = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    Invoke-Expression $conteudo
    ((Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - OK') | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
} catch {
    ((Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - ERRO: ' + $_.Exception.Message) | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
}
'@
$atual = Get-Content "C:\GeneT\run_update.ps1" -Raw -ErrorAction SilentlyContinue
if ($atual -notlike "*Encoding UTF8*") {
    $runUpdate | Out-File "C:\GeneT\run_update.ps1" -Encoding UTF8 -Force
}

# ── Corrigir tarefa agendada (executar como SYSTEM) ───────────
$task = Get-ScheduledTask -TaskName "GeneT-Update" -ErrorAction SilentlyContinue
if ($task -and $task.Principal.LogonType -ne "ServiceAccount") {
    $action    = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\GeneT\run_update.ps1"
    $trigger1  = New-ScheduledTaskTrigger -AtStartup
    $trigger2  = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 4) -Once -At (Get-Date)
    $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -RunOnlyIfNetworkAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
    Register-ScheduledTask -TaskName "GeneT-Update" -Action $action -Trigger @($trigger1, $trigger2) -Settings $settings -Principal $principal -Force | Out-Null
}

# ── Cartao de Cidadao ─────────────────────────────────────────
$instalado = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*Autenticacao.gov*" -or $_.DisplayName -like "*Cartao de Cidadao*" }

if (-not $instalado) {
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - A apresentar instalador Cartao de Cidadao...'
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
    $url  = "https://aplicacoes.autenticacao.gov.pt/apps/Autenticacao.gov_Win_x64_signed.msi"
    $dest = "C:\Windows\Temp\CartaoCidadao.msi"
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Start-Process $dest
} else {
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - Cartao de Cidadao ja instalado - a saltar'
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
}

# ── Adobe Acrobat Reader ──────────────────────────────────────
$instalado = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Where-Object { $_.DisplayName -like "*Adobe Acrobat*" }

if (-not $instalado) {
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - A instalar Adobe Acrobat Reader...'
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
    winget install Adobe.Acrobat.Reader.64-bit --source winget --silent --accept-package-agreements --accept-source-agreements 2>$null
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - Adobe Acrobat Reader instalado'
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
} else {
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - Adobe Acrobat Reader ja instalado - a saltar'
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
}

# ── Desativar expiração de password ──────────────────────────
Get-LocalUser | Where-Object { $_.Enabled -eq $true -and $_.Name -notin @("Administrator","Administrador","DefaultAccount","Guest","WDAGUtilityAccount") } | ForEach-Object {
    Set-LocalUser -Name $_.Name -PasswordNeverExpires $true
    $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - Password nunca expira: ' + $_.Name
    $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
}

# ── GraphPad Prism (PCs específicos) ─────────────────────────
$pcsGraphPad = @("GENET-LT-001","GENET-LT-006","GENET-LT-007","GENET-LT-008","GENET-LT-009","GENET-LT-010","GENET-LT-014","GENET-LT-015","GENET-LT-016","GENET-LT-017")

if ($pcsGraphPad -contains $env:COMPUTERNAME) {
    $instalado = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*GraphPad Prism*" }

    if (-not $instalado) {
        $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - A instalar GraphPad Prism...'
        $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
        $dest = "C:\Windows\Temp\InstallPrism11.msi"
        try {
            Invoke-WebRequest -Uri "https://cdn.graphpad.com/downloads/prism/11/InstallPrism11.msi" -OutFile $dest -UseBasicParsing
            $p = Start-Process msiexec.exe -ArgumentList "/i `"$dest`" /qn /norestart" -Wait -PassThru
            $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - GraphPad Prism - Exit code: ' + $p.ExitCode
            $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
        } catch {
            $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - ERRO GraphPad Prism: ' + $_.Exception.Message
            $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
        }
    } else {
        $logMsg = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - GraphPad Prism ja instalado - a saltar'
        $logMsg | Out-File 'C:\GeneT\update.log' -Append -Encoding UTF8
    }
}

# ── Adiciona comandos abaixo desta linha ──────────────────────


# ─────────────────────────────────────────────────────────────
