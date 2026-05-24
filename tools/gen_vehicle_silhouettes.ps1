Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$vehDir = Join-Path $root 'resources\[local]\fivempro_hud\html\assets\vehicles'
if (-not (Test-Path -LiteralPath $vehDir)) {
    New-Item -ItemType Directory -Path $vehDir -Force | Out-Null
}

function Draw-TopDownCar($g, $w, $h, $bodyW, $bodyH, $roofW, $roofH, $color) {
    $cx = $w / 2
    $cy = $h / 2
    $brush = New-Object System.Drawing.SolidBrush $color
    $wheel = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 18, 22, 30))
    $glass = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 90, 120))
    $pts = @(
        [System.Drawing.Point]::new([int]($cx), [int]($cy - $bodyH / 2)),
        [System.Drawing.Point]::new([int]($cx + $bodyW / 2), [int]($cy - $bodyH / 2 + 40)),
        [System.Drawing.Point]::new([int]($cx + $bodyW / 2), [int]($cy + $bodyH / 2 - 30)),
        [System.Drawing.Point]::new([int]($cx), [int]($cy + $bodyH / 2)),
        [System.Drawing.Point]::new([int]($cx - $bodyW / 2), [int]($cy + $bodyH / 2 - 30)),
        [System.Drawing.Point]::new([int]($cx - $bodyW / 2), [int]($cy - $bodyH / 2 + 40))
    )
    $g.FillPolygon($brush, $pts)
    $g.FillRectangle($glass, [int]($cx - $roofW / 2), [int]($cy - $roofH / 2 - 20), [int]$roofW, [int]($roofH))
    $g.FillEllipse($wheel, [int]($cx - $bodyW / 2 + 8), [int]($cy - 50), 34, 50)
    $g.FillEllipse($wheel, [int]($cx + $bodyW / 2 - 42), [int]($cy - 50), 34, 50)
    $g.FillEllipse($wheel, [int]($cx - $bodyW / 2 + 8), [int]($cy + 10), 34, 50)
    $g.FillEllipse($wheel, [int]($cx + $bodyW / 2 - 42), [int]($cy + 10), 34, 50)
}

function Save-VehiclePng($name, $drawFn) {
    $path = Join-Path $vehDir ($name + '.png')
    $bmp = New-Object System.Drawing.Bitmap 256, 420
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    & $drawFn $g 256 420
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "Wrote $name.png"
}

$classes = @{
    'class_compact'   = @{ w = 90;  h = 200; rw = 52; rh = 70; c = [System.Drawing.Color]::FromArgb(255, 180, 200, 220) }
    'class_sedan'     = @{ w = 100; h = 230; rw = 58; rh = 85; c = [System.Drawing.Color]::FromArgb(255, 195, 210, 230) }
    'class_suv'       = @{ w = 120; h = 250; rw = 70; rh = 95; c = [System.Drawing.Color]::FromArgb(255, 210, 218, 235) }
    'class_coupe'     = @{ w = 98;  h = 220; rw = 54; rh = 72; c = [System.Drawing.Color]::FromArgb(255, 200, 205, 225) }
    'class_muscle'    = @{ w = 112; h = 240; rw = 60; rh = 78; c = [System.Drawing.Color]::FromArgb(255, 190, 170, 175) }
    'class_sports'    = @{ w = 104; h = 235; rw = 50; rh = 68; c = [System.Drawing.Color]::FromArgb(255, 220, 180, 180) }
    'class_super'     = @{ w = 108; h = 240; rw = 48; rh = 62; c = [System.Drawing.Color]::FromArgb(255, 230, 190, 190) }
    'class_motorcycle'= @{ w = 46;  h = 180; rw = 30; rh = 40; c = [System.Drawing.Color]::FromArgb(255, 170, 180, 200) }
    'class_offroad'   = @{ w = 118; h = 255; rw = 68; rh = 88; c = [System.Drawing.Color]::FromArgb(255, 185, 195, 170) }
    'class_van'       = @{ w = 115; h = 260; rw = 72; rh = 100; c = [System.Drawing.Color]::FromArgb(255, 200, 205, 215) }
}

foreach ($entry in $classes.GetEnumerator()) {
    $n = $entry.Key
    $p = $entry.Value
    Save-VehiclePng $n { param($g, $w, $h)
        Draw-TopDownCar $g $w $h $p.w $p.h $p.rw $p.rh $p.c
    }
}

# Populiarūs modeliai (Baller = SUV, F820 = sports)
Save-VehiclePng 'baller' { param($g, $w, $h)
    Draw-TopDownCar $g $w $h 125 255 74 98 ([System.Drawing.Color]::FromArgb(255, 215, 222, 240))
}
Save-VehiclePng 'baller2' { param($g, $w, $h)
    Draw-TopDownCar $g $w $h 125 255 74 98 ([System.Drawing.Color]::FromArgb(255, 215, 222, 240))
}
Save-VehiclePng 'f820' { param($g, $w, $h)
    Draw-TopDownCar $g $w $h 108 238 50 66 ([System.Drawing.Color]::FromArgb(255, 225, 185, 185))
}
Save-VehiclePng 'adder' { param($g, $w, $h)
    Draw-TopDownCar $g $w $h 110 242 48 64 ([System.Drawing.Color]::FromArgb(255, 235, 195, 195))
}
Save-VehiclePng 'sultan' { param($g, $w, $h)
    Draw-TopDownCar $g $w $h 102 232 56 78 ([System.Drawing.Color]::FromArgb(255, 200, 210, 225))
}

Write-Host 'Done.'
