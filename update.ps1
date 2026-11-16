# ============================================================
# update.ps1 - GeneT Remote Management
# Repository: github.com/joaquimsantos-UC/genet-scripts
#
# Runs as SYSTEM from C:\GeneT\run_update.ps1 (scheduled task "GeneT-Update",
# at startup and every 4 hours). It is downloaded as text and executed with
# Invoke-Expression, so KEEP THIS FILE ASCII-ONLY (no accents, no smart quotes).
#
# What it does on every run:
#   1. Locks down C:\GeneT (users can only read it, except C:\GeneT\user)
#   2. Repairs run_update.ps1 and the GeneT-Update scheduled task
#   3. Disables password expiry for local users
#   4. Syncs software: catalog (software.json) + each user's choices
#   4b. Network printers from the catalog (Sync-Printers)
#   5. Runs your own commands (function Invoke-CustomCommands, below)
# ============================================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$GeneTRoot    = 'C:\GeneT'
$UserDir      = 'C:\GeneT\user'
$CacheDir     = 'C:\GeneT\cache'
$LogFile      = 'C:\GeneT\update.log'
$CatalogFile  = 'C:\GeneT\software.json'
$StateFile    = 'C:\GeneT\software.state.json'
$LocalFile    = 'C:\GeneT\user\software.local.json'
$UiFile       = 'C:\GeneT\GeneT-Software.ps1'
$RepoRaw      = 'https://raw.githubusercontent.com/joaquimsantos-UC/genet-scripts/refs/heads/main'
$OkExitCodes  = @(0, 3010, 1641)

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
function Write-Log([string]$msg) {
    $line = (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' - ' + $msg
    try { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 } catch { }
}

function Limit-Log {
    try {
        if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length -gt 1MB)) {
            $tail = Get-Content -LiteralPath $LogFile -Tail 500
            Set-Content -LiteralPath $LogFile -Value $tail -Encoding UTF8
        }
    } catch { }
}

function Get-JsonFile([string]$path, [int]$maxBytes = 1048576) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        if ((Get-Item -LiteralPath $path).Length -gt $maxBytes) {
            Write-Log ('ignored (file too large): ' + $path)
            return $null
        }
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        return ($text | ConvertFrom-Json)
    } catch {
        Write-Log ('invalid JSON in ' + $path + ': ' + $_.Exception.Message)
        return $null
    }
}

function ConvertTo-Hash($obj) {
    $h = @{}
    if ($obj) {
        foreach ($p in $obj.PSObject.Properties) {
            $v = $p.Value
            if ($v -is [System.Management.Automation.PSCustomObject]) { $v = ConvertTo-Hash $v }
            $h[$p.Name] = $v
        }
    }
    return $h
}

function Save-Url([string]$url, [string]$dest) {
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        Write-Log ('download failed (' + $url + '): ' + $_.Exception.Message)
        return $false
    }
}

# Runs a process hidden, waits (with timeout) and returns the exit code.
# -1 = could not start, -2 = timeout (process killed).
function Invoke-Proc([string]$file, [string]$arguments, [int]$timeoutMin = 30) {
    $out = Join-Path $CacheDir 'proc.out'
    $err = Join-Path $CacheDir 'proc.err'
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    try {
        if ([string]::IsNullOrWhiteSpace($arguments)) {
            $p = Start-Process -FilePath $file -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -ErrorAction Stop
        } else {
            $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -ErrorAction Stop
        }
    } catch {
        Write-Log ('could not start ' + $file + ': ' + $_.Exception.Message)
        return -1
    }
    $null = $p.Handle
    if (-not $p.WaitForExit($timeoutMin * 60 * 1000)) {
        try { $p.Kill() } catch { }
        Write-Log ('timeout (' + $timeoutMin + ' min), process killed: ' + $file)
        return -2
    }
    return $p.ExitCode
}

function Write-ProcTail {
    try {
        $out = Join-Path $CacheDir 'proc.out'
        if (Test-Path -LiteralPath $out) {
            $tail = Get-Content -LiteralPath $out -Tail 4 -ErrorAction SilentlyContinue
            foreach ($l in $tail) { if ($l -and $l.Trim()) { Write-Log ('  > ' + $l.Trim()) } }
        }
    } catch { }
}

# ------------------------------------------------------------
# 1. Permissions: standard users must NOT be able to change anything
#    that SYSTEM executes. Only C:\GeneT\user is writable by users.
# ------------------------------------------------------------
function Set-GeneTAcl {
    New-Item -ItemType Directory -Path $GeneTRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $UserDir   -Force | Out-Null
    New-Item -ItemType Directory -Path $CacheDir  -Force | Out-Null
    & icacls.exe $GeneTRoot /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
    & icacls.exe $UserDir   /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)M'  | Out-Null
}

# ------------------------------------------------------------
# 2. Repair run_update.ps1 and the scheduled task
# ------------------------------------------------------------
function Repair-RunUpdate {
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
    $atual = Get-Content 'C:\GeneT\run_update.ps1' -Raw -ErrorAction SilentlyContinue
    if ($atual -notlike '*Encoding UTF8*') {
        $runUpdate | Out-File 'C:\GeneT\run_update.ps1' -Encoding UTF8 -Force
    }
}

function Repair-Task {
    $task = Get-ScheduledTask -TaskName 'GeneT-Update' -ErrorAction SilentlyContinue
    if (-not $task) { return }

    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -MultipleInstances IgnoreNew

    if ($task.Principal.LogonType -ne 'ServiceAccount') {
        # Run as SYSTEM (works without a logged-on user)
        $action    = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\GeneT\run_update.ps1'
        $trigger1  = New-ScheduledTaskTrigger -AtStartup
        $trigger2  = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 4) -Once -At (Get-Date)
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
        Register-ScheduledTask -TaskName 'GeneT-Update' -Action $action -Trigger @($trigger1, $trigger2) -Settings $settings -Principal $principal -Force | Out-Null
        Write-Log 'task GeneT-Update re-registered (SYSTEM)'
    }
    elseif (($task.Settings.ExecutionTimeLimit -ne 'PT2H') -or $task.Settings.DisallowStartIfOnBatteries -or $task.Settings.StopIfGoingOnBatteries) {
        # Long installs need more than 15 minutes; laptops must also run on battery
        Set-ScheduledTask -TaskName 'GeneT-Update' -Settings $settings | Out-Null
        Write-Log 'task GeneT-Update settings updated (2 h limit, runs on battery)'
    }
}

# ------------------------------------------------------------
# 3. Password expiry
# ------------------------------------------------------------
function Disable-PasswordExpiry {
    Get-LocalUser | Where-Object { $_.Enabled -eq $true -and $_.Name -notin @('Administrator', 'Administrador', 'DefaultAccount', 'Guest', 'WDAGUtilityAccount') } | ForEach-Object {
        if ($_.PasswordExpires) {
            Set-LocalUser -Name $_.Name -PasswordNeverExpires $true
            Write-Log ('Password never expires: ' + $_.Name)
        }
    }
}

# ------------------------------------------------------------
# 4. Software sync
# ------------------------------------------------------------
function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    try {
        $c = Get-ChildItem 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe' -ErrorAction SilentlyContinue |
            Sort-Object { [version]($_.Directory.Name -replace '^Microsoft\.DesktopAppInstaller_([\d\.]+)_.*$', '$1') } -Descending |
            Select-Object -First 1
        if ($c) { return $c.FullName }
    } catch { }
    return $null
}

function Get-ArpEntries {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    return @(Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName })
}

function Update-RepoFile([string]$name, [string]$dest, [scriptblock]$validate) {
    $tmp = Join-Path $CacheDir ($name + '.tmp')
    if (-not (Save-Url ($RepoRaw + '/' + $name) $tmp)) { return $false }
    $valid = $true
    if ($validate) { $valid = [bool](& $validate $tmp) }
    if (-not $valid) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Write-Log ('invalid file from repository, kept previous copy: ' + $name)
        return $false
    }
    Copy-Item -LiteralPath $tmp -Destination $dest -Force
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    return $true
}

function Set-UiShortcut {
    try {
        if (-not (Test-Path -LiteralPath $UiFile)) { return }
        $lnk = 'C:\Users\Public\Desktop\GeneT Software.lnk'
        if (Test-Path -LiteralPath $lnk) { return }
        $ws = New-Object -ComObject WScript.Shell
        $s  = $ws.CreateShortcut($lnk)
        $s.TargetPath   = (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')
        $s.Arguments    = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $UiFile + '"'
        $s.WorkingDirectory = $GeneTRoot
        $s.Description  = 'GeneT Software'
        $s.Save()
        Write-Log 'desktop shortcut created: GeneT Software'
    } catch {
        Write-Log ('could not create shortcut: ' + $_.Exception.Message)
    }
}

function Test-Installed($item) {
    if ($item.detect) {
        foreach ($e in $script:Arp) {
            if ($e.DisplayName -match $item.detect) { return $true }
        }
    }
    if ($item.source -eq 'winget' -and $script:Winget) {
        $rc = Invoke-Proc $script:Winget ('list --id ' + $item.wingetId + ' --exact --accept-source-agreements --disable-interactivity') 5
        if ($rc -eq 0) { return $true }
    }
    return $false
}

function Get-DefaultWanted($item) {
    if ($item.default -eq $true) { return $true }
    if ($item.defaultFor -and ($item.defaultFor -contains $env:COMPUTERNAME)) { return $true }
    return $false
}

function Test-Backoff([string]$id, $item) {
    $f = $script:Fail[$id]
    if (-not $f) { return $false }
    if ([string]$f.ver -ne [string]$item.version) { return $false }
    if ([int]$f.tries -ge 3) { return $true }
    try { if (((Get-Date) - [datetime]$f.last).TotalHours -lt 6) { return $true } } catch { }
    return $false
}

function Install-Winget($item) {
    if (-not $script:Winget) { Write-Log ('winget not available, skipped: ' + $item.id); return $false }
    $common = ' --id ' + $item.wingetId + ' --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity'
    $rc = Invoke-Proc $script:Winget ('install' + $common + ' --scope machine') 30
    if ($rc -ne 0) {
        # some packages have no machine-wide installer
        $rc = Invoke-Proc $script:Winget ('install' + $common) 30
    }
    if ($rc -ne 0) { Write-Log ('winget install exit code ' + $rc + ': ' + $item.id); Write-ProcTail }
    return ($rc -eq 0)
}

function Install-Package($item) {
    $dir = Join-Path $CacheDir $item.id
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        # --- download -------------------------------------------------
        if ($item.source -eq 'drive') {
            $url   = $script:Catalog.driveUrl.Replace('{id}', [string]$item.driveId)
            $fname = [string]$item.file
        } else {
            $url   = [string]$item.url
            $fname = Split-Path $url -Leaf
        }
        $dest = Join-Path $dir $fname
        if (-not (Save-Url $url $dest)) { return $false }

        # --- integrity ------------------------------------------------
        if ($item.verify -eq 'signature') {
            $sig = Get-AuthenticodeSignature -LiteralPath $dest
            if ($sig.Status -ne 'Valid') {
                Write-Log ('signature NOT valid (' + $sig.Status + '), refused: ' + $item.id)
                return $false
            }
        } else {
            if ([string]::IsNullOrWhiteSpace([string]$item.sha256)) {
                Write-Log ('no sha256 in catalog, refused: ' + $item.id)
                return $false
            }
            $h = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower()
            if ($h -ne ([string]$item.sha256).ToLower()) {
                Write-Log ('sha256 MISMATCH, refused: ' + $item.id)
                return $false
            }
        }

        # --- extra files (e.g. JMP silent.iss) ---------------------------
        if ($item.extra) {
            foreach ($x in $item.extra) {
                $xurl  = $script:Catalog.driveUrl.Replace('{id}', [string]$x.driveId)
                $xdest = Join-Path $dir ([string]$x.file)
                if (-not (Save-Url $xurl $xdest)) { return $false }
                $xh = (Get-FileHash -LiteralPath $xdest -Algorithm SHA256).Hash.ToLower()
                if ([string]::IsNullOrWhiteSpace([string]$x.sha256) -or ($xh -ne ([string]$x.sha256).ToLower())) {
                    Write-Log ('extra file hash mismatch or missing, refused: ' + $item.id + '/' + $x.file)
                    return $false
                }
            }
        }

        # --- install --------------------------------------------------
        $instArgs = ([string]$item.installArgs).Replace('{dir}', $dir)
        switch ($item.type) {
            'msi' { $rc = Invoke-Proc 'msiexec.exe' ('/i "' + $dest + '" ' + $instArgs) 45 }
            'zip' {
                $xdir = Join-Path $dir 'x'
                Expand-Archive -LiteralPath $dest -DestinationPath $xdir -Force
                $rc = Invoke-Proc (Join-Path $xdir ([string]$item.inner)) $instArgs 45
            }
            default { $rc = Invoke-Proc $dest $instArgs 45 }
        }
        if ($OkExitCodes -contains $rc) { return $true }
        Write-Log ('installer exit code ' + $rc + ': ' + $item.id)
        Write-ProcTail
        return $false
    } catch {
        Write-Log ('install error ' + $item.id + ': ' + $_.Exception.Message)
        return $false
    } finally {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Item($item) {
    if ($item.source -eq 'winget') { return (Install-Winget $item) }
    return (Install-Package $item)
}

function Uninstall-Item($item) {
    if ($item.source -eq 'winget' -and $script:Winget) {
        $rc = Invoke-Proc $script:Winget ('uninstall --id ' + $item.wingetId + ' --exact --silent --accept-source-agreements --disable-interactivity') 30
        if ($rc -ne 0) { Write-Log ('winget uninstall exit code ' + $rc + ': ' + $item.id); Write-ProcTail }
        return ($rc -eq 0)
    }
    $entry = $null
    if ($item.detect) {
        foreach ($e in $script:Arp) { if ($e.DisplayName -match $item.detect) { $entry = $e; break } }
    }
    if (-not $entry) { return $false }
    $us = [string]$entry.UninstallString
    if ($us -match '\{[0-9A-Fa-f\-]{36}\}') {
        $rc = Invoke-Proc 'msiexec.exe' ('/x ' + $Matches[0] + ' /qn /norestart') 30
        return (@(0, 1605, 1641, 3010) -contains $rc)
    }
    if ($entry.QuietUninstallString) {
        $rc = Invoke-Proc 'cmd.exe' ('/c ' + [string]$entry.QuietUninstallString) 30
        return ($rc -eq 0)
    }
    Write-Log ('no silent uninstall available: ' + $item.id)
    return $false
}

function Sync-Software {
    $null = New-Item -ItemType Directory -Path $CacheDir -Force

    # --- refresh catalog and the user-facing window from the repository
    $okCat = Update-RepoFile 'software.json' $CatalogFile { param($p) $j = Get-JsonFile $p; return [bool]($j -and $j.software) }
    $null  = Update-RepoFile 'GeneT-Software.ps1' $UiFile { param($p) return [bool]((Get-Content -LiteralPath $p -Raw) -match 'System\.Windows\.Forms') }
    Set-UiShortcut

    $script:Catalog = Get-JsonFile $CatalogFile
    if (-not $script:Catalog -or -not $script:Catalog.software) {
        Write-Log 'software catalog not available - software sync skipped'
        return
    }
    $items = @($script:Catalog.software | Where-Object { $_.enabled -eq $true })
    $ids   = @($items | ForEach-Object { [string]$_.id })

    $script:Winget = Get-WingetPath
    if (-not $script:Winget) { Write-Log 'winget not found (winget items will be skipped)' }
    $script:Arp = Get-ArpEntries

    # --- previous state
    $old       = Get-JsonFile $StateFile
    $oldInst   = ConvertTo-Hash $(if ($old) { $old.installed } else { $null })
    $script:Fail = ConvertTo-Hash $(if ($old) { $old.failures } else { $null })
    $lastUpgrade = $null
    if ($old -and $old.lastUpgrade) { $lastUpgrade = [string]$old.lastUpgrade }

    # --- choices made by users (UNTRUSTED input: only known ids, only true/false)
    $choices = @{}
    $local = Get-JsonFile $LocalFile 65536
    if ($local -and $local.choices) {
        foreach ($p in $local.choices.PSObject.Properties) {
            if (($ids -contains $p.Name) -and ($p.Value -is [bool])) { $choices[$p.Name] = $p.Value }
        }
    }

    # winget upgrades at most once every 24 h
    $doUpgrade = $true
    if ($lastUpgrade) {
        try { if (((Get-Date) - [datetime]$lastUpgrade).TotalHours -lt 24) { $doUpgrade = $false } } catch { }
    }
    $upgradedNow = $false

    $newInst = @{}
    foreach ($item in $items) {
        $id        = [string]$item.id
        $installed = Test-Installed $item
        $hasChoice = $choices.ContainsKey($id)
        if ($hasChoice) { $want = [bool]$choices[$id] } else { $want = Get-DefaultWanted $item }

        $ourVersion = $null
        if ($oldInst.ContainsKey($id) -and $oldInst[$id]) { $ourVersion = [string]$oldInst[$id].version }

        if ($want -and -not $installed) {
            if (Test-Backoff $id $item) { continue }
            Write-Log ('installing: ' + $id)
            $ok = Install-Item $item
            $script:Arp = Get-ArpEntries
            $installed = Test-Installed $item
            if ($ok -and $installed) {
                Write-Log ('installed: ' + $id)
                $ourVersion = [string]$item.version
                $script:Fail.Remove($id)
            } else {
                $n = 1
                if ($script:Fail.ContainsKey($id) -and $script:Fail[$id]) { $n = [int]$script:Fail[$id].tries + 1 }
                $script:Fail[$id] = @{ tries = $n; last = (Get-Date).ToString('s'); ver = [string]$item.version }
                Write-Log ('install FAILED (' + $n + '): ' + $id)
            }
        }
        elseif ($want -and $installed) {
            if ($item.autoUpdate -eq $true) {
                if ($item.source -eq 'winget') {
                    if ($doUpgrade -and $script:Winget) {
                        $rc = Invoke-Proc $script:Winget ('upgrade --id ' + $item.wingetId + ' --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity') 30
                        $upgradedNow = $true
                        Write-Log ('winget upgrade ' + $id + ' -> exit ' + $rc)
                    }
                }
                elseif ((-not [string]::IsNullOrEmpty($ourVersion)) -and (-not [string]::IsNullOrWhiteSpace([string]$item.version)) -and ($ourVersion -ne [string]$item.version)) {
                    if (-not (Test-Backoff $id $item)) {
                        Write-Log ('updating ' + $id + ': ' + $ourVersion + ' -> ' + $item.version)
                        if (Install-Item $item) { $ourVersion = [string]$item.version } else {
                            $script:Fail[$id] = @{ tries = 1; last = (Get-Date).ToString('s'); ver = [string]$item.version }
                            Write-Log ('update FAILED: ' + $id)
                        }
                    }
                }
            }
        }
        elseif ((-not $want) -and $installed -and $hasChoice) {
            # only removed when the user explicitly unticked it
            if ($item.canUninstall -eq $true) {
                Write-Log ('uninstalling (user choice): ' + $id)
                if (Uninstall-Item $item) {
                    $script:Arp = Get-ArpEntries
                    $installed = Test-Installed $item
                    Write-Log ('uninstalled: ' + $id)
                } else { Write-Log ('uninstall FAILED: ' + $id) }
            } else {
                Write-Log ('uninstall not supported, ask IT: ' + $id)
            }
        }

        if ($installed) {
            if ($null -eq $ourVersion) { $ourVersion = '' }
            $newInst[$id] = @{ version = $ourVersion }
        }
    }

    # --- save state (read by the GeneT Software window)
    $stamp = $lastUpgrade
    if ($upgradedNow) { $stamp = (Get-Date).ToString('s') }
    $state = [ordered]@{
        updated     = (Get-Date).ToString('s')
        computer    = $env:COMPUTERNAME
        lastUpgrade = $stamp
        installed   = $newInst
        failures    = $script:Fail
    }
    try {
        $json = $state | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($StateFile, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch { Write-Log ('could not write state: ' + $_.Exception.Message) }
}

# ------------------------------------------------------------
# 5. Your own commands. Add them inside this function.
#    (This replaces the old "add commands below this line" area.)
# ------------------------------------------------------------
# ---------------------------------------------------------------------------
# Network printers (machine-wide: visible to every user of the laptop)
# Catalog section "printers": TCP/IP port + driver (driver zip on Drive, sha256 pinned)
# ---------------------------------------------------------------------------
function Sync-Printers {
    if (-not $script:Catalog -or -not $script:Catalog.printers) { return }
    foreach ($p in @($script:Catalog.printers | Where-Object { $_.enabled -eq $true })) {
        try {
            $name = [string]$p.name
            $ip   = [string]$p.ip
            if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { Write-Log ('printer: invalid IP, skipped: ' + $name); continue }
            $port = [int]$p.port
            if ($port -lt 1 -or $port -gt 65535) { $port = 9100 }

            # queue already there?
            if (Get-Printer -Name $name -ErrorAction SilentlyContinue) { continue }

            # driver present? if not, install it from the pinned zip
            $drv = [string]$p.driverName
            if (-not (Get-PrinterDriver -Name $drv -ErrorAction SilentlyContinue)) {
                $d = $p.driver
                if (-not $d -or [string]::IsNullOrWhiteSpace([string]$d.driveId) -or [string]::IsNullOrWhiteSpace([string]$d.sha256)) {
                    Write-Log ('printer: driver "' + $drv + '" missing and no driver package in catalog - skipped: ' + $name)
                    continue
                }
                $dir = Join-Path $CacheDir ('printer-' + [string]$p.id)
                Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                try {
                    $zip = Join-Path $dir ([string]$d.file)
                    $url = $script:Catalog.driveUrl.Replace('{id}', [string]$d.driveId)
                    if (-not (Save-Url $url $zip)) { continue }
                    $h = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
                    if ($h -ne ([string]$d.sha256).ToLower()) { Write-Log ('printer: driver sha256 MISMATCH, refused: ' + $name); continue }
                    $x = Join-Path $dir 'x'
                    Expand-Archive -LiteralPath $zip -DestinationPath $x -Force
                    $rc = Invoke-Proc 'pnputil.exe' ('/add-driver "' + $x + '\*.inf" /subdirs /install') 10
                    Write-Log ('printer: pnputil exit ' + $rc)
                    Add-PrinterDriver -Name $drv -ErrorAction Stop
                } finally {
                    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # port + queue
            if (-not (Get-PrinterPort -Name $ip -ErrorAction SilentlyContinue)) {
                Add-PrinterPort -Name $ip -PrinterHostAddress $ip -PortNumber $port -ErrorAction Stop
            }
            Add-Printer -Name $name -DriverName $drv -PortName $ip -ErrorAction Stop
            Write-Log ('printer installed: ' + $name)
        } catch {
            Write-Log ('printer error (' + $p.name + '): ' + $_.Exception.Message)
        }
    }
}

function Invoke-CustomCommands {

    # --- add commands below this line --------------------------------------


    # -----------------------------------------------------------------------
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
function Invoke-GeneTUpdate {
    $mutex = New-Object System.Threading.Mutex($false, 'Global\GeneTUpdate')
    $got = $false
    try { $got = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $got = $true }
    if (-not $got) { Write-Log 'another update is running - skipped'; return }
    try {
        Write-Log 'update.ps1 started'
        Set-GeneTAcl
        Limit-Log
        Repair-RunUpdate
        Repair-Task
        Disable-PasswordExpiry
        Sync-Software
        Sync-Printers
        Invoke-CustomCommands
        Write-Log 'update.ps1 finished'
    } finally {
        try { $mutex.ReleaseMutex() } catch { }
        $mutex.Dispose()
    }
}

Invoke-GeneTUpdate
