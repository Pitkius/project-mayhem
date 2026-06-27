# Rodo didžiausius .ytd/.ydd failus clothing resursuose
param(
    [string]$Root = (Join-Path $PSScriptRoot "..\resources\[clothing]")
)

Get-ChildItem -LiteralPath $Root -Recurse -Include *.ytd,*.ydd -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 40 @{
        N = 'MiB'; E = { [math]::Round($_.Length / 1MB, 2) }
    }, @{
        N = 'Resource'; E = { ($_.FullName -split '[\\/]mrp_[^\\/]+')[1].TrimStart('\') }
    }, Name, DirectoryName
