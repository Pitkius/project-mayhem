# Resize all 1024+ textures to half size in nteammrpdtxt*.ytd files.
# Requires CodeWalker.Core.dll (same folder as CodeWalker RPF Explorer).

param(
    [string]$StreamDir = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\cfx-nteam-mrpd\stream",
    [string]$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
)

Add-Type -AssemblyName System.Drawing

$cw = Join-Path $CwDir "CodeWalker.Core.dll"
if (-not (Test-Path -LiteralPath $cw)) { throw "CodeWalker.Core.dll not found at $CwDir" }

[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom($cw)

$YtdFile = $asm.GetType("CodeWalker.GameFiles.YtdFile")
$DDSIO = $asm.GetType("CodeWalker.Utils.DDSIO")
$Texture = $asm.GetType("CodeWalker.GameFiles.Texture")
$getPixels = $DDSIO.GetMethod("GetPixels")

function To-UInt32($val) {
    if ($null -eq $val) { return [uint32]0 }
    if ($val -is [uint32]) { return $val }
    return [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$val), 0)
}

function Write-UInt32([IO.BinaryWriter]$bw, $val) {
    $bw.Write([BitConverter]::GetBytes((To-UInt32 $val)))
}

function Invoke-LoadYtd([byte[]]$data) {
    $ytd = [Activator]::CreateInstance($YtdFile)
    $args = New-Object object[] 1
    $args[0] = $data
    $YtdFile.GetMethod("Load", [type[]]@([byte[]])).Invoke($ytd, $args)
    return $ytd
}

function Get-Textures($ytd) {
    return $ytd.TextureDict.Textures.data_items
}

function Build-DdsRgba([byte[]]$rgba, [int]$w, [int]$h) {
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter($ms)
    $bw.Write([int]0x20534444)
    $bw.Write([int]124)
    Write-UInt32 $bw 0x0002100F
    $bw.Write([int]$h)
    $bw.Write([int]$w)
    $bw.Write([int]($w * $h * 4))
    $bw.Write([int]0)
    $bw.Write([int]1)
    for ($i = 0; $i -lt 11; $i++) { $bw.Write([int]0) }
    $bw.Write([int]32)
    Write-UInt32 $bw 0x41
    Write-UInt32 $bw 0
    Write-UInt32 $bw 32
    Write-UInt32 $bw 0x00FF0000
    Write-UInt32 $bw 0x0000FF00
    Write-UInt32 $bw 0x000000FF
    Write-UInt32 $bw 0xFF000000
    Write-UInt32 $bw 0x1000
    Write-UInt32 $bw 0
    Write-UInt32 $bw 0
    Write-UInt32 $bw 0
    for ($i = 0; $i -lt $rgba.Length; $i += 4) {
        $bw.Write($rgba[$i + 2])
        $bw.Write($rgba[$i + 1])
        $bw.Write($rgba[$i + 0])
        $bw.Write($rgba[$i + 3])
    }
    $bw.Close()
    return [byte[]]$ms.ToArray()
}

function Resize-Tex($tex, [int]$nw, [int]$nh) {
    $pixArgs = New-Object object[] 2
    $pixArgs[0] = $tex
    $pixArgs[1] = 0
    $pixels = $getPixels.Invoke($null, $pixArgs)
    if (-not $pixels -or $pixels.Length -eq 0) { throw "no pixels" }

    $w = [int]$tex.Width
    $h = [int]$tex.Height
    $src = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $bd = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $src.PixelFormat)
    try { [Runtime.InteropServices.Marshal]::Copy($pixels, 0, $bd.Scan0, $pixels.Length) }
    finally { $src.UnlockBits($bd) }

    $dst = New-Object System.Drawing.Bitmap $nw, $nh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, 0, 0, $nw, $nh)
    $g.Dispose()
    $src.Dispose()

    $out = New-Object byte[] ($nw * $nh * 4)
    $srect = New-Object System.Drawing.Rectangle 0, 0, $nw, $nh
    $sbd = $dst.LockBits($srect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $dst.PixelFormat)
    try { [Runtime.InteropServices.Marshal]::Copy($sbd.Scan0, $out, 0, $out.Length) }
    finally { $dst.UnlockBits($sbd); $dst.Dispose() }

    $dds = Build-DdsRgba $out $nw $nh
    if ($dds -isnot [byte[]]) { $dds = [byte[]]$dds }
    $getTexture = $DDSIO.GetMethod("GetTexture", [type[]]@([byte[]]))
    $invokeArgs = New-Object object[] 1
    $invokeArgs[0] = $dds
    return $getTexture.Invoke($null, $invokeArgs)
}

$backup = Join-Path $StreamDir "_backup_before_resize"
New-Item -ItemType Directory -Force -Path $backup | Out-Null

$files = Get-ChildItem -LiteralPath $StreamDir -Filter "nteammrpdtxt*.ytd"
$grand = 0
foreach ($f in $files) {
    $bak = Join-Path $backup $f.Name
    if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $f.FullName -Destination $bak }
    $before = $f.Length
    $ytd = Invoke-LoadYtd ([IO.File]::ReadAllBytes($f.FullName))
    $items = @(Get-Textures $ytd)
    $texType = $asm.GetType("CodeWalker.GameFiles.Texture")
    $listType = [Collections.Generic.List`1].MakeGenericType($texType)
    $list = [Activator]::CreateInstance($listType)
    foreach ($t in $items) { [void]$listType.GetMethod("Add").Invoke($list, @($t)) }
    $n = 0
    for ($i = 0; $i -lt $items.Length; $i++) {
        $t = $items[$i]
        if ($t.Width -lt 1024 -and $t.Height -lt 1024) { continue }
        $nw = [Math]::Max(1, [int]$t.Width / 2)
        $nh = [Math]::Max(1, [int]$t.Height / 2)
        try {
            $r = Resize-Tex $t $nw $nh
            $r.Name = $t.Name
            $r.NameHash = $t.NameHash
            $r.Usage = $t.Usage
            $r.UsageFlags = To-UInt32 $t.UsageFlags
            $r.Unknown_32h = To-UInt32 $t.Unknown_32h
            $listType.GetMethod("set_Item").Invoke($list, @($i, $r))
            $n++
            Write-Host ("  {0}: {1}x{2} -> {3}x{4}" -f $t.Name, $t.Width, $t.Height, $nw, $nh)
        } catch {
            Write-Warning ("  SKIP {0}: {1}" -f $t.Name, $_.Exception.Message)
        }
    }
    if ($n -gt 0) {
        $dict = $ytd.TextureDict
        $dict.BuildFromTextureList($list)
        $saved = $ytd.Save()
        [IO.File]::WriteAllBytes($f.FullName, $saved)
    }
    $after = (Get-Item -LiteralPath $f.FullName).Length
    Write-Host ("{0}: resized {1}, {2} KB -> {3} KB" -f $f.Name, $n, [math]::Round($before/1KB), [math]::Round($after/1KB))
    $grand += $n
}
Write-Host "Total resized: $grand. Backups: $backup"
