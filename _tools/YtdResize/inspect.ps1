$CwDir = "C:\Users\pytka\Desktop\CodeWalker30_dev46"
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.dll"))
[void][Reflection.Assembly]::LoadFrom((Join-Path $CwDir "SharpDX.Mathematics.dll"))
$asm = [Reflection.Assembly]::LoadFrom((Join-Path $CwDir "CodeWalker.Core.dll"))
$DDSIO = $asm.GetType("CodeWalker.Utils.DDSIO")
$DDSIO.GetMethods() | Where-Object { $_.Name -eq "GetTexture" } | ForEach-Object {
    Write-Host $_.ToString()
}

$getTexture = $DDSIO.GetMethod("GetTexture", [type[]]@([byte[]]))
Write-Host "Selected: $($getTexture.ToString())"

# minimal valid 4x4 dds
$dds = [byte[]]@(
    0x44,0x44,0x53,0x20, 124,0,0,0, 15,16,2,0, 4,0,0,0, 4,0,0,0, 64,0,0,0, 0,0,0,0, 1,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    32,0,0,0, 65,0,0,0, 0,0,0,0, 32,0,0,0, 0,0,255,0, 0,255,0,0, 255,0,0,0, 0,0,0,255,
    0,16,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
)
# pad pixel data
$dds = $dds + ([byte[]](New-Object byte[] 64))

$args = New-Object object[] 1
$args[0] = $dds
Write-Host "dds type: $($dds.GetType().FullName), args[0] type: $($args[0].GetType().FullName)"
try {
    $r = $getTexture.Invoke($null, $args)
    Write-Host "OK $($r.Width)x$($r.Height)"
} catch {
    Write-Host "FAIL: $($_.Exception.Message)"
}
