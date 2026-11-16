# ============================================================
# GeneT-Software.ps1 - GeneT: escolha de software neste computador
# Corre com o utilizador atual (nao precisa de administrador).
# Grava as escolhas em C:\GeneT\user\software.local.json; a tarefa
# "GeneT-Update" (SYSTEM) aplica-as na proxima sincronizacao (max. ~4 h).
# Ficheiro guardado em UTF-8 com BOM (acentos no Windows PowerShell 5.1).
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$CatalogFile = 'C:\GeneT\software.json'
$StateFile   = 'C:\GeneT\software.state.json'
$LocalFile   = 'C:\GeneT\user\software.local.json'
$Title       = 'GeneT Software'

function Show-Msg([string]$text, [string]$icon = 'Information') {
    [void][System.Windows.Forms.MessageBox]::Show($text, $Title, 'OK', $icon)
}

function Read-Json([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        return ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
    } catch { return $null }
}

# ------------------------------------------------------------
# Dados
# ------------------------------------------------------------
$catalog = Read-Json $CatalogFile
if (-not $catalog -or -not $catalog.software) {
    Show-Msg "A lista de software ainda não foi sincronizada neste computador.`nTenta novamente daqui a alguns minutos (com o computador ligado à Internet)." 'Warning'
    exit
}

$state = Read-Json $StateFile
$installed = @{}
if ($state -and $state.installed) {
    foreach ($p in $state.installed.PSObject.Properties) { $installed[$p.Name] = $true }
}
$failed = @{}
if ($state -and $state.failures) {
    foreach ($p in $state.failures.PSObject.Properties) { $failed[$p.Name] = $true }
}

$choices = @{}
$local = Read-Json $LocalFile
if ($local -and $local.choices) {
    foreach ($p in $local.choices.PSObject.Properties) {
        if ($p.Value -is [bool]) { $choices[$p.Name] = $p.Value }
    }
}

function Get-DefaultWanted($item) {
    if ($item.default -eq $true) { return $true }
    if ($item.defaultFor -and ($item.defaultFor -contains $env:COMPUTERNAME)) { return $true }
    return $false
}

$items    = @($catalog.software | Where-Object { $_.enabled -eq $true })
$baseline = @{}   # o que acontece se o utilizador nao fizer nenhuma escolha
$locked   = @{}   # instalado e sem remocao automatica: nao se pode desmarcar

# ------------------------------------------------------------
# Janela
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = $Title
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(760, 470)
$form.MinimumSize = New-Object System.Drawing.Size(640, 360)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(12, 10)
$lblInfo.Size = New-Object System.Drawing.Size(736, 58)
$lblInfo.Anchor = 'Top, Left, Right'
$lblInfo.Text = "Escolhe os programas que queres ter neste computador e carrega em Guardar. A instalação (ou remoção) é feita automaticamente em segundo plano, no máximo em cerca de 4 horas, com o computador ligado e com acesso à Internet. Os programas que exigem licença têm de ser ativados por ti depois de instalados."
$form.Controls.Add($lblInfo)

$lv = New-Object System.Windows.Forms.ListView
$lv.Location = New-Object System.Drawing.Point(12, 74)
$lv.Size = New-Object System.Drawing.Size(736, 334)
$lv.Anchor = 'Top, Bottom, Left, Right'
$lv.View = 'Details'
$lv.CheckBoxes = $true
$lv.FullRowSelect = $true
$lv.GridLines = $true
$lv.HideSelection = $false
$lv.MultiSelect = $false
[void]$lv.Columns.Add('Programa', 330)
[void]$lv.Columns.Add('Estado', 170)
[void]$lv.Columns.Add('Notas', 215)
$form.Controls.Add($lv)

$lblSync = New-Object System.Windows.Forms.Label
$lblSync.Location = New-Object System.Drawing.Point(12, 420)
$lblSync.Size = New-Object System.Drawing.Size(480, 36)
$lblSync.Anchor = 'Bottom, Left'
if ($state -and $state.updated) {
    $lblSync.Text = 'Última sincronização: ' + ([string]$state.updated).Replace('T', ' ')
} else {
    $lblSync.Text = 'Ainda sem sincronização neste computador.'
}
$form.Controls.Add($lblSync)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = 'Guardar'
$btnSave.Location = New-Object System.Drawing.Point(560, 424)
$btnSave.Size = New-Object System.Drawing.Size(90, 30)
$btnSave.Anchor = 'Bottom, Right'
$form.Controls.Add($btnSave)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = 'Fechar'
$btnClose.Location = New-Object System.Drawing.Point(658, 424)
$btnClose.Size = New-Object System.Drawing.Size(90, 30)
$btnClose.Anchor = 'Bottom, Right'
$form.Controls.Add($btnClose)
$form.CancelButton = $btnClose

# ------------------------------------------------------------
# Preencher a lista
# ------------------------------------------------------------
$script:loading = $true
foreach ($item in $items) {
    $id     = [string]$item.id
    $isInst = $installed.ContainsKey($id)
    $base   = ($isInst -or (Get-DefaultWanted $item))
    $baseline[$id] = $base

    if ($choices.ContainsKey($id)) { $checked = [bool]$choices[$id] } else { $checked = $base }
    if ($isInst -and ($item.canUninstall -ne $true)) { $locked[$id] = $true }

    if ($isInst -and $checked)          { $status = 'Instalado' }
    elseif ($isInst -and -not $checked) { $status = 'A remover (pendente)' }
    elseif ((-not $isInst) -and $checked -and $failed.ContainsKey($id)) { $status = 'Falhou - contacta o IT' }
    elseif ((-not $isInst) -and $checked) { $status = 'A instalar (pendente)' }
    else { $status = 'Não instalado' }

    $notes = @()
    if ($item.license -eq $true) { $notes += 'Requer licença/ativação' }
    if ($locked.ContainsKey($id)) { $notes += 'Remoção só pelo IT' }

    $li = New-Object System.Windows.Forms.ListViewItem([string]$item.name)
    [void]$li.SubItems.Add($status)
    [void]$li.SubItems.Add(($notes -join '; '))
    $li.Tag = $id
    $li.Checked = $checked
    [void]$lv.Items.Add($li)
}
$script:loading = $false

# Programas instalados sem remocao automatica ficam sempre marcados
$lv.Add_ItemCheck({
    param($sender, $e)
    if ($script:loading) { return }
    $id = [string]$sender.Items[$e.Index].Tag
    if ($locked.ContainsKey($id) -and ($e.NewValue -eq 'Unchecked')) { $e.NewValue = $e.CurrentValue }
})

# ------------------------------------------------------------
# Guardar
# ------------------------------------------------------------
$btnSave.Add_Click({
    try {
        $ch = [ordered]@{}
        foreach ($k in $choices.Keys) { $ch[$k] = [bool]$choices[$k] }
        foreach ($it in $lv.Items) {
            $id = [string]$it.Tag
            if (($it.Checked -ne $baseline[$id]) -or $choices.ContainsKey($id)) { $ch[$id] = [bool]$it.Checked }
        }
        $obj = [ordered]@{
            version = 1
            user    = $env:USERNAME
            saved   = (Get-Date).ToString('s')
            choices = $ch
        }
        $json = $obj | ConvertTo-Json -Depth 4
        [System.IO.File]::WriteAllText($LocalFile, $json, (New-Object System.Text.UTF8Encoding($false)))
        Show-Msg "Escolhas guardadas.`nSerão aplicadas na próxima sincronização automática (no máximo em cerca de 4 horas)."
        $form.Close()
    } catch {
        Show-Msg ("Não foi possível guardar as escolhas.`nContacta o IT (joaquim.santos@uc.pt).`n`n" + $_.Exception.Message) 'Error'
    }
})

$btnClose.Add_Click({ $form.Close() })

[void]$form.ShowDialog()
