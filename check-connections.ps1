$ErrorActionPreference = "Stop"
$isql = "C:\Program Files\Firebird\Firebird_5_0\isql.exe"
$envFile = "C:\Apps\SqlAccountSync\publish\.env"
$licenseMax = 10

function Read-EnvValue([string]$Path, [string]$Key) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*#') { continue }
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)\s*$") {
            return $Matches[1].Trim().Trim('"')
        }
    }
    return ""
}

function Invoke-Isql([string]$Database, [string]$SqlFile) {
    $conn = "localhost:" + ($Database -replace '\\', '/')
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $isql -q $conn -i $SqlFile 2>&1 | Out-String
    $ErrorActionPreference = $prev
    return $out
}

function Company-Name([string]$Database, [string]$SqlFile) {
    $out = Invoke-Isql $Database $SqlFile
    if ($out -match 'COMPANYNAME\s+(.*)') { return $Matches[1].Trim() }
    return ""
}

function Attachment-Rows([string]$Database, [string]$SqlFile) {
    $out = Invoke-Isql $Database $SqlFile
    $rows = @()
    $hostName = ""
    $proc = ""
    $since = ""
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -match '^HOST\s+(.*)$') {
            if ($proc -and $proc -notmatch 'isql\.exe') {
                $rows += [pscustomobject]@{ Host = $hostName; Proc = $proc; Since = $since }
            }
            $hostName = $Matches[1].Trim()
            $proc = ""
            $since = ""
        }
        elseif ($line -match '^PROC\s+(.*)$') { $proc = $Matches[1].Trim() }
        elseif ($line -match '^SINCE\s+(.*)$') { $since = $Matches[1].Trim() }
    }
    if ($proc -and $proc -notmatch 'isql\.exe') {
        $rows += [pscustomobject]@{ Host = $hostName; Proc = $proc; Since = $since }
    }
    return $rows
}

if (-not (Test-Path -LiteralPath $isql)) {
    Write-Host "ERROR: isql not found at $isql"
    exit 1
}

$password = Read-EnvValue $envFile "CENTRAL_FB_MASTERKEY"
if (-not $password) { $password = Read-EnvValue $envFile "FIREBIRD_PASSWORD" }
if (-not $password) {
    Write-Host "ERROR: CENTRAL_FB_MASTERKEY is missing in $envFile"
    exit 1
}

$env:ISC_USER = "SYSDBA"
$env:ISC_PASSWORD = $password

$nameSql = Join-Path $env:TEMP "check-conn-name.sql"
$attSql = Join-Path $env:TEMP "check-conn-att.sql"
@'
SET LIST ON;
SELECT TRIM(COMPANYNAME) AS COMPANYNAME FROM SY_PROFILE;
'@ | Set-Content -LiteralPath $nameSql -Encoding ASCII
@'
SET LIST ON;
SELECT TRIM(COALESCE(MON$REMOTE_HOST,'')) AS HOST,
       TRIM(COALESCE(MON$REMOTE_PROCESS,'')) AS PROC,
       MON$TIMESTAMP AS SINCE
FROM MON$ATTACHMENTS
WHERE COALESCE(MON$SYSTEM_FLAG, 0) = 0
  AND UPPER(COALESCE(MON$REMOTE_PROCESS,'')) NOT CONTAINING 'ISQL.EXE';
'@ | Set-Content -LiteralPath $attSql -Encoding ASCII

$files = @()
$files += Get-ChildItem "C:\eStream\SQLAccounting\DB" -Filter *.FDB -File -ErrorAction SilentlyContinue
$files += Get-ChildItem "C:\SQLData\SqlAccountSync" -Filter *.FDB -File -ErrorAction SilentlyContinue

$shown = @()
foreach ($file in ($files | Sort-Object FullName -Unique)) {
    $rows = @(Attachment-Rows $file.FullName $attSql)
    if ($rows.Count -eq 0) { continue }
    $company = Company-Name $file.FullName $nameSql
    foreach ($row in $rows) {
        $procName = Split-Path -Leaf $row.Proc
        if (-not $procName) { $procName = $row.Proc }
        $shown += [pscustomobject]@{
            Database = $file.Name
            Company = $company
            Host = $row.Host
            Process = $procName
            Since = $row.Since
        }
    }
}

Remove-Item $nameSql, $attSql -Force -ErrorAction SilentlyContinue
Remove-Item Env:ISC_PASSWORD -ErrorAction SilentlyContinue

if ($shown.Count -eq 0) {
    Write-Host "No database connections."
    exit 0
}

$shown | Format-Table -AutoSize Database, Company, Host, Process, Since
$companyCount = @($shown | Where-Object { $_.Database -ne "SYNC.FDB" }).Count
Write-Host ("Company connections: {0}    License maximum: {1}" -f $companyCount, $licenseMax)
if ($companyCount -gt $licenseMax) {
    Write-Host "Over the limit. A new SQL Accounting login will be refused."
}
exit 0
