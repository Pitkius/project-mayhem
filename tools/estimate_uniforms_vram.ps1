# Apytikslis stream/ dydis ir didziausi failai (PD + GMP uniformos)
param(
    [string]$Root = (Join-Path $PSScriptRoot "..")
)

$packs = @(
    "resources\[clothing]\mrp_pd_uniforms\stream",
    "resources\[clothing]\mrp_gmp_uniforms\stream"
)

Write-Host "`n=== Uniformu stream suvestine ===" -ForegroundColor Cyan

foreach ($rel in $packs) {
    $path = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "Nerasta: $rel" -ForegroundColor Yellow
        continue
    }
    $files = Get-ChildItem -LiteralPath $path -Recurse -File -Include *.ytd,*.ydd
    $sum = ($files | Measure-Object -Property Length -Sum).Sum
    $mb = [math]::Round($sum / 1MB, 1)
    Write-Host "`n$rel" -ForegroundColor Green
    Write-Host "  Failu: $($files.Count)  Diskas: $mb MB"
    Write-Host "  Top 8 (diskas):" -ForegroundColor DarkGray
    $files | Sort-Object Length -Descending | Select-Object -First 8 | ForEach-Object {
        $m = [math]::Round($_.Length / 1MB, 2)
        Write-Host ("    {0,7} MB  {1}" -f $m, $_.Name)
    }
}

Write-Host "`nPastaba: RAM gali buti 3-8x didesnis nei diskas (64 MB vienas .ytd)." -ForegroundColor Yellow
Write-Host "Optimizacija: resources/[clothing]/mrp_pd_uniforms/STREAMING.txt`n"
