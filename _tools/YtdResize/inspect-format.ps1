$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
$bak = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\cfx-nteam-mrpd\stream\_backup_before_resize\nteammrpdtxt2.ytd"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$YtdFile = $asm.GetType("CodeWalker.GameFiles.YtdFile")
$DDSIO = $asm.GetType("CodeWalker.Utils.DDSIO")
$ytd = [Activator]::CreateInstance($YtdFile)
$YtdFile.GetMethod("Load", [type[]]@([byte[]])).Invoke($ytd, @(,[IO.File]::ReadAllBytes($bak)))
$tex = ($ytd.TextureDict.Textures.data_items | Where-Object { $_.Name -eq "RSNOS_v_elevpanels" } | Select-Object -First 1)
Write-Host "Original: $($tex.Width)x$($tex.Height) Format=$($tex.Format) Levels=$($tex.Levels)"
$getDds = $DDSIO.GetMethod("GetDDSFile")
$dds = $getDds.Invoke($null, @($tex))
Write-Host "GetDDSFile bytes: $($dds.Length)"
$getTex = $DDSIO.GetMethod("GetTexture", [type[]]@([byte[]]))
$tex2 = $getTex.Invoke($null, @($dds))
Write-Host "Roundtrip: $($tex2.Width)x$($tex2.Height) Format=$($tex2.Format) Levels=$($tex2.Levels)"
