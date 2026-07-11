$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$t = $asm.GetType("CodeWalker.GameFiles.Texture")
$t.GetProperties() | Sort-Object Name | ForEach-Object { Write-Host ($_.PropertyType.Name + " " + $_.Name) }
Write-Host "---"
$t.GetFields() | Sort-Object Name | ForEach-Object { Write-Host ($_.FieldType.Name + " " + $_.Name) }
