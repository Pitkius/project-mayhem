# Deado clothing chunked push - mazesni chunk'ai + auto-retry (HTTP 408 fix)
# Paleisk TIK is CMD/PowerShell, NE Cursor!
param(
    [string]$Repo = (Join-Path $PSScriptRoot '..'),
    [string]$SourceCommit = 'aa3b6bf4',
    [string]$Branch = 'deado-clothing-pack',
    [int]$BatchSize = 25,
    [int]$StartFromChunk = 1,
    [int]$MaxRetries = 8,
    [int]$RetryDelaySec = 45,
    [switch]$SyncOnly,
    [string]$LogFile = (Join-Path $PSScriptRoot 'push-deado-chunked.log')
)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path -LiteralPath $Repo).Path
$DeadoPrefix = 'resources/[clothing]/fivempro_deado_clothing'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line
    Write-Host $line
}

function Invoke-RepoGit {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    & git -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw ('git {0} failed with exit code {1}' -f ($GitArgs -join ' '), $LASTEXITCODE)
    }
}

function Invoke-RepoGitQuiet {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git -C $Repo @GitArgs 2>&1
    $ErrorActionPreference = $prev
    if ($LASTEXITCODE -ne 0) {
        throw ('git {0} failed: {1}' -f ($GitArgs -join ' '), ($out -join ' '))
    }
    return @($out)
}

function Test-IsDeadoFile {
    param([string]$File)
    return ($File -eq 'cfg/20_qb.cfg' -or $File.StartsWith("$DeadoPrefix/"))
}

function Test-StreamFile {
    param([string]$File, [string]$Folder = '')
    if (-not (Test-IsDeadoFile $File)) { return $false }
    $marker = if ($Folder) { "/stream/$Folder/" } else { '/stream/' }
    if (-not $File.Contains($marker)) { return $false }
    if (-not $Folder) {
        return ($File.Substring($File.IndexOf('/stream/') + 8) -notmatch '/')
    }
    return $true
}

function Get-StreamFolder {
    param([string]$File)
    if ($File -notmatch '/stream/([^/]+)/') { return $null }
    return $Matches[1]
}

function Get-AheadCount {
    $count = Invoke-RepoGitQuiet rev-list --count "origin/$Branch..$Branch"
    return [int]$count[0]
}

function Invoke-GitPush {
    param([string]$RefSpec)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git -C $Repo `
        -c http.postBuffer=524288000 `
        -c http.lowSpeedLimit=0 `
        -c http.lowSpeedTime=999999 `
        -c http.version=HTTP/1.1 `
        -c pack.threads=1 `
        push origin $RefSpec 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return @{ Ok = ($code -eq 0); Output = ($out -join ' ') }
}

function Push-WithRetry {
    param([string]$Label = 'push')
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Log ('Push bandymas {0}/{1}: {2}' -f $attempt, $MaxRetries, $Label)
        $result = Invoke-GitPush -RefSpec "HEAD:refs/heads/$Branch"
        if ($result.Ok) {
            Write-Log ('OK: {0}' -f $Label)
            return
        }
        Write-Log ('KLAIDA ({0}): {1}' -f $attempt, $result.Output)
        if ($attempt -lt $MaxRetries) {
            Write-Log ('Laukiama {0}s...' -f $RetryDelaySec)
            Start-Sleep -Seconds $RetryDelaySec
        }
    }
    throw ('Push nepavyko po {0} bandymu: {1}' -f $MaxRetries, $Label)
}

function Sync-PendingCommits {
    $ahead = Get-AheadCount
    if ($ahead -le 0) {
        Write-Log 'Nera nepushintu commitu.'
        return
    }
    Write-Log ('Rasta {0} nepushintu commitu - pushinama po viena...' -f $ahead)
    while ($true) {
        $ahead = Get-AheadCount
        if ($ahead -le 0) { break }

        $pending = Invoke-RepoGitQuiet rev-list --reverse "origin/$Branch..$Branch"
        $oldest = $pending[0]
        $msg = (Invoke-RepoGitQuiet log -1 '--format=%s' $oldest)[0]
        Write-Log ('--- Likusiu push: {0} / {1} / {2} ---' -f $ahead, $oldest, $msg)

        $pushed = $false
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            Write-Log ('Push bandymas {0}/{1}' -f $attempt, $MaxRetries)
            $refSpec = '{0}:refs/heads/{1}' -f $oldest, $Branch
            $result = Invoke-GitPush -RefSpec $refSpec
            if ($result.Ok) {
                Write-Log ('OK: {0}' -f $msg)
                $pushed = $true
                break
            }
            Write-Log ('KLAIDA ({0}): {1}' -f $attempt, $result.Output)
            if ($attempt -lt $MaxRetries) {
                Write-Log ('Laukiama {0}s...' -f $RetryDelaySec)
                Start-Sleep -Seconds $RetryDelaySec
            }
        }
        if (-not $pushed) {
            throw ('Nepavyko pushinti: {0}' -f $msg)
        }
    }
    Write-Log 'Visi laukiantys commitai nupushinti.'
}

function Add-FilesFromSource {
    param([string[]]$Paths)
    foreach ($path in $Paths) {
        if (-not (Test-IsDeadoFile $path)) { throw ('Blocked path: {0}' -f $path) }
        Invoke-RepoGit -c core.longpaths=true checkout $SourceCommit -- $path
    }
}

function New-ChunkCommit {
    param([string]$Message, [string[]]$Paths)
    Add-FilesFromSource -Paths $Paths
    foreach ($path in $Paths) {
        Invoke-RepoGit add -- $path
    }
    & git -C $Repo diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Log ('SKIP: {0}' -f $Message)
        return $false
    }
    Invoke-RepoGit -c user.name=chunked-push -c user.email=chunked@local commit -m $Message
    return $true
}

function Split-Files {
    param([string[]]$Files, [int]$Size = $BatchSize)
    $chunks = [System.Collections.Generic.List[string[]]]::new()
    for ($i = 0; $i -lt $Files.Count; $i += $Size) {
        $end = [Math]::Min($i + $Size - 1, $Files.Count - 1)
        $chunks.Add($Files[$i..$end])
    }
    return $chunks
}

function Add-Chunk {
    param($List, [string]$Name, [string[]]$Paths)
    if ($Paths -and $Paths.Count -gt 0) {
        $List.Add([pscustomobject]@{ Name = $Name; Paths = $Paths })
    }
}

function Build-ChunkPlan {
    $allFiles = @(
        Invoke-RepoGitQuiet diff-tree --no-commit-id --name-only -r $SourceCommit |
        Where-Object { Test-IsDeadoFile $_ }
    )

    $baseFiles = @(
        'cfg/20_qb.cfg',
        "$DeadoPrefix/fxmanifest.lua",
        "$DeadoPrefix/mp_m_freemode_01_mp_m_knocks.meta"
    ) + @($allFiles | Where-Object { Test-StreamFile -File $_ })

    $streamMarker = "$DeadoPrefix/stream/"
    $folderGroups = $allFiles |
        Where-Object { $_.Contains($streamMarker) -and ($_ -match '/stream/[^/]+/') } |
        ForEach-Object { Get-StreamFolder $_ } |
        Where-Object { $_ } |
        Group-Object |
        Sort-Object Name

    $chunks = [System.Collections.Generic.List[object]]::new()
    Add-Chunk -List $chunks -Name '01-base' -Paths $baseFiles

    $idx = 2
    foreach ($group in $folderGroups) {
        $folder = $group.Name
        $files = @($allFiles | Where-Object { Test-StreamFile -File $_ -Folder $folder })
        $parts = Split-Files -Files $files
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $suffix = if ($parts.Count -eq 1) { $folder } else { '{0}-part{1}' -f $folder, ($i + 1) }
            Add-Chunk -List $chunks -Name ('{0:D2}-{1}' -f $idx, $suffix) -Paths $parts[$i]
            $idx++
        }
    }

    return ,@($chunks, $allFiles.Count)
}

Write-Log '=== DEADO CHUNKED PUSH ==='
Write-Log ('Batch={0} StartFrom={1} Retry={2}x{3}s' -f $BatchSize, $StartFromChunk, $MaxRetries, $RetryDelaySec)

Invoke-RepoGit fetch origin
$onBranch = (Invoke-RepoGitQuiet branch --show-current)[0]
if ($onBranch -ne $Branch) {
    Invoke-RepoGit checkout $Branch
}

Sync-PendingCommits
if ($SyncOnly) {
    Write-Log '=== SYNC BAIGTAS ==='
    exit 0
}

$plan = Build-ChunkPlan
$chunks = $plan[0]
$totalFiles = $plan[1]
Write-Log ('Chunku: {0} Deado failu: {1}' -f $chunks.Count, $totalFiles)

$done = 0
foreach ($chunk in $chunks) {
    $done++
    if ($done -lt $StartFromChunk) { continue }

    $label = $chunk.Name
    $count = @($chunk.Paths).Count
    Write-Log ('--- {0}/{1}: {2} ({3} failu) ---' -f $done, $chunks.Count, $label, $count)

    $committed = New-ChunkCommit -Message ('Deado clothing chunk: {0}' -f $label) -Paths $chunk.Paths
    if ($committed) {
        Push-WithRetry -Label $label
    } else {
        $ahead = Get-AheadCount
        if ($ahead -gt 0) {
            Write-Log ('SKIP bet yra {0} nepushintu - sync...' -f $ahead)
            Sync-PendingCommits
        }
    }
}

Sync-PendingCommits
Write-Log '=== BAIGTA ==='
