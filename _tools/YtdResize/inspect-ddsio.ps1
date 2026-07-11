$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$DDSIO = $asm.GetType("CodeWalker.Utils.DDSIO")
$DDSIO.GetMethods([Reflection.BindingFlags]"Public,Static") | Sort-Object Name | ForEach-Object {
    $p = ($_.GetParameters() | ForEach-Object { $_.ParameterType.Name }) -join ", "
    Write-Host ($_.ReturnType.Name + " " + $_.Name + "(" + $p + ")")
}
Write-Host "=== nested ==="
$DDSIO.GetNestedTypes() | ForEach-Object {
    Write-Host "TYPE $($_.FullName)"
    $_.GetMethods([Reflection.BindingFlags]"Public,Static") | Sort-Object Name | ForEach-Object {
        $p = ($_.GetParameters() | ForEach-Object { $_.ParameterType.Name }) -join ", "
        Write-Host ("  " + $_.ReturnType.Name + " " + $_.Name + "(" + $p + ")")
    }
}
