$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vehFile = Join-Path $root 'resources\[qb]\qb-core\shared\vehicles_reh.lua'

$rehMax = @{
    '08srt8'=198; anniselegygt=288; annisr33=270; benefactorc63=258; benefactorc63gr=272; benefactorc63m=292
    benefactorcle53=268; benefactore63=268; benefactorg63=212; benefactorgle=215; benefactorgls=210
    benefactorrange=278; benefactors600=260; benefactors600b=270; benefactors63l=262; benefactors65=255
    benefactors87=278; benefactorspur=268; bfpologti=268; bravadobuffalo=275; bravadocharger08=255
    bravadocharger23=282; bravadodaytona=268; bravadodemon=270; bravadodemonsc=285; bravadodemonsc2=280
    bravadomagnum=258; bravadosrt392=240; bravadosuburban=198; bravadoz28=258; burgerfahrzeupassat=228
    canissrt8=205; caniswrangler=168; coilraiden=195; coquettec6=280; coquettec8=290; coquettec8a=290
    coquettezl1=285; coquettezr1=292; declasseimpala=198; dinkablista=188; dinkabooga=200; dinkacivic=192
    dinkansx=308; dinkawhip=268; grottibrioso=225; inveteroc7=288; inveterozr1=310; karimaxima=215
    karinaltima=205; karinascent=225; karincamry=210; karincorolla=198; karineclipse=210; karinelantra=215
    karingenesis=248; karink5gt=228; karinq50=200; karinrav4=185; karinsedan=250; karinsorento=198
    karinstinger=268; karinsupra=210; obeyttrs=268; ocelotintruder=235; ocelotvanquish=268; overflodjesko=198
    overflodjesko2=300; pegassiurus=200; pfister911=268; progen600=308; progenartura=310; ubermachtg20=268
    ubermachtm3cs=292; ubermachtm4=290; ubermachtm4gts=278; ubermachtm4q=268; ubermachtm5=290
    ubermachtsentinelk5=215; ubermachtx6m=263; ubermachtx7=218; vapiddurango=215; vapidfugitive=248
    vapidhawk=260; vapidsandkingdura=280; vapidstanier=198; vapidtrx=198; vapidtrxc=268
}

$hyper = @{ overflodjesko2=$true; progenartura=$true; progen600=$true; inveterozr1=$true; dinkansx=$true }

$catZ = @{
    compacts=11.2; sedans=8.8; suvs=10.8; coupes=7.2; muscle=5.4; sports=4.6; super=3.3; offroad=12.5
}
$catMult = @{
    compacts=0.78; sedans=0.90; suvs=0.94; coupes=0.96; muscle=0.92; sports=1.06; super=1.22; offroad=0.86
}
$zOverrides = @{
    bravadodemon=4.2; bravadodemonsc=3.9; bravadodemonsc2=4.0; bravadocharger23=4.8; ubermachtm5=3.8
    ubermachtm3cs=3.6; ubermachtm4=3.9; benefactorc63m=3.7; coquettec8=3.2; coquettec8a=3.2; coquettezr1=3.1
    inveteroc7=3.4; inveterozr1=3.0; progen600=2.9; progenartura=2.8; overflodjesko2=2.7; dinkansx=3.0
    dinkacivic=7.5; karincorolla=10.2; vapidstanier=11.0; caniswrangler=12.0
}
$tierBands = @{
    D=@{min=8000;max=55000}; C=@{min=45000;max=125000}; B=@{min=110000;max=245000}
    A=@{min=220000;max=520000}; S=@{min=480000;max=1200000}; X=@{min=3000000;max=4500000}
}

function Clamp-Num([double]$v, [double]$lo, [double]$hi) {
    if ($v -lt $lo) { return $lo }
    if ($v -gt $hi) { return $hi }
    return $v
}

function Get-Z100($model, $cat, $maxKmh) {
    if ($zOverrides.ContainsKey($model)) { return [double]$zOverrides[$model] }
    if ($hyper.ContainsKey($model)) { return 2.75 }
    $base = [double]$catZ[$cat]
    if ($maxKmh -gt 80) {
        $norm = Clamp-Num -v ($maxKmh / 240.0) -lo 0.55 -hi 1.35
        $base = $base / $norm
    }
    return Clamp-Num -v $base -lo 2.4 -hi 18.0
}

function Get-Tier($maxKmh, $z100, $isHyper) {
    if ($isHyper) { return 'X' }
    if ($maxKmh -ge 298 -or $z100 -le 3.2) { return 'S' }
    if ($maxKmh -ge 268 -or $z100 -le 4.6) { return 'A' }
    if ($maxKmh -ge 238 -or $z100 -le 6.8) { return 'B' }
    if ($maxKmh -ge 195 -or $z100 -le 9.8) { return 'C' }
    return 'D'
}

function Get-Price($model, $cat) {
    $maxKmh = [double]$rehMax[$model]
    $z100 = Get-Z100 $model $cat $maxKmh
    $isHyper = $hyper.ContainsKey($model)
    $speedNorm = Clamp-Num -v (($maxKmh - 140.0) / 170.0) -lo 0.0 -hi 1.15
    $accelNorm = Clamp-Num -v ((14.0 / $z100) - 0.5) -lo 0.2 -hi 5.5
    $price = 10000 + [math]::Pow($speedNorm, 2) * 400000 + [math]::Pow($accelNorm, 1.25) * 88000
    $price = $price * [double]$catMult[$cat]
    if ($isHyper) { $price = [math]::Max($price, 3000000) }
    $tier = Get-Tier $maxKmh $z100 $isHyper
    $band = $tierBands[$tier]
    $price = Clamp-Num -v $price -lo $band.min -hi $band.max
    $price = Clamp-Num -v $price -lo 8000 -hi 4500000
    return [int]([math]::Round($price / 500.0) * 500)
}

$lines = @('-- REH Rebadged Car Pack (auto-generated)', '-- Kainos sinchronizuotos su mrp_vehicle_perf (greitis + 0-100)', 'return {')
$entries = @()
foreach ($line in Get-Content -LiteralPath $vehFile) {
    if ($line -match "\{ model = '([^']+)', name = '((?:''|[^'])*)', brand = '((?:''|[^'])*)', price = \d+, category = '([^']+)'") {
        $entries += [pscustomobject]@{
            model = $matches[1]
            name = $matches[2] -replace "''", "'"
            brand = $matches[3] -replace "''", "'"
            category = $matches[4]
        }
    }
}

foreach ($e in $entries) {
    $price = Get-Price $e.model $e.category
    $lines += "    { model = '$($e.model)', name = '$($e.name)', brand = '$($e.brand)', price = $price, category = '$($e.category)', type = 'automobile', shop = 'pdm' },"
}
$lines += '}'

Set-Content -LiteralPath $vehFile -Value ($lines -join "`n") -Encoding UTF8
Write-Host "Updated $($entries.Count) REH vehicle prices in vehicles_reh.lua"
