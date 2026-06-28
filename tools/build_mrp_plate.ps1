# Sugeneruoja mrp_plates/textures/plate01.png (violetine MRP + logo, 256x128 kaip vanilla plate01)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath (Join-Path $root 'resources'))) {
    $root = 'C:\Users\pytka\Desktop\FIVEMPROJEKTAS'
}

$logoPath = Join-Path $root 'resources\[local]\mrp_loadscreen\html\assets\mrp_logo.png'
$outPath = Join-Path $root 'resources\[local]\mrp_plates\textures\plate01.png'

# Vanilla plate01 proporcijos — tekstas sinchronizuojamas su GTA šriftu.
$targetW = 256
$targetH = 128
$bmp = New-Object System.Drawing.Bitmap $targetW, $targetH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'HighQuality'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'

$violet = [System.Drawing.Color]::FromArgb(255, 76, 29, 149)
$bandDark = [System.Drawing.Color]::FromArgb(255, 59, 7, 100)
$white = [System.Drawing.Color]::FromArgb(255, 252, 250, 255)
$border = [System.Drawing.Color]::FromArgb(255, 124, 58, 237)
$ltColor = [System.Drawing.Color]::FromArgb(255, 196, 181, 253)

$g.FillRectangle((New-Object System.Drawing.SolidBrush $violet), 0, 0, $targetW, $targetH)

# Siauresne EU juosta (~19%) — kad 3 skaitmenys + 3 raides tilptu baltame lauke.
$bandW = 48
$g.FillRectangle((New-Object System.Drawing.SolidBrush $bandDark), 0, 0, $bandW, $targetH)

$whiteX = $bandW + 3
$whiteW = $targetW - $whiteX - 4
$g.FillRectangle((New-Object System.Drawing.SolidBrush $white), $whiteX, 5, $whiteW, $targetH - 10)
$g.DrawRectangle((New-Object System.Drawing.Pen $border, 2), 1, 1, $targetW - 3, $targetH - 3)

$fontLt = New-Object System.Drawing.Font('Arial', 9, [System.Drawing.FontStyle]::Bold)
$g.DrawString('LT', $fontLt, (New-Object System.Drawing.SolidBrush $ltColor), 8, ($targetH - 22))

if (Test-Path -LiteralPath $logoPath) {
    $logo = [System.Drawing.Image]::FromFile($logoPath)
    $ls = 34
    $g.DrawImage($logo, [int](($bandW - $ls) / 2), [int](($targetH - $ls) / 2) - 8, $ls, $ls)
    $logo.Dispose()
} else {
    Write-Warning "Logo not found: $logoPath"
}

$g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Built $outPath ($targetW x $targetH)"
