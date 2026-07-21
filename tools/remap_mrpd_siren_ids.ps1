$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\resources\[cars]\mrp_pd_mrpd\data')
)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $root)) {
    throw "Data folder not found: $root"
}

$sirenIds = @{
    1 = 9431; 2 = 9432; 3 = 9435; 4 = 9412
    5 = 9436; 6 = 9783; 7 = 9437; 8 = 9438
    9 = 9439; 10 = 9440; 11 = 9441; 12 = 9413
    13 = 134; 14 = 445069; 15 = 1229; 16 = 4924
}
$lightIds = @{
    1 = 1; 2 = 1; 3 = 1; 4 = 2021
    5 = 2027; 6 = 2028; 7 = 2029; 8 = 2030
    9 = 2031; 10 = 2032; 11 = 2033; 12 = 2026
    13 = 1; 14 = 1; 15 = 1; 16 = 1
}

1..16 | ForEach-Object {
    $n = $_
    $sirenId = $sirenIds[$n]
    $lightId = $lightIds[$n]
    $dir = Join-Path $root "mrpd$n"
    $sourcePath = Join-Path $dir 'carcols.meta'
    $variationsPath = Join-Path $dir 'carvariations.meta'
    $vehiclesPath = Join-Path $dir 'vehicles.meta'

    $source = [System.IO.File]::ReadAllText($sourcePath)
    $source = [regex]::Replace(
        $source,
        '(?s)(<Sirens>.*?<id value=")\d+(")',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $match.Groups[1].Value + $sirenId + $match.Groups[2].Value
        },
        1
    )
    $source = [regex]::Replace(
        $source,
        '<name>[^<]*</name>',
        "<name>mrpd$n</name>",
        1
    )
    if ($lightId -ne 1) {
        $source = [regex]::Replace(
            $source,
            '(?s)(<Lights>.*?<id value=")\d+(")',
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($match)
                $match.Groups[1].Value + $lightId + $match.Groups[2].Value
            },
            1
        )
    }
    $source = $source -replace '<sequencer value=""\s*/>', '<sequencer value="0"/>'
    [System.IO.File]::WriteAllText($sourcePath, $source, $utf8NoBom)

    $variations = [System.IO.File]::ReadAllText($variationsPath)
    $variations = [regex]::Replace(
        $variations,
        'sirenSettings value="\d+"',
        "sirenSettings value=`"$sirenId`""
    )
    $variations = [regex]::Replace(
        $variations,
        'lightSettings value="\d+"',
        "lightSettings value=`"$lightId`""
    )
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

    [xml]$carcolsCheck = [System.IO.File]::ReadAllText($sourcePath)
    [xml]$variationsCheck = [System.IO.File]::ReadAllText($variationsPath)
    $actualSiren = [int]$carcolsCheck.SelectSingleNode('//Sirens/Item/id').value
    $actualVariationSiren = [int]$variationsCheck.SelectSingleNode(
        "//variationData/Item[modelName='mrpd$n']/sirenSettings"
    ).value
    if ($actualSiren -ne $sirenId -or $actualVariationSiren -ne $sirenId) {
        throw "mrpd$n siren linkage validation failed."
    }

    Write-Host "mrpd${n}: siren=$sirenId, light=$lightId, audio=FBI"
}
Write-Host 'All 16 per-model carcols files repaired and validated.'
