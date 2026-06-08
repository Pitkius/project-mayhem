# Atnaujina FiveM serverio artifacts (FXServer + txAdmin) Windows aplinkoje.
# NELIEČIA: resources/, cfg/, cache/, server.cfg, .git/
param(
    [string]$ServerRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$SevenZip = "C:\Program Files\7-Zip\7z.exe"
)

$ErrorActionPreference = "Stop"
$ArtifactsBase = "https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/"

Write-Host "=== FiveM artifacts atnaujinimas ===" -ForegroundColor Cyan
Write-Host "Serveris: $ServerRoot"

if (-not (Test-Path $SevenZip)) {
    throw "Nerastas 7-Zip: $SevenZip"
}

$fx = Get-Process -Name "FXServer" -ErrorAction SilentlyContinue
if ($fx) {
    throw "FXServer veikia (PID $($fx.Id)). Sustabdyk serverį per txAdmin ir paleisk skriptą iš naujo."
}

Write-Host "Gaunamas naujausias artifact build..."
$html = curl.exe -sL $ArtifactsBase
if ($LASTEXITCODE -ne 0 -or -not $html) {
    throw "Nepavyko atsisiųsti artifacts sąrašo."
}

# Pirmas „is-active“ build sąraše = naujausias stabilus
$match = [regex]::Match($html, 'panel-block\s+is-active[^>]*href="\./(\d+-[a-f0-9]+)/server\.7z"')
if (-not $match.Success) {
    $match = [regex]::Match($html, 'href="\./(\d+-[a-f0-9]+)/server\.7z"')
}
if (-not $match.Success) {
    throw "Nepavyko rasti artifact nuorodos HTML puslapyje."
}

$buildFolder = $match.Groups[1].Value
$buildNum = ($buildFolder -split '-')[0]
$downloadUrl = "$ArtifactsBase$buildFolder/server.7z"

Write-Host "Atsisiunčiamas build $buildNum ..."
$tmpDir = Join-Path $env:TEMP "fivem-artifact-$buildNum"
$archive = Join-Path $tmpDir "server.7z"
$extractDir = Join-Path $tmpDir "extracted"
if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
New-Item -ItemType Directory -Path $tmpDir | Out-Null

curl.exe -fL --progress-bar -o $archive $downloadUrl
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $archive)) {
    throw "Nepavyko atsisiųsti: $downloadUrl"
}

Write-Host "Išarchyvuojama..."
New-Item -ItemType Directory -Path $extractDir | Out-Null
& $SevenZip x $archive "-o$extractDir" -y | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "7z išarchyvavimo klaida."
}

# Artifact gali būti vienu lygiu arba server/ subfolderyje
$artifactRoot = $extractDir
if (Test-Path (Join-Path $extractDir "server\FXServer.exe")) {
    $artifactRoot = Join-Path $extractDir "server"
} elseif (-not (Test-Path (Join-Path $extractDir "FXServer.exe"))) {
    $found = Get-ChildItem -Path $extractDir -Filter "FXServer.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $artifactRoot = $found.DirectoryName }
    else { throw "FXServer.exe nerastas išarchyvuotame archive." }
}

Write-Host "Kopijuojami binary failai į $ServerRoot ..."
$excludeDirs = @('resources', 'cfg', 'cache', 'crashes', 'txData', '.git', 'node_modules', 'docs', 'scripts', 'tools')
$excludeFiles = @('server.cfg', '.gitignore', 'README.md')

Get-ChildItem -Path $artifactRoot -Force | ForEach-Object {
    if ($_.PSIsContainer) {
        if ($excludeDirs -contains $_.Name) { return }
        $dest = Join-Path $ServerRoot $_.Name
        Write-Host "  dir: $($_.Name)"
        robocopy $_.FullName $dest /MIR /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    } else {
        if ($excludeFiles -contains $_.Name) { return }
        Write-Host "  file: $($_.Name)"
        Copy-Item -Path $_.FullName -Destination (Join-Path $ServerRoot $_.Name) -Force
    }
}

Write-Host ""
Write-Host "Atnaujinta! Build $buildNum (txAdmin kartu su artifacts)." -ForegroundColor Green
Write-Host "Paleisk serverį per txAdmin ir patikrink, kad EOS įspėjimas dingo." -ForegroundColor Green

Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
