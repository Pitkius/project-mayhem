$dir = "C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\cfx-nteam-mrpd\stream"
Write-Host "CURRENT"
Get-ChildItem -LiteralPath $dir -Filter "nteammrpdtxt*.ytd" | Sort-Object Name | ForEach-Object {
    Write-Host ("{0,-22} {1,6} KB" -f $_.Name, [math]::Round($_.Length/1KB))
}
$sum = (Get-ChildItem -LiteralPath $dir -Filter "nteammrpdtxt*.ytd" | Measure-Object Length -Sum).Sum
Write-Host ("TOTAL {0} KB" -f [math]::Round($sum/1KB))
Write-Host "BACKUP"
$bak = Join-Path $dir "_backup_before_resize"
Get-ChildItem -LiteralPath $bak -Filter "nteammrpdtxt*.ytd" | Sort-Object Name | ForEach-Object {
    Write-Host ("{0,-22} {1,6} KB" -f $_.Name, [math]::Round($_.Length/1KB))
}
$sum2 = (Get-ChildItem -LiteralPath $bak -Filter "nteammrpdtxt*.ytd" | Measure-Object Length -Sum).Sum
Write-Host ("TOTAL {0} KB" -f [math]::Round($sum2/1KB))
