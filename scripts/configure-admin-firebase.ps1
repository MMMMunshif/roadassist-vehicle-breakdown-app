param([Parameter(Mandatory=$true)][string]$DownloadedConfig)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$target = Join-Path $projectDirectory 'android/app/google-services.json'
$existing = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
$downloaded = Get-Content -LiteralPath $DownloadedConfig -Raw | ConvertFrom-Json
if ($downloaded.project_info.project_id -ne $existing.project_info.project_id) {
    throw 'The downloaded config belongs to a different Firebase project.'
}
$admin = @($downloaded.client | Where-Object { $_.client_info.android_client_info.package_name -eq 'com.roadassist.admin' })
if ($admin.Count -ne 1) { throw 'Download the Firebase Android config for package com.roadassist.admin.' }
# Preserve every existing client, including the normal Driver/Provider app.
$existing.client = @($existing.client | Where-Object { $_.client_info.android_client_info.package_name -ne 'com.roadassist.admin' }) + $admin
$existing | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host 'Admin Firebase configuration added. Normal app client preserved.'
