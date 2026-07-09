$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root 'resources\[cars]\mrp_pd_mrpd'

$mapping = [ordered]@{
    'gcpd20'  = 'mrpd1'
    'gcpd21'  = 'mrpd2'
    'gcpd22'  = 'mrpd3'
    'gcpd22bb'= 'mrpd3bb'
    'gcpd23'  = 'mrpd4'
    'gcapd1'  = 'mrpd5'
    'gcapd2'  = 'mrpd6'
    'gcapd3'  = 'mrpd7'
    'gcapd4'  = 'mrpd8'
    'gcapd5'  = 'mrpd9'
    'gcapd6'  = 'mrpd10'
    'gcapd10' = 'mrpd11'
    'gcapd11' = 'mrpd12'
}

$sources = @(
    (Join-Path $root 'resources\[cars]\mrp_pd_undercover'),
    (Join-Path $root 'resources\[cars]\mrp_pd_animuotu')
)

if (Test-Path -LiteralPath $dest) {
    Remove-Item -LiteralPath $dest -Recurse -Force
}

New-Item -ItemType Directory -Path (Join-Path $dest 'data') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dest 'stream') -Force | Out-Null

function Rename-InTextFile {
    param([string]$Path, [hashtable]$Map)
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach ($entry in $Map.GetEnumerator()) {
        $content = $content.Replace($entry.Key, $entry.Value)
    }
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

foreach ($src in $sources) {
    if (-not (Test-Path -LiteralPath $src)) {
        throw "Source pack not found: $src"
    }

    foreach ($entry in $mapping.GetEnumerator()) {
        $old = $entry.Key
        $new = $entry.Value

        $dataOld = Join-Path $src "data\$old"
        if (Test-Path -LiteralPath $dataOld) {
            $dataNew = Join-Path $dest "data\$new"
            Copy-Item -LiteralPath $dataOld -Destination $dataNew -Recurse -Force
            Get-ChildItem -LiteralPath $dataNew -Recurse -File | ForEach-Object {
                Rename-InTextFile -Path $_.FullName -Map $mapping
            }
        }

        $streamOld = Join-Path $src "stream\$old"
        if (Test-Path -LiteralPath $streamOld) {
            $streamNew = Join-Path $dest "stream\$new"
            Copy-Item -LiteralPath $streamOld -Destination $streamNew -Recurse -Force
            Get-ChildItem -LiteralPath $streamNew -Recurse -File | ForEach-Object {
                $newName = $_.Name.Replace($old, $new)
                if ($newName -ne $_.Name) {
                    Rename-Item -LiteralPath $_.FullName -NewName $newName
                }
            }
        }
    }
}

$fx = @"
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_pd_mrpd'
author 'MRP'
description 'Mission Row PD vehicle pack (MRPD 1-12)'
version '1.0.0'

files {
    'data/**/vehicles.meta',
    'data/**/carvariations.meta',
    'data/**/carcols.meta',
    'data/**/handling.meta',
    'data/**/vehiclelayouts.meta',
    'data/**/*.meta',
    'data/**/*.xml',
}

data_file 'HANDLING_FILE' 'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE' 'data/**/vehiclelayouts.meta'
data_file 'CONTENT_UNLOCKING_META_FILE' 'data/**/*unlocks.meta'
"@

Set-Content -LiteralPath (Join-Path $dest 'fxmanifest.lua') -Value $fx -Encoding UTF8
Write-Output "Created mrp_pd_mrpd with models: $($mapping.Values -join ', ')"
