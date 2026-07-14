$root = "c:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources"
$consumerLine = "    '@mrp_hud/client/theme_nui_consumer.lua',"
$skipResources = @('mrp_hud', 'oxmysql', 'screenshot-basic')

Get-ChildItem -Path $root -Recurse -Filter 'fxmanifest.lua' | ForEach-Object {
    $manifestPath = $_.FullName
    $content = [System.IO.File]::ReadAllText($manifestPath)
    if ($content -notmatch "ui_page\s+'([^']+)'") { return }

    $uiPage = $Matches[1]
    $resourceDir = Split-Path $manifestPath -Parent
    $resourceName = Split-Path $resourceDir -Leaf

    if ($skipResources -contains $resourceName) {
        Write-Host "Skip $resourceName"
        return
    }

    $manifestChanged = $false

    if ($content -notmatch 'theme_nui_consumer') {
        if ($content -match 'client_scripts\s*\{') {
            $content = $content -replace '(client_scripts\s*\{)', "`$1`r`n$consumerLine"
            $manifestChanged = $true
        }
        elseif ($content -match "client_script\s+'") {
            $content = $content + "`r`nclient_script '@mrp_hud/client/theme_nui_consumer.lua'"
            $manifestChanged = $true
        }
        else {
            $block = "`r`nclient_scripts {`r`n$consumerLine`r`n}`r`n"
            if ($content -match 'server_scripts') {
                $content = $content -replace '(server_scripts)', "$block`$1"
            }
            else {
                $content += $block
            }
            $manifestChanged = $true
        }
    }

    if ($manifestChanged) {
        [System.IO.File]::WriteAllText($manifestPath, $content)
        Write-Host "Manifest: $resourceName"
    }

    $htmlPath = Join-Path $resourceDir ($uiPage -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $htmlPath)) {
        Write-Host "  Missing HTML: $resourceName -> $uiPage"
        return
    }

    $html = [System.IO.File]::ReadAllText($htmlPath)
    if ($html -match 'theme\.js') { return }

    $injection = '    <script src="nui://mrp_fonts/html/theme.js"></script>'
    if ($html -notmatch 'ui\.css' -and $html -notmatch 'theme\.css') {
        $injection = "    <link rel=`"stylesheet`" href=`"nui://mrp_fonts/html/theme.css`" />`r`n$injection"
    }

    if ($html -match '</head>') {
        $html = $html -replace '</head>', "$injection`r`n</head>"
        [System.IO.File]::WriteAllText($htmlPath, $html)
        Write-Host "  HTML: $resourceName"
    }
}

Write-Host "Done."
