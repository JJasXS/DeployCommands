param(
    [Parameter(Mandatory = $true)]
    [string]$EnvPath
)

if (-not (Test-Path -LiteralPath $EnvPath)) {
    Write-Host "ERROR: .env file missing: $EnvPath"
    exit 2
}

$map = @{}
Get-Content -LiteralPath $EnvPath | ForEach-Object {
    $line = $_
    if ($line -match '^\s*#') { return }
    if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$') {
        $map[$matches[1]] = $matches[2].Trim().Trim('"')
    }
}

$need = @('TENANT_CODE', 'AWS_REGION', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY')
$bad = @()
foreach ($k in $need) {
    if (-not $map.ContainsKey($k) -or [string]::IsNullOrWhiteSpace($map[$k])) {
        $bad += $k
    }
}

# Soft length checks so empty placeholders fail before publish
if ($map.ContainsKey('AWS_ACCESS_KEY_ID') -and -not [string]::IsNullOrWhiteSpace($map['AWS_ACCESS_KEY_ID']) -and $map['AWS_ACCESS_KEY_ID'].Length -lt 16) {
    $bad += 'AWS_ACCESS_KEY_ID(too short)'
}
if ($map.ContainsKey('AWS_SECRET_ACCESS_KEY') -and -not [string]::IsNullOrWhiteSpace($map['AWS_SECRET_ACCESS_KEY']) -and $map['AWS_SECRET_ACCESS_KEY'].Length -lt 20) {
    $bad += 'AWS_SECRET_ACCESS_KEY(too short)'
}

$tenantApiUrl = ''
if ($map.ContainsKey('TENANT_BOOTSTRAP_API_URL') -and -not [string]::IsNullOrWhiteSpace($map['TENANT_BOOTSTRAP_API_URL'])) {
    $tenantApiUrl = $map['TENANT_BOOTSTRAP_API_URL'].Trim()
} elseif ($map.ContainsKey('TenantBootstrap__AwsApiBaseUrl') -and -not [string]::IsNullOrWhiteSpace($map['TenantBootstrap__AwsApiBaseUrl'])) {
    $tenantApiUrl = $map['TenantBootstrap__AwsApiBaseUrl'].Trim()
}
if ([string]::IsNullOrWhiteSpace($tenantApiUrl)) {
    $bad += 'TENANT_BOOTSTRAP_API_URL'
}

if ($bad.Count -gt 0) {
    Write-Host ("ERROR: missing/empty: " + ($bad -join ', '))
    exit 3
}

Write-Host ("OK: TENANT_CODE=" + $map['TENANT_CODE'] + "  SDK mode  AWS_REGION=" + $map['AWS_REGION'])
if ($map.ContainsKey('SDK_SECRET_ID') -and -not [string]::IsNullOrWhiteSpace($map['SDK_SECRET_ID'])) {
    Write-Host ("OK: SDK_SECRET_ID=" + $map['SDK_SECRET_ID'])
} else {
    Write-Host ("OK: SDK secret default proacc/tenant/" + $map['TENANT_CODE'] + "/sdkConnections")
}
exit 0
