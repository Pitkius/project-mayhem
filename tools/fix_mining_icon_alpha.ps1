$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$imagesDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'resources\[qb]\qb-inventory\html\images'
if (-not (Test-Path -LiteralPath $imagesDir)) {
    throw "Images dir not found: $imagesDir"
}
$prefixes = @(
    'mining_pickaxe', 'stone', 'coal', 'gravel', 'ironore', 'copperore', 'aluminumore',
    'silverore', 'goldore', 'diamond', 'emerald', 'ruby', 'sapphire', 'mystery_ore', 'artifact'
)

function Get-CornerBg($bmp) {
    $pts = @(
        [System.Drawing.Point]::new(1, 1),
        [System.Drawing.Point]::new($bmp.Width - 2, 1),
        [System.Drawing.Point]::new(1, $bmp.Height - 2),
        [System.Drawing.Point]::new($bmp.Width - 2, $bmp.Height - 2)
    )
    $rs = 0; $gs = 0; $bs = 0
    foreach ($p in $pts) {
        $c = $bmp.GetPixel($p.X, $p.Y)
        $rs += $c.R; $gs += $c.G; $bs += $c.B
    }
    return @([int]($rs / 4), [int]($gs / 4), [int]($bs / 4))
}

function Color-Dist($a, $b) {
    [math]::Sqrt(($a[0]-$b[0])*($a[0]-$b[0]) + ($a[1]-$b[1])*($a[1]-$b[1]) + ($a[2]-$b[2])*($a[2]-$b[2]))
}

$allPng = @(Get-ChildItem -LiteralPath $imagesDir -Filter '*.png')
$targets = @($allPng | Where-Object {
    $n = $_.Name
    $null -ne ($prefixes | Where-Object { $n.StartsWith($_) } | Select-Object -First 1)
})
Write-Host "Processing $($targets.Count) icon(s) in $imagesDir"
$touched = 0
$targets | ForEach-Object {
    $path = $_.FullName
    $bmp = [System.Drawing.Bitmap]::FromFile($path)
    $bg = Get-CornerBg $bmp
    $changed = $false
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            $c = $bmp.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $rgb = @($c.R, $c.G, $c.B)
            $dist = Color-Dist $rgb $bg
            $maxC = [math]::Max($c.R, [math]::Max($c.G, $c.B))
            $minC = [math]::Min($c.R, [math]::Min($c.G, $c.B))
            $neutral = ($c.R -gt 165) -and ($c.G -gt 165) -and ($c.B -gt 165) -and (($maxC - $minC) -lt 28)
            if ($dist -le 52 -or $neutral) {
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
                $changed = $true
            }
        }
    }
    if ($changed) {
        $tmp = "$path.__tmp.png"
        $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        Move-Item -LiteralPath $tmp -Destination $path -Force
        Write-Host "fixed $($_.Name)"
        $touched++
    } else {
        Write-Host "skip  $($_.Name)"
        $bmp.Dispose()
    }
}
Write-Host "Done. Updated $touched file(s)."
