# Sugeneruoja mrp_plates/textures/plate01.png (violetine MRP + logo)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath (Join-Path $root 'resources'))) {
    $root = 'C:\Users\pytka\Desktop\FIVEMPROJEKTAS'
}

$logoPath = Join-Path $root 'resources\[local]\mrp_loadscreen\html\assets\mrp_logo.png'
$outPath = Join-Path $root 'resources\[local]\mrp_plates\textures\plate01.png'

$targetW = 512
$targetH = 256
$bmp = New-Object System.Drawing.Bitmap $targetW, $targetH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'HighQuality'
$g.InterpolationMode = 'HighQualityBicubic'

$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 76, 29, 149))), 0, 0, $targetW, $targetH)
$bandW = [int]($targetW * 0.30)
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 59, 7, 100))), 0, 0, $bandW, $targetH)
$whiteX = $bandW + 5
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 250, 245, 255))), $whiteX, 6, $targetW - $whiteX - 6, $targetH - 12)
$g.DrawRectangle((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 124, 58, 237)), 2), 1, 1, $targetW - 3, $targetH - 3)

$fontLt = New-Object System.Drawing.Font('Arial', 13, [System.Drawing.FontStyle]::Bold)
$g.DrawString('LT', $fontLt, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 196, 181, 253))), 10, ($targetH - 26))

if (Test-Path -LiteralPath $logoPath) {
    $logo = [System.Drawing.Image]::FromFile($logoPath)
    $ls = 78
    $g.DrawImage($logo, [int](($bandW - $ls) / 2), [int](($targetH - $ls) / 2) - 6, $ls, $ls)
    $logo.Dispose()
} else {
    Write-Warning "Logo not found: $logoPath"
}

$fontMrp = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
$g.DrawString('MRP', $fontMrp, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 167, 139, 250))), ($whiteX + 6), [int]($targetH / 2 - 7))

$g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Built $outPath"
