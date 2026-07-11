Add-Type -AssemblyName System.Drawing
$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
$bak = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\cfx-nteam-mrpd\stream\_backup_before_resize\nteammrpdtxt.ytd"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$YtdFile = $asm.GetType("CodeWalker.GameFiles.YtdFile")
$ytd = [Activator]::CreateInstance($YtdFile)
$YtdFile.GetMethod("Load", [type[]]@([byte[]])).Invoke($ytd, @(,[IO.File]::ReadAllBytes($bak)))
$items = @($ytd.TextureDict.Textures.data_items)
$texType = $asm.GetType("CodeWalker.GameFiles.Texture")
$listType = [Collections.Generic.List`1].MakeGenericType($texType)
$list = [Activator]::CreateInstance($listType)
foreach ($t in $items) { [void]$listType.GetMethod("Add").Invoke($list, @($t)) }
$dict = $ytd.TextureDict
$build = $dict.GetType().GetMethod("BuildFromTextureList")
Write-Host "Build method: $($build.ToString())"
try {
    $build.Invoke($dict, @($list))
    $saved = $YtdFile.GetMethod("Save").Invoke($ytd, $null)
    Write-Host "OK saved $($saved.Length)"
} catch {
    Write-Host "FAIL: $($_.Exception.Message)"
    if ($_.Exception.InnerException) { Write-Host "Inner: $($_.Exception.InnerException.Message)" }
}
