# DEPRECATED for HUD: car HUD naudoja SVG (fivempro_hud/html/index.html).
# Inventoriaus PNG – naudok AI generuotas ikonas, ne šį scriptą.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$hudDir = Join-Path $root 'resources\[local]\fivempro_hud\html\assets\icons'
$vehDir = Join-Path $root 'resources\[local]\fivempro_hud\html\assets\vehicles'
$invDir = Join-Path $root 'resources\[qb]\qb-inventory\html\images'

foreach ($d in @($hudDir, $vehDir)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

function Save-Png($path, $drawFn) {
    $bmp = New-Object System.Drawing.Bitmap(128, 128)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    & $drawFn $g
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

Save-Png (Join-Path $hudDir 'icon-engine.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,167,139,250),4)
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,167,139,250))
    $g.DrawRectangle($p,28,42,72,44); $g.FillRectangle($b,34,48,24,32); $g.FillRectangle($b,70,48,24,32); $g.DrawRectangle($p,52,36,24,16); $g.DrawLine($p,40,56,88,56)
}
Save-Png (Join-Path $hudDir 'icon-fuel.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,167,139,250)); $p=New-Object System.Drawing.Pen([System.Drawing.Color]::White,3)
    $g.FillRectangle($b,36,38,28,52); $g.FillPolygon($b,@([System.Drawing.Point]::new(50,28),[System.Drawing.Point]::new(64,28),[System.Drawing.Point]::new(64,38),[System.Drawing.Point]::new(50,38)))
    $g.DrawLine($p,64,34,82,34); $g.DrawLine($p,82,34,82,58); $g.FillEllipse($b,78,54,12,12)
}
Save-Png (Join-Path $hudDir 'icon-lights.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $y=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,230,120)); $g.FillEllipse($y,24,48,22,22); $g.FillEllipse($y,82,48,22,22)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,255,210,80),3); $g.DrawLine($p,46,59,82,59); $g.DrawLine($p,35,59,18,72); $g.DrawLine($p,93,59,110,72)
}
Save-Png (Join-Path $hudDir 'icon-belt.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,251,113,133),5); $g.DrawLine($p,30,88,98,40); $g.DrawLine($p,30,40,98,88); $g.FillEllipse([System.Drawing.Brushes]::LightGray,58,58,12,12)
}
Save-Png (Join-Path $hudDir 'icon-doors.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,167,139,250),4); $g.DrawRectangle($p,34,28,60,72); $g.DrawLine($p,64,28,64,100); $g.FillEllipse([System.Drawing.Brushes]::Gold,72,58,10,10)
}
Save-Png (Join-Path $hudDir 'icon-lock.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,167,139,250),4); $g.DrawArc($p,42,28,44,40,180,180); $g.DrawRectangle($p,36,58,56,42); $g.FillEllipse([System.Drawing.Brushes]::Gold,58,72,12,12)
}
Save-Png (Join-Path $hudDir 'icon-interior.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $y=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,220,100)); $g.FillEllipse($y,44,44,40,40)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,255,200,80),3); $g.DrawLine($p,64,20,64,44); $g.DrawLine($p,64,84,64,108); $g.DrawLine($p,20,64,44,64); $g.DrawLine($p,84,64,108,64)
}
Save-Png (Join-Path $hudDir 'icon-car.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,200,210,230))
    $g.FillPolygon($b,@([System.Drawing.Point]::new(64,24),[System.Drawing.Point]::new(88,44),[System.Drawing.Point]::new(92,72),[System.Drawing.Point]::new(84,98),[System.Drawing.Point]::new(44,98),[System.Drawing.Point]::new(36,72),[System.Drawing.Point]::new(40,44)))
    $g.FillEllipse([System.Drawing.Brushes]::Black,42,68,16,16); $g.FillEllipse([System.Drawing.Brushes]::Black,70,68,16,16)
}
Save-Png (Join-Path $hudDir 'icon-plate.png') { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,15,18,28))),8,8,112,112)
    $g.FillRectangle([System.Drawing.Brushes]::White,24,46,80,36); $g.DrawString('ABC',(New-Object System.Drawing.Font('Arial',16,[System.Drawing.FontStyle]::Bold)),[System.Drawing.Brushes]::Black,38,52)
}

$carPath = Join-Path $vehDir 'vehicle-topdown.png'
$car = New-Object System.Drawing.Bitmap(256,512)
$cg=[System.Drawing.Graphics]::FromImage($car); $cg.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $cg.Clear([System.Drawing.Color]::Transparent)
$body=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,220,228,240)); $glass=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,90,110,140)); $wheel=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,20,24,32))
$cg.FillPolygon($body,@([System.Drawing.Point]::new(128,20),[System.Drawing.Point]::new(188,70),[System.Drawing.Point]::new(210,180),[System.Drawing.Point]::new(200,420),[System.Drawing.Point]::new(170,480),[System.Drawing.Point]::new(86,480),[System.Drawing.Point]::new(56,420),[System.Drawing.Point]::new(46,180),[System.Drawing.Point]::new(68,70)))
$cg.FillRectangle($glass,88,90,80,90); $cg.FillRectangle($glass,88,280,80,70)
$cg.FillEllipse($wheel,52,110,44,70); $cg.FillEllipse($wheel,160,110,44,70); $cg.FillEllipse($wheel,52,330,44,70); $cg.FillEllipse($wheel,160,330,44,70)
$cg.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,30,40,60),2)),128,90,128,350)
$car.Save($carPath,[System.Drawing.Imaging.ImageFormat]::Png); $cg.Dispose(); $car.Dispose()

$inv = @{
  'tow_chain.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,190,195,210),5)
    $g.DrawArc($p,34,42,26,26,0,360); $g.DrawArc($p,68,42,26,26,0,360); $g.DrawLine($p,47,55,81,55); $g.DrawLine($p,42,68,42,92); $g.DrawLine($p,86,68,86,92)
  }
  'basic_tablet.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,100,180,255),4); $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,60,140,220))
    $g.DrawRectangle($p,34,30,60,70); $g.FillRectangle($b,40,36,48,54)
  }
  'advanced_tablet.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,80,220,170),4); $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,40,170,130))
    $g.DrawRectangle($p,30,28,68,74); $g.FillRectangle($b,36,34,56,56); $g.DrawLine($p,36,50,92,50); $g.DrawLine($p,36,64,92,64)
  }
  'military_tablet.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,255,130,80),4); $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,190,70,40))
    $g.DrawRectangle($p,28,26,72,78); $g.FillRectangle($b,34,32,60,60)
    $g.FillPolygon([System.Drawing.Brushes]::DarkRed,@([System.Drawing.Point]::new(64,40),[System.Drawing.Point]::new(74,58),[System.Drawing.Point]::new(64,76),[System.Drawing.Point]::new(54,58)))
  }
  'basic_flashdrive.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,90,190,255)); $p=New-Object System.Drawing.Pen([System.Drawing.Color]::White,3)
    $g.FillRectangle($b,46,36,36,20); $g.FillRectangle($b,58,56,12,40); $g.DrawRectangle($p,42,32,44,28)
  }
  'encrypted_flashdrive.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,170,110,255)); $p=New-Object System.Drawing.Pen([System.Drawing.Color]::White,3)
    $g.FillRectangle($b,44,36,40,20); $g.FillRectangle($b,58,56,12,40); $g.DrawRectangle($p,40,32,48,28); $g.FillRectangle([System.Drawing.Brushes]::White,48,40,24,8)
  }
  'military_flashdrive.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,190,70)); $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,120,60,20),3)
    $g.FillRectangle($b,42,36,44,20); $g.FillRectangle($b,58,56,12,40); $g.DrawRectangle($p,38,32,52,28); $g.FillRectangle([System.Drawing.Brushes]::DarkRed,48,40,24,8)
  }
  'gang_tablet.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,220,90,240),4); $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,130,40,160))
    $g.DrawRectangle($p,32,30,64,72); $g.FillRectangle($b,38,36,52,54); $g.DrawLine($p,38,52,90,52)
  }
  'police_bodycam.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,70,140,255))
    $g.FillEllipse($b,38,46,52,38); $g.FillEllipse([System.Drawing.Brushes]::Black,52,54,24,22); $g.FillEllipse([System.Drawing.Brushes]::Red,80,48,10,10)
  }
  'drill.png' = { param($g)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230,20,24,36))),6,6,116,116)
    $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,255,180,60),4); $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,220,140,40))
    $g.FillRectangle($b,54,34,20,70); $g.DrawEllipse($p,38,78,52,28); $g.DrawLine($p,64,34,64,22)
  }
}
foreach ($name in $inv.Keys) {
    Save-Png (Join-Path $invDir $name) $inv[$name]
}

Write-Host 'HUD icons:' (Get-ChildItem -LiteralPath $hudDir).Count
Write-Host 'Vehicle assets:' (Get-ChildItem -LiteralPath $vehDir).Count
