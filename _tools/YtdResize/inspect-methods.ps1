$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$asm.GetTypes() | ForEach-Object {
    $_.GetMethods([Reflection.BindingFlags]"Public,Static") | Where-Object {
        $_.Name -match 'Compress|DXT|Texture|DDS'
    } | ForEach-Object { Write-Host ($_.DeclaringType.FullName + "::" + $_.Name) }
} | Select-Object -First 40
