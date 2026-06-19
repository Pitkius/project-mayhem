# Nukopijuoja Guardian fivem-webhooks-*.lua -> server_logs/webhooks.lua
$root = Split-Path $PSScriptRoot -Parent
$srcDir = Join-Path $root 'discord-system\guardian-bot\data'
$dst = Join-Path $root 'resources\[local]\server_logs\webhooks.lua'

$src = Get-ChildItem -Path $srcDir -Filter 'fivem-webhooks-*.lua' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $src) {
    Write-Error "Nerastas fivem-webhooks-*.lua. Paleisk: cd discord-system/guardian-bot && npm run setup:logs"
    exit 1
}

Copy-Item -Path $src.FullName -Destination $dst -Force
Write-Host "Sinchronizuota: $($src.Name) -> webhooks.lua"
