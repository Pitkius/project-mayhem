Add-Type -AssemblyName System.Drawing
$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
$StreamDir = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\cfx-nteam-mrpd\stream"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$YtdFile = $asm.GetType("CodeWalker.GameFiles.YtdFile")
$DDSIO = $asm.GetType("CodeWalker.Utils.DDSIO")
$getPixels = $DDSIO.GetMethod("GetPixels")
$getTexture = $DDSIO.GetMethod("GetTexture")
$f = Get-ChildItem -LiteralPath $StreamDir -Filter "nteammrpdtxt2.ytd" | Select-Object -First 1
$ytd = [Activator]::CreateInstance($YtdFile)
$YtdFile.GetMethod("Load", [type[]]@([byte[]])).Invoke($ytd, @(,[IO.File]::ReadAllBytes($f.FullName)))
$tex = ($ytd.TextureDict.Textures.data_items | Where-Object { $_.Width -ge 1024 } | Select-Object -First 1)
Write-Host "Testing texture: $($tex.Name) $($tex.Width)x$($tex.Height)"
$pixels = $getPixels.Invoke($null, @($tex, 0))
Write-Host "Pixels: $($pixels.Length)"
$w = [int]$tex.Width; $h = [int]$tex.Height
$src = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$bd = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $src.PixelFormat)
[Runtime.InteropServices.Marshal]::Copy($pixels, 0, $bd.Scan0, $pixels.Length)
$src.UnlockBits($bd)
$nw = $w / 2; $nh = $h / 2
$dst = New-Object System.Drawing.Bitmap $nw, $nh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.DrawImage($src, 0, 0, $nw, $nh); $g.Dispose(); $src.Dispose()
$out = New-Object byte[] ($nw * $nh * 4)
$srect = New-Object System.Drawing.Rectangle 0, 0, $nw, $nh
$sbd = $dst.LockBits($srect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $dst.PixelFormat)
[Runtime.InteropServices.Marshal]::Copy($sbd.Scan0, $out, 0, $out.Length)
$dst.UnlockBits($sbd); $dst.Dispose()

$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter($ms)
$bw.Write([int]0x20534444); $bw.Write([int]124); $bw.Write([uint32]0x0002100F)
$bw.Write([int]$nh); $bw.Write([int]$nw); $bw.Write([int]($nw * $nh * 4)); $bw.Write([int]0); $bw.Write([int]1)
for ($i = 0; $i -lt 11; $i++) { $bw.Write([int]0) }
$bw.Write([int]32); $bw.Write([uint32]0x41); $bw.Write([uint32]0); $bw.Write([uint32]32)
$bw.Write([uint32][int64]0x00FF0000); $bw.Write([uint32][int64]0x0000FF00)
$bw.Write([uint32][int64]0x000000FF); $bw.Write([uint32][int64]0xFF000000)
$bw.Write([uint32]0x1000); $bw.Write([uint32]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
for ($i = 0; $i -lt $out.Length; $i += 4) {
    $bw.Write($out[$i + 2]); $bw.Write($out[$i + 1]); $bw.Write($out[$i + 0]); $bw.Write($out[$i + 3])
}
$dds = $ms.ToArray(); $bw.Close()
Write-Host "DDS bytes: $($dds.Length)"

try {
    $r = $getTexture.Invoke($null, @(, $dds))
    Write-Host "GetTexture OK: $($r.Width)x$($r.Height)"
    try { $r.Name = $tex.Name; Write-Host "Name OK" } catch { Write-Host "Name FAIL: $($_.Exception.Message)" }
    try { $r.UsageFlags = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$tex.UsageFlags), 0); Write-Host "UsageFlags OK" } catch { Write-Host "UsageFlags FAIL: $($_.Exception.Message)" }
} catch {
    Write-Host "GetTexture FAIL: $($_.Exception.Message)"
    if ($_.Exception.InnerException) { Write-Host "Inner: $($_.Exception.InnerException.Message)" }
    Write-Host $_.ScriptStackTrace
}
