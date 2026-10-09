param(
    [Parameter(Mandatory = $true)]
    [string]$EnvPath,
    [Parameter(Mandatory = $true)]
    [string]$ServiceName
)

$ErrorActionPreference = "Stop"

$vals = New-Object System.Collections.Generic.List[string]
Get-Content -LiteralPath $EnvPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    if ($line -match "^[A-Za-z0-9_]+=") {
        $vals.Add($line)
    }
}

if (-not ($vals | Where-Object { $_.StartsWith("ASPNETCORE_ENVIRONMENT=") })) {
    $vals.Add("ASPNETCORE_ENVIRONMENT=Production")
}

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
if (-not (Test-Path -LiteralPath $regPath)) {
    Write-Host "ERROR: Windows service '$ServiceName' is not installed yet."
    exit 1
}

New-ItemProperty -Path $regPath -Name Environment -PropertyType MultiString -Value $vals.ToArray() -Force | Out-Null
Write-Host "OK: service environment set from .env ($($vals.Count) keys)."
exit 0
