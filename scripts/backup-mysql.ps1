# Optional local Windows helper (VPS primary is backup-mysql.sh + cron).
# Requires mysqldump/mariadb-dump and gzip on PATH (MySQL client / Git / scoop).
#
# Setup:
#   copy scripts\backup-mysql.env.example scripts\backup-mysql.env
#   # edit credentials
#   powershell -ExecutionPolicy Bypass -File scripts\backup-mysql.ps1
#
# Task Scheduler (daily 04:00):
#   Action: powershell.exe
#   Args:   -ExecutionPolicy Bypass -File "C:\path\to\project-mayhem\scripts\backup-mysql.ps1"
#
# Retention (same policy as .sh):
#   Keep newest KEEP_DAILY (7); plus KEEP_WEEKLY (4) one-per-ISO-week from older;
#   drop age > MAX_AGE_DAYS (35); trim oldest if total > MAX_TOTAL_MB (2048).

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$CleanupOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

function Import-DotEnv {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $i = $line.IndexOf("=")
        if ($i -lt 1) { return }
        $name = $line.Substring(0, $i).Trim()
        $value = $line.Substring($i + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        Set-Item -Path "Env:$name" -Value $value
    }
    return $true
}

$envCandidates = @(
    $env:BACKUP_ENV,
    (Join-Path $env:USERPROFILE ".config\mrp-mysql-backup.env"),
    (Join-Path $ScriptDir "backup-mysql.env")
) | Where-Object { $_ }
$loaded = $false
foreach ($c in $envCandidates) {
    if (Import-DotEnv $c) { $loaded = $true; break }
}

$BackupDir = if ($env:BACKUP_DIR) { $env:BACKUP_DIR } else { Join-Path $RepoDir "backups\mysql" }
$KeepDaily = if ($env:KEEP_DAILY) { [int]$env:KEEP_DAILY } else { 7 }
$KeepWeekly = if ($env:KEEP_WEEKLY) { [int]$env:KEEP_WEEKLY } else { 4 }
$MaxAgeDays = if ($env:MAX_AGE_DAYS) { [int]$env:MAX_AGE_DAYS } else { 35 }
$MaxTotalMb = if ($env:MAX_TOTAL_MB) { [int]$env:MAX_TOTAL_MB } else { 2048 }
$LogFile = if ($env:LOG_FILE) { $env:LOG_FILE } else { Join-Path $BackupDir "backup.log" }

function Write-BackupLog([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Parse-MysqlUri([string]$Uri) {
    $Uri = $Uri.Trim().Trim('"')
    if ($Uri -notmatch '^mysql://([^:]+):([^@]+)@([^:/]+)(?::(\d+))?/([^?]+)') {
        throw "Cannot parse mysql URI"
    }
    $env:MYSQL_USER = [Uri]::UnescapeDataString($Matches[1])
    $env:MYSQL_PASSWORD = [Uri]::UnescapeDataString($Matches[2])
    $env:MYSQL_HOST = $Matches[3]
    $env:MYSQL_PORT = if ($Matches[4]) { $Matches[4] } else { "3306" }
    $env:MYSQL_DATABASE = ($Matches[5] -split '\?')[0]
}

function Resolve-Credentials {
    if ($env:MYSQL_CONNECTION_STRING) {
        Parse-MysqlUri $env:MYSQL_CONNECTION_STRING
    } elseif ($env:MYSQL_CFG -and (Test-Path $env:MYSQL_CFG)) {
        $line = Select-String -Path $env:MYSQL_CFG -Pattern '^\s*set\s+mysql_connection_string\s+' | Select-Object -Last 1
        if (-not $line) { throw "No mysql_connection_string in $($env:MYSQL_CFG)" }
        $raw = ($line.Line -replace '^\s*set\s+mysql_connection_string\s+', '').Trim().Trim('"')
        Parse-MysqlUri $raw
    } elseif (-not $env:MYSQL_USER -or -not $env:MYSQL_PASSWORD -or -not $env:MYSQL_DATABASE) {
        $guess = Join-Path $RepoDir "cfg\00_base.cfg"
        if (Test-Path $guess) {
            $line = Select-String -Path $guess -Pattern '^\s*set\s+mysql_connection_string\s+' | Select-Object -Last 1
            if ($line) {
                $raw = ($line.Line -replace '^\s*set\s+mysql_connection_string\s+', '').Trim().Trim('"')
                Parse-MysqlUri $raw
            }
        }
    }
    if (-not $env:MYSQL_USER -or -not $env:MYSQL_PASSWORD -or -not $env:MYSQL_DATABASE) {
        throw "Missing DB credentials. See scripts/backup-mysql.env.example"
    }
    if (-not $env:MYSQL_HOST) { $env:MYSQL_HOST = "127.0.0.1" }
    if (-not $env:MYSQL_PORT) { $env:MYSQL_PORT = "3306" }
}

function Get-BackupFiles {
    Get-ChildItem -Path $BackupDir -Filter "*.sql.gz" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
}

function Invoke-RetentionCleanup {
    $files = @(Get-BackupFiles)
    $keep = [System.Collections.Generic.HashSet[string]]::new()
    for ($i = 0; $i -lt [Math]::Min($KeepDaily, $files.Count); $i++) {
        [void]$keep.Add($files[$i].FullName)
    }
    $weekKept = @{}
    $weeklyCount = 0
    for ($i = $KeepDaily; $i -lt $files.Count; $i++) {
        $f = $files[$i]
        $cal = [cultureinfo]::InvariantCulture.Calendar
        $week = "{0}-W{1:D2}" -f $cal.GetYear($f.LastWriteTime), $cal.GetWeekOfYear($f.LastWriteTime, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
        if (-not $weekKept.ContainsKey($week) -and $weeklyCount -lt $KeepWeekly) {
            $weekKept[$week] = $true
            [void]$keep.Add($f.FullName)
            $weeklyCount++
        }
    }
    $newest = if ($files.Count -gt 0) { $files[0].FullName } else { $null }
    foreach ($f in $files) {
        if (-not $keep.Contains($f.FullName)) { continue }
        if ($f.FullName -eq $newest) { continue }
        $age = ((Get-Date) - $f.LastWriteTime).TotalDays
        if ($age -gt $MaxAgeDays) { [void]$keep.Remove($f.FullName) }
    }
    $toDelete = New-Object System.Collections.Generic.List[string]
    for ($i = $files.Count - 1; $i -ge 0; $i--) {
        if (-not $keep.Contains($files[$i].FullName)) {
            $toDelete.Add($files[$i].FullName)
        }
    }
    $total = ($files | Where-Object { $keep.Contains($_.FullName) } | Measure-Object -Property Length -Sum).Sum
    if (-not $total) { $total = 0 }
    $maxBytes = [int64]$MaxTotalMb * 1MB
    if ($total -gt $maxBytes) {
        for ($i = $files.Count - 1; $i -ge 1; $i--) {
            if ($total -le $maxBytes) { break }
            $f = $files[$i]
            if (-not $keep.Contains($f.FullName)) { continue }
            [void]$keep.Remove($f.FullName)
            $toDelete.Add($f.FullName)
            $total -= $f.Length
        }
    }
    $count = 0
    foreach ($path in $toDelete) {
        if ($DryRun) {
            Write-BackupLog "DRY-RUN delete: $path"
        } else {
            Remove-Item -Force -LiteralPath $path
            Write-BackupLog "Deleted old backup: $(Split-Path $path -Leaf)"
        }
        $count++
    }
    Write-BackupLog "Cleanup done (removed $count file(s)). keep_daily=$KeepDaily keep_weekly=$KeepWeekly max_age_days=$MaxAgeDays max_total_mb=$MaxTotalMb"
}

function Invoke-Dump {
    Resolve-Credentials
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $out = Join-Path $BackupDir ("{0}_{1}.sql.gz" -f $env:MYSQL_DATABASE, $stamp)
    if ($DryRun) {
        Write-BackupLog "DRY-RUN dump would write: $out"
        return
    }
    $dumper = Get-Command mysqldump -ErrorAction SilentlyContinue
    if (-not $dumper) { $dumper = Get-Command mariadb-dump -ErrorAction SilentlyContinue }
    if (-not $dumper) { throw "mysqldump/mariadb-dump not found on PATH" }
    $gzip = Get-Command gzip -ErrorAction SilentlyContinue
    $defaults = [System.IO.Path]::GetTempFileName()
    @"
[client]
host=$($env:MYSQL_HOST)
port=$($env:MYSQL_PORT)
user=$($env:MYSQL_USER)
password=$($env:MYSQL_PASSWORD)
"@ | Set-Content -Path $defaults -Encoding ASCII
    try {
        $tmp = "$out.partial"
        if ($gzip) {
            & $dumper.Source --defaults-extra-file=$defaults --single-transaction --routines --triggers --events --hex-blob --default-character-set=utf8mb4 $env:MYSQL_DATABASE |
                & $gzip.Source -c |
                Set-Content -Path $tmp -Encoding Byte
        } else {
            # Fallback without gzip: still write .sql then Compress-Archive is zip — keep .sql.gz via .NET if possible
            throw "gzip not found on PATH (install Git for Windows or gzip)"
        }
        if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) {
            throw "dump produced empty output"
        }
        Move-Item -Force $tmp $out
        $size = "{0:N1} MB" -f ((Get-Item $out).Length / 1MB)
        Write-BackupLog "OK: created $(Split-Path $out -Leaf) ($size)"
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $defaults, "$out.partial"
    }
}

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
if (-not $CleanupOnly) {
    Write-BackupLog "Starting backup host=$($env:MYSQL_HOST) db=$($env:MYSQL_DATABASE) dir=$BackupDir"
    Invoke-Dump
} else {
    Write-BackupLog "Cleanup-only mode dir=$BackupDir"
}
Invoke-RetentionCleanup
Write-BackupLog "Finished."
