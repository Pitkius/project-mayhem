# Standalone test: resize one texture, build, save
param([string]$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46")
Add-Type -AssemblyName System.Drawing
$bak = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\cfx-nteam-mrpd\stream\_backup_before_resize\nteammrpdtxt2.ytd"
$out = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\_tools\YtdResize\test-out.ytd"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$YtdFile = $asm.GetType("CodeWalker.GameFiles.YtdFile")
$DDSIO = $asm.GetType("CodeWalker.Utils.DDSIO")
$getPixels = $DDSIO.GetMethod("GetPixels")

function To-UInt32($val) {
    if ($null -eq $val) { return [uint32]0 }
    if ($val -is [uint32]) { return $val }
    return [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$val), 0)
}
function Write-UInt32([IO.BinaryWriter]$bw, $val) { $bw.Write([BitConverter]::GetBytes((To-UInt32 $val))) }
function Build-DdsRgba([byte[]]$rgba, [int]$w, [int]$h) {
    $ms = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter($ms)
    $bw.Write([int]0x20534444); $bw.Write([int]124); Write-UInt32 $bw 0x0002100F
    $bw.Write([int]$h); $bw.Write([int]$w); $bw.Write([int]($w * $h * 4)); $bw.Write([int]0); $bw.Write([int]1)
    for ($i = 0; $i -lt 11; $i++) { $bw.Write([int]0) }
    $bw.Write([int]32); Write-UInt32 $bw 0x41; Write-UInt32 $bw 0; Write-UInt32 $bw 32
    Write-UInt32 $bw 0x00FF0000; Write-UInt32 $bw 0x0000FF00; Write-UInt32 $bw 0x000000FF; Write-UInt32 $bw 0xFF000000
    Write-UInt32 $bw 0x1000; Write-UInt32 $bw 0; Write-UInt32 $bw 0; Write-UInt32 $bw 0
    for ($i = 0; $i -lt $rgba.Length; $i += 4) { $bw.Write($rgba[$i+2]); $bw.Write($rgba[$i+1]); $bw.Write($rgba[$i+0]); $bw.Write($rgba[$i+3]) }
    $bw.Close(); return [byte[]]$ms.ToArray()
}
function Resize-Tex($tex, [int]$nw, [int]$nh) {
    $pixArgs = New-Object object[] 2; $pixArgs[0] = $tex; $pixArgs[1] = 0
    $pixels = $getPixels.Invoke($null, $pixArgs)
    $w = [int]$tex.Width; $h = [int]$tex.Height
    $src = New-Object System.Drawing.Bitmap $w,$h,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
    $bd = $src.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::WriteOnly,$src.PixelFormat)
    [Runtime.InteropServices.Marshal]::Copy($pixels,0,$bd.Scan0,$pixels.Length); $src.UnlockBits($bd)
    $dst = New-Object System.Drawing.Bitmap $nw,$nh,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst); $g.DrawImage($src,0,0,$nw,$nh); $g.Dispose(); $src.Dispose()
    $outPx = New-Object byte[] ($nw*$nh*4)
    $srect = New-Object System.Drawing.Rectangle 0,0,$nw,$nh
    $sbd = $dst.LockBits($srect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,$dst.PixelFormat)
    [Runtime.InteropServices.Marshal]::Copy($sbd.Scan0,$outPx,0,$outPx.Length); $dst.UnlockBits($sbd); $dst.Dispose()
    $dds = Build-DdsRgba $outPx $nw $nh
    $getTexture = $DDSIO.GetMethod("GetTexture",[type[]]@([byte[]]))
    $invokeArgs = New-Object object[] 1; $invokeArgs[0] = $dds
    return $getTexture.Invoke($null, $invokeArgs)
}

$ytd = [Activator]::CreateInstance($YtdFile)
$YtdFile.GetMethod("Load",[type[]]@([byte[]])).Invoke($ytd, @(,[IO.File]::ReadAllBytes($bak)))
$items = @($ytd.TextureDict.Textures.data_items)
$texType = $asm.GetType("CodeWalker.GameFiles.Texture")
$listType = [Collections.Generic.List`1].MakeGenericType($texType)
$list = [Activator]::CreateInstance($listType)
foreach ($t in $items) { [void]$listType.GetMethod("Add").Invoke($list, @($t)) }

for ($i = 0; $i -lt $items.Length; $i++) {
    $t = $items[$i]
    if ($t.Width -lt 1024 -and $t.Height -lt 1024) { continue }
    $nw = [Math]::Max(1, [int]$t.Width / 2); $nh = [Math]::Max(1, [int]$t.Height / 2)
    $r = Resize-Tex $t $nw $nh
    $r.Name = $t.Name; $r.NameHash = $t.NameHash; $r.Usage = $t.Usage
    $r.UsageFlags = To-UInt32 $t.UsageFlags; $r.Unknown_32h = To-UInt32 $t.Unknown_32h
    $listType.GetMethod("set_Item").Invoke($list, @($i, $r))
    Write-Host "Resized $($t.Name)"
}

$dict = $ytd.TextureDict
Write-Host "Before build ytd=$($null -eq $ytd) dict=$($null -eq $dict)"
try { $dict.BuildFromTextureList($list); Write-Host "Build OK" } catch { Write-Host "Build FAIL: $($_.Exception.Message)"; exit 1 }
Write-Host "After build ytd=$($null -eq $ytd)"
try {
    $saved = $YtdFile.GetMethod("Save").Invoke($ytd, $null)
    Write-Host "Saved $($saved.Length) bytes"
    [IO.File]::WriteAllBytes($out, $saved)
    Write-Host "Written to $out"
} catch {
    Write-Host "Save FAIL: $($_.Exception.Message)"
    if ($_.Exception.InnerException) { Write-Host $_.Exception.InnerException.Message }
}
