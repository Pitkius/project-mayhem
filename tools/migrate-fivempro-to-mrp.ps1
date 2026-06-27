# Migracija: mrp_* resursai -> mrp_* (DB lenteliu mrp_* lieka)
$ErrorActionPreference = 'Stop'
$root = 'C:\Users\pytka\Desktop\FIVEMPROJEKTAS'

Write-Host '==> 1/4 Pervadinami resursu aplankai...'
$dirs = Get-ChildItem -Path "$root\resources" -Recurse -Directory |
    Where-Object { $_.Name -like 'mrp_*' } |
    Sort-Object { $_.FullName.Length } -Descending

foreach ($d in $dirs) {
    $newName = $d.Name -replace '^mrp_', 'mrp_'
    if ($d.Name -ne $newName) {
        $target = Join-Path $d.Parent.FullName $newName
        if (Test-Path -LiteralPath $target) {
            Write-Warning "Skip (exists): $target"
        } else {
            Rename-Item -LiteralPath $d.FullName -NewName $newName
            Write-Host "  $($d.Name) -> $newName"
        }
    }
}

$extensions = @('.lua', '.js', '.html', '.css', '.cfg', '.txt', '.md', '.mjs', '.ps1', '.bat', '.yml', '.json')
$skipDirs = @('\.git\', '\node_modules\', '\.cursor\')

Write-Host '==> 2/4 Tekstiniuose failuose: mrp_ -> mrp_ ...'
$files = Get-ChildItem -Path $root -Recurse -File | Where-Object {
    $extensions -contains $_.Extension.ToLower() -and
    $_.Extension -ne '.sql' -and
    $_.FullName -notmatch '\\\.git\\' -and
    $_.FullName -notmatch '\\node_modules\\' -and
    $_.FullName -notmatch '\\\.cursor\\'
}

foreach ($f in $files) {
    $raw = [System.IO.File]::ReadAllText($f.FullName)
    if ($raw -notmatch 'mrp_') { continue }

    $new = $raw -replace 'mrp_', 'mrp_'
    $new = $new -replace "author 'MRP'", "author 'MRP'"
    $new = $new -replace 'author "MRP"', 'author "MRP"'
    $new = $new -replace 'Custom MRP resources', 'Custom MRP resources'
    $new = $new -replace 'MRP serverio', 'MRP serverio'

    if ($new -ne $raw) {
        [System.IO.File]::WriteAllText($f.FullName, $new)
    }
}

Write-Host '==> 3/4 Atstatomos DB lenteliu nuorodos Lua failuose...'
$dbPrefixes = @(
    'phone_', 'gang_members', 'gang_turfs', 'gang_sales_logs', 'gang_warnings',
    'trucker_profiles', 'trucker_companies', 'trucker_company_members', 'trucker_fleet', 'trucker_delivery_log',
    'dispatch_logs', 'player_logs', 'property_ownership', 'service_invoices', 'char_presets',
    'ranger_fines', 'interrogation_kits', 'drugs_printers', 'phone_bank_accounts', 'phone_bank_transactions'
)

$luaFiles = Get-ChildItem -Path "$root\resources" -Recurse -File -Filter '*.lua'
foreach ($f in $luaFiles) {
    $raw = [System.IO.File]::ReadAllText($f.FullName)
    $new = $raw
    foreach ($p in $dbPrefixes) {
        $new = $new -replace "mrp_$p", "mrp_$p"
    }
    # Lentele mrp_gangs (ne resursas)
    $new = $new -replace '`mrp_gangs`', '`mrp_gangs`'
    $new = $new -replace 'FROM mrp_gangs\b', 'FROM mrp_gangs'
    $new = $new -replace 'JOIN mrp_gangs\b', 'JOIN mrp_gangs'
    $new = $new -replace 'INTO mrp_gangs\b', 'INTO mrp_gangs'
    $new = $new -replace 'UPDATE mrp_gangs\b', 'UPDATE mrp_gangs'
    $new = $new -replace 'ALTER TABLE `mrp_gangs`', 'ALTER TABLE `mrp_gangs`'
    $new = $new -replace 'mrp_gangs g\b', 'mrp_gangs g'
    $new = $new -replace 'mrp_gangs\.', 'mrp_gangs.'
    $new = $new -replace 'ux_mrp_gangs_', 'ux_mrp_gangs_'
    $new = $new -replace 'idx_mrp_gang_', 'idx_mrp_gang_'

    if ($new -ne $raw) {
        [System.IO.File]::WriteAllText($f.FullName, $new)
    }
}

Write-Host '==> 4/4 server.cfg ir cfg failai...'
foreach ($cfg in @("$root\server.cfg", "$root\cfg\00_base.cfg", "$root\cfg\20_qb.cfg", "$root\cfg\25_voice.cfg", "$root\cfg\30_custom.cfg")) {
    if (-not (Test-Path -LiteralPath $cfg)) { continue }
    $raw = [System.IO.File]::ReadAllText($cfg)
    $new = $raw -replace 'mrp_', 'mrp_'
    $new = $new -replace 'Custom FIVEMPRO', 'Custom MRP'
    if ($new -ne $raw) { [System.IO.File]::WriteAllText($cfg, $new) }
}

Write-Host 'Migracija baigta.'
