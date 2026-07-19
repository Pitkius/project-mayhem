$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\resources\[cars]\mrp_pd_mrpd\data'
$root = [System.IO.Path]::GetFullPath($root)

Write-Host "Root: $root"
if (-not (Test-Path -LiteralPath $root)) {
    throw "Data folder not found: $root"
}

1..16 | ForEach-Object {
    $n = $_
    $newId = 99 + $n   # 100..115
    $oldId = 9700 + $n # 9701..9716
    $dir = Join-Path $root ("mrpd{0}" -f $n)
    $cols = Join-Path $dir 'carcols.meta'
    $vars = Join-Path $dir 'carvariations.meta'

    if (-not (Test-Path -LiteralPath $cols)) {
        Write-Host "SKIP missing carcols: mrpd$n"
        return
    }
    if (-not (Test-Path -LiteralPath $vars)) {
        Write-Host "SKIP missing carvariations: mrpd$n"
        return
    }

    $c = [System.IO.File]::ReadAllText($cols)
    $v = [System.IO.File]::ReadAllText($vars)

    $oldIdStr = [string]$oldId
    $newIdStr = [string]$newId

    $cHits = ([regex]::Matches($c, [regex]::Escape("id value=`"$oldIdStr`""))).Count
    $vHits = ([regex]::Matches($v, [regex]::Escape("sirenSettings value=`"$oldIdStr`""))).Count

    if ($cHits -lt 1) {
        # Already remapped?
        $already = ([regex]::Matches($c, [regex]::Escape("id value=`"$newIdStr`""))).Count
        Write-Host ("mrpd{0}: no old id {1} in carcols (already new? {2})" -f $n, $oldIdStr, $already)
    }

    $c = $c.Replace("id value=`"$oldIdStr`"", "id value=`"$newIdStr`"")
    $v = $v.Replace("sirenSettings value=`"$oldIdStr`"", "sirenSettings value=`"$newIdStr`"")

    [System.IO.File]::WriteAllText($cols, $c)
    [System.IO.File]::WriteAllText($vars, $v)

    Write-Host ("mrpd{0}: {1} -> {2} (carcols={3}, carvariations={4})" -f $n, $oldIdStr, $newIdStr, $cHits, $vHits)
}

Write-Host 'Done.'
