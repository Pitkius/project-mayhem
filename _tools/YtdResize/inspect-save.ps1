Add-Type -AssemblyName System.Drawing
$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
$StreamDir = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\cfx-nteam-mrpd\stream"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$YtdFile = $asm.GetType("CodeWalker.GameFiles.YtdFile")
$f = Join-Path $StreamDir "nteammrpdtxt1.ytd"
$ytd = [Activator]::CreateInstance($YtdFile)
$YtdFile.GetMethod("Load", [type[]]@([byte[]])).Invoke($ytd, @(,[IO.File]::ReadAllBytes($f)))
Write-Host "Ytd type: $($ytd.GetType().FullName)"
$YtdFile.GetMethods() | Where-Object { $_.Name -eq "Save" } | ForEach-Object { Write-Host $_.ToString() }
try {
    $saved = $YtdFile.GetMethod("Save").Invoke($ytd, $null)
    Write-Host "Save via reflection: $($saved.Length) bytes"
} catch {
    Write-Host "Save fail: $($_.Exception.Message)"
}
try {
    $saved2 = $ytd.Save()
    Write-Host "Save direct: $($saved2.Length) bytes"
} catch {
    Write-Host "Save direct fail: $($_.Exception.Message)"
}
