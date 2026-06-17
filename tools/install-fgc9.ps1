# Išpakuoja f60129-FGC-9 archyvą į resources/[weapons]/ ir parodo weapons.meta hash.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$drop = Join-Path $PSScriptRoot 'weapon-drops'
$weaponsDir = Join-Path $root 'resources\[weapons]'

New-Item -ItemType Directory -Force -Path $drop, $weaponsDir | Out-Null

function Find-Archive {
    $names = @('*f60129*', '*FGC-9*', '*fgc9*', '*FGC9*')
    $paths = @($drop, $PSScriptRoot, (Join-Path $root 'tools'), (Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Desktop'))
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        foreach ($n in $names) {
            $hit = Get-ChildItem -LiteralPath $p -Filter $n -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { return $hit }
        }
    }
    return $null
}

function Find-7z {
    $candidates = @(
        "${env:ProgramFiles}\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        (Get-Command 7z -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    ) | Where-Object { $_ -and (Test-Path $_) }
    return $candidates | Select-Object -First 1
}

$archive = Find-Archive
if (-not $archive) {
    Write-Host ''
    Write-Host 'FGC-9 archyvas nerastas.' -ForegroundColor Yellow
    Write-Host "Padėk failą (pvz. f60129-FGC-9.rar) į: $drop"
    Write-Host 'Tada paleisk šį skriptą dar kartą.'
    exit 1
}

Write-Host "Rastas archyvas: $($archive.FullName)"

$seven = Find-7z
if (-not $seven) {
    Write-Host '7-Zip nerastas. Įdiek 7-Zip arba išpakuok ranka į resources\[weapons]\' -ForegroundColor Red
    exit 1
}

$staging = Join-Path $env:TEMP ('fgc9-install-' + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $staging | Out-Null
& $seven x $archive.FullName "-o$staging" -y | Out-Null

$manifest = Get-ChildItem -Path $staging -Recurse -Filter 'fxmanifest.lua' -ErrorAction SilentlyContinue | Select-Object -First 1
$resourceRoot = if ($manifest) { $manifest.Directory.FullName } else { $staging }

$destName = Split-Path $resourceRoot -Leaf
if ($destName -match '^(stream|data|meta)$') {
    $destName = 'fgc9'
}
$dest = Join-Path $weaponsDir $destName
if (Test-Path $dest) {
    Remove-Item -LiteralPath $dest -Recurse -Force
}
Move-Item -LiteralPath $resourceRoot -Destination $dest

$meta = Get-ChildItem -Path $dest -Recurse -Filter 'weapons.meta' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($meta) {
    $xml = Get-Content -LiteralPath $meta.FullName -Raw
    if ($xml -match '<Name>(WEAPON_[^<]+)</Name>') {
        $hash = $matches[1].ToLower()
        Write-Host ''
        Write-Host "weapons.meta hash: $($matches[1])" -ForegroundColor Green
        if ($hash -ne 'weapon_fgc9') {
            Write-Host "DĖMESIO: qb-core naudoja weapon_fgc9. Jei hash kitoks, atnaujink items.lua / weapons.lua." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host 'weapons.meta nerastas — patikrink ar archyvas turi FiveM addon failus.' -ForegroundColor Yellow
}

Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host "Įdiegta į: $dest"
Write-Host 'Serverio cfg jau turi: ensure [weapons]'
Write-Host 'Testas žaidime: /giveitem [id] weapon_fgc9 1'
