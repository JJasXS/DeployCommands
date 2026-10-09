param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "ERROR: .env file not found: $Path"
    exit 1
}

$map = @{}
Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $eq = $line.IndexOf("=")
    if ($eq -lt 1) { return }
    $name = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim()
    $map[$name] = $value
}

$required = @(
    "ASPNETCORE_URLS",
    "DatabaseProvider",
    "SqlAccount__DatabasePath",
    "SqlAccount__DbUser",
    "SqlAccount__DbPassword",
    "Jwt__Secret",
    "VITE_API_URL"
)

$missing = @()
foreach ($key in $required) {
    if (-not $map.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($map[$key])) {
        $missing += $key
    }
}

if ($missing.Count -gt 0) {
    Write-Host "ERROR: .env is missing:"
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 1
}

if ($map["ASPNETCORE_URLS"] -notmatch ":5000\b") {
    Write-Host "ERROR: ASPNETCORE_URLS must listen on port 5000."
    Write-Host "  Current: $($map['ASPNETCORE_URLS'])"
    exit 1
}

if ($map["VITE_API_URL"] -notmatch ":5000/") {
    Write-Host "ERROR: VITE_API_URL must point at the API on port 5000."
    Write-Host "  Current: $($map['VITE_API_URL'])"
    exit 1
}

Write-Host "OK: .env has the StudentPortal keys."
exit 0
