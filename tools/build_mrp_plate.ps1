# Sugeneruoja mrp_plates/textures/plate01.png (MRP EU, 256x128)
# Be „San Andreas“ ir be „LT“ — tik MRP logo kairėje juostoje.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $root 'resources'))) {
    $root = 'C:\Users\pytka\Desktop\FIVEMPROJEKTAS'
}

$logoPath = Join-Path $root 'resources\[local]\mrp_loadscreen\html\assets\mrp_logo.png'
$outPath = Join-Path $root 'resources\[local]\mrp_plates\textures\plate01.png'

$targetW = 256
$targetH = 128

function New-SolidBrushArgb($a, $r, $g, $b) {
    return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($a, $r, $g, $b))
}

function New-PenArgb($a, $r, $g, $b, $width) {
    return New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($a, $r, $g, $b)), $width
}

function Draw-LinearGradientRect($g, $rect, $c1, $c2, $vertical) {
    $mode = if ($vertical) { [System.Drawing.Drawing2D.LinearGradientMode]::Vertical } else { [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal }
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, $mode
    $g.FillRectangle($brush, $rect)
    $brush.Dispose()
}

function Draw-EmbossedLogo($g, $logo, $x, $y, $size) {
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.CompositingQuality = 'HighQuality'
    $g.SmoothingMode = 'HighQuality'

    # Violetinis glow uz logo (metalinis halas)
    $glowRect = New-Object System.Drawing.Rectangle ([int]($x - 3), [int]($y - 3), [int]($size + 6), [int]($size + 6))
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($glowRect)
    $glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(120, 196, 181, 253)
    $glowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 76, 29, 149))
    $g.FillEllipse($glowBrush, $glowRect)
    $glowBrush.Dispose()
    $path.Dispose()

    # Giluminis seselis (isgraviruota duobe)
    $shadow = New-Object System.Drawing.Imaging.ImageAttributes
    $shadowMatrix = New-Object System.Drawing.Imaging.ColorMatrix
    $shadowMatrix.Matrix00 = 0.12
    $shadowMatrix.Matrix11 = 0.08
    $shadowMatrix.Matrix22 = 0.18
    $shadowMatrix.Matrix33 = 0.55
    $shadow.SetColorMatrix($shadowMatrix)
    $g.DrawImage($logo, (New-Object System.Drawing.Rectangle ([int]($x + 2), [int]($y + 2), $size, $size)), 0, 0, $logo.Width, $logo.Height, [System.Drawing.GraphicsUnit]::Pixel, $shadow)
    $shadow.Dispose()

    # Pagrindinis logo sluoksnis (siek tiek pritemintas — ne plokscias PNG)
    $base = New-Object System.Drawing.Imaging.ImageAttributes
    $baseMatrix = New-Object System.Drawing.Imaging.ColorMatrix
    $baseMatrix.Matrix00 = 0.92
    $baseMatrix.Matrix11 = 0.88
    $baseMatrix.Matrix22 = 0.95
    $baseMatrix.Matrix33 = 1.0
    $baseMatrix.Matrix40 = 0.02
    $baseMatrix.Matrix41 = 0.01
    $baseMatrix.Matrix42 = 0.03
    $base.SetColorMatrix($baseMatrix)
    $g.DrawImage($logo, (New-Object System.Drawing.Rectangle ([int]$x, [int]$y, $size, $size)), 0, 0, $logo.Width, $logo.Height, [System.Drawing.GraphicsUnit]::Pixel, $base)
    $base.Dispose()

    # Virsutinis highlight (blizgesys / isgraviruotas krastas)
    $hi = New-Object System.Drawing.Imaging.ImageAttributes
    $hiMatrix = New-Object System.Drawing.Imaging.ColorMatrix
    $hiMatrix.Matrix00 = 0.35
    $hiMatrix.Matrix11 = 0.35
    $hiMatrix.Matrix22 = 0.45
    $hiMatrix.Matrix33 = 0.42
    $hiMatrix.Matrix40 = 0.55
    $hiMatrix.Matrix41 = 0.55
    $hiMatrix.Matrix42 = 0.62
    $hi.SetColorMatrix($hiMatrix)
    $hiRect = New-Object System.Drawing.Rectangle ([int]($x - 1), [int]($y - 1), [int]($size * 0.62), [int]($size * 0.55))
    $g.SetClip($hiRect)
    $g.DrawImage($logo, (New-Object System.Drawing.Rectangle ([int]($x - 1), [int]($y - 1), $size, $size)), 0, 0, $logo.Width, $logo.Height, [System.Drawing.GraphicsUnit]::Pixel, $hi)
    $g.ResetClip()
    $hi.Dispose()

    # Metalinis ringas aplink emblema
    $ringPen = New-PenArgb 170 167 139 250 1.6
    $g.DrawEllipse($ringPen, [int]($x - 2), [int]($y - 2), [int]($size + 4), [int]($size + 4))
    $innerPen = New-PenArgb 90 59 7 100 1
    $g.DrawEllipse($innerPen, [int]($x + 1), [int]($y + 1), [int]($size - 2), [int]($size - 2))
    $ringPen.Dispose()
    $innerPen.Dispose()
}

$bmp = New-Object System.Drawing.Bitmap $targetW, $targetH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'HighQuality'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.TextRenderingHint = 'ClearTypeGridFit'

$violet = [System.Drawing.Color]::FromArgb(255, 76, 29, 149)
$bandDark = [System.Drawing.Color]::FromArgb(255, 46, 16, 101)
$bandLight = [System.Drawing.Color]::FromArgb(255, 109, 40, 217)
$white = [System.Drawing.Color]::FromArgb(255, 248, 250, 252)
$border = [System.Drawing.Color]::FromArgb(255, 124, 58, 237)
$borderHi = [System.Drawing.Color]::FromArgb(255, 196, 181, 253)
$numField = [System.Drawing.Color]::FromArgb(255, 18, 18, 22)

# Fonas
$g.FillRectangle((New-Object System.Drawing.SolidBrush $violet), 0, 0, $targetW, $targetH)

$bandW = 52
$bandRect = New-Object System.Drawing.Rectangle 0, 0, $bandW, $targetH
Draw-LinearGradientRect $g $bandRect $bandLight $bandDark $true

$fieldX = $bandW + 3
$fieldW = $targetW - $fieldX - 4
$fieldRect = New-Object System.Drawing.Rectangle $fieldX, 5, $fieldW, ($targetH - 10)

# Visas desinys laukas tamsus (be baltos „San Andreas“ juostos viršuje)
Draw-LinearGradientRect $g $fieldRect ([System.Drawing.Color]::FromArgb(255, 22, 20, 28)) ([System.Drawing.Color]::FromArgb(255, 12, 10, 16)) $true

# Numerių zona
$numRect = New-Object System.Drawing.Rectangle ($fieldX + 6), 38, ($fieldW - 12), 54
$g.FillRectangle((New-Object System.Drawing.SolidBrush $numField), $numRect)
$numPen = New-PenArgb 90 124 58 237 1
$g.DrawRectangle($numPen, $numRect)
$numPen.Dispose()

# Subtilus violetinis highlight (ne baltas — kad variklis nepieštų „San Andreas“)
$shineRect = New-Object System.Drawing.Rectangle $fieldX, 5, $fieldW, 10
Draw-LinearGradientRect $g $shineRect ([System.Drawing.Color]::FromArgb(45, 109, 40, 217)) ([System.Drawing.Color]::FromArgb(0, 109, 40, 217)) $true

# Rėmelis
$g.DrawRectangle((New-Object System.Drawing.Pen $border, 2), 1, 1, $targetW - 3, $targetH - 3)
$g.DrawLine((New-PenArgb 120 196 181 253 1), 2, 2, $targetW - 3, 2)

if (Test-Path -LiteralPath $logoPath) {
    $logo = [System.Drawing.Image]::FromFile($logoPath)
    $ls = 40
    $lx = [int](($bandW - $ls) / 2)
    $ly = [int](($targetH - $ls) / 2)
    Draw-EmbossedLogo $g $logo $lx $ly $ls
    $logo.Dispose()
} else {
    Write-Warning "Logo not found: $logoPath"
}

$g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Built $outPath ($targetW x $targetH)"
