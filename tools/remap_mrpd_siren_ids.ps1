$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\resources\[cars]\mrp_pd_mrpd\data')
)
$sharedPath = Join-Path $root '_shared\carcols.meta'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $root)) {
    throw "Data folder not found: $root"
}

$lightBlocks = [System.Collections.Generic.List[string]]::new()
$sirenBlocks = [System.Collections.Generic.List[string]]::new()

1..16 | ForEach-Object {
    $n = $_
    $sirenId = 59 + $n # 60..75: free and below the vanilla 255-slot limit
    $dir = Join-Path $root "mrpd$n"
    $sourcePath = Join-Path $dir 'carcols.meta'
    $variationsPath = Join-Path $dir 'carvariations.meta'
    $vehiclesPath = Join-Path $dir 'vehicles.meta'

    $source = [System.IO.File]::ReadAllText($sourcePath)
    $lightsMatch = [regex]::Match($source, '(?s)<Lights>\s*(.*?)\s*</Lights>')
    $sourceLightCount = 0
    if ($lightsMatch.Success -and $lightsMatch.Groups[1].Value -match '<Item>') {
        $lightBlock = $lightsMatch.Groups[1].Value.Trim()
        $sourceLightCount = 1
        if ($n -eq 4) {
            # Original mrpd4 reused 203 for both Lights and Sirens.
            $lightBlock = [regex]::Replace(
                $lightBlock,
                '<id value="\d+"\s*/>',
                '<id value="232"/>',
                1
            )
        }
        $lightBlocks.Add($lightBlock)
    }

    $sirensMatch = [regex]::Match($source, '(?s)<Sirens>\s*(.*?)\s*</Sirens>')
    if (-not $sirensMatch.Success) {
        throw "mrpd$n has no Sirens block."
    }
    $sirenBlock = $sirensMatch.Groups[1].Value.Trim()
    $sirenBlock = [regex]::Replace(
        $sirenBlock,
        '<id value="\d+"\s*/>',
        "<id value=`"$sirenId`"/>",
        1
    )
    $sirenBlock = [regex]::Replace(
        $sirenBlock,
        '<name>[^<]*</name>',
        "<name>mrpd$n</name>",
        1
    )
    $sirenBlock = $sirenBlock -replace '<sequencer value=""\s*/>', '<sequencer value="0"/>'
    $sirenBlocks.Add($sirenBlock)

    $variations = [System.IO.File]::ReadAllText($variationsPath)
    $variations = [regex]::Replace(
        $variations,
        'sirenSettings value="\d+"',
        "sirenSettings value=`"$sirenId`""
    )
    if ($n -eq 4) {
        $variations = [regex]::Replace(
            $variations,
            'lightSettings value="\d+"',
            'lightSettings value="232"'
        )
    }
    [System.IO.File]::WriteAllText($variationsPath, $variations, $utf8NoBom)

    # Emergency audio profile is required for native siren state. The original
    # mrpd13/14/16 files used civilian SCHAFTER/BALLER/SCHLAGEN profiles.
    $vehicles = [System.IO.File]::ReadAllText($vehiclesPath)
    $vehicles = [regex]::Replace(
        $vehicles,
        '<audioNameHash>[^<]*</audioNameHash>',
        '<audioNameHash>FBI</audioNameHash>'
    )
    [System.IO.File]::WriteAllText($vehiclesPath, $vehicles, $utf8NoBom)

    Write-Host "mrpd${n}: siren=$sirenId, lights=$sourceLightCount, audio=FBI"
}

$builder = [System.Text.StringBuilder]::new()
[void]$builder.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$builder.AppendLine('<CVehicleModelInfoVarGlobal>')
[void]$builder.AppendLine('  <Lights>')
foreach ($block in $lightBlocks) {
    [void]$builder.AppendLine($block)
}
[void]$builder.AppendLine('  </Lights>')
[void]$builder.AppendLine('  <Sirens>')
foreach ($block in $sirenBlocks) {
    [void]$builder.AppendLine($block)
}
[void]$builder.AppendLine('  </Sirens>')
[void]$builder.AppendLine('</CVehicleModelInfoVarGlobal>')
[System.IO.File]::WriteAllText($sharedPath, $builder.ToString(), $utf8NoBom)

[xml]$check = [System.IO.File]::ReadAllText($sharedPath)
if ($check.SelectNodes('//Sirens/Item').Count -ne 16) {
    throw 'Generated shared carcols does not contain 16 siren definitions.'
}
if ($check.SelectNodes('//Lights/Item').Count -ne 9) {
    throw 'Generated shared carcols does not contain 9 light definitions.'
}

Write-Host "Generated: $sharedPath"
