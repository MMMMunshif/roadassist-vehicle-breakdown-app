param([switch]$Debug, [string]$DartDefinesFile)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectDirectory 'android/app/google-services.json'
if (!(Test-Path -LiteralPath $configPath)) { throw 'Missing android/app/google-services.json.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$adminClient = @($config.client | Where-Object { $_.client_info.android_client_info.package_name -eq 'com.roadassist.admin' })
if ($adminClient.Count -ne 1) {
    throw 'Register com.roadassist.admin in Firebase project roadassist-lk-munshif, then run scripts/configure-admin-firebase.ps1 with its downloaded google-services.json. See docs/admin_android_app.md.'
}
Push-Location -LiteralPath $projectDirectory
try {
    $buildMode = if ($Debug) { '--debug' } else { '--release' }
    $buildArguments = @('build', 'apk', $buildMode)
    if ($DartDefinesFile) {
        $resolvedDefines = (Resolve-Path -LiteralPath $DartDefinesFile).Path
        $buildArguments += "--dart-define-from-file=$resolvedDefines"
    }
    $buildArguments += '--dart-define=ADMIN_PORTAL=true'
    & flutter @buildArguments
    if ($LASTEXITCODE -ne 0) { throw 'Admin APK build failed; see Flutter output above.' }
    $apkName = if ($Debug) { 'app-debug.apk' } else { 'app-release.apk' }
    $source = Join-Path $projectDirectory "build/app/outputs/flutter-apk/$apkName"
    $output = Join-Path $projectDirectory 'build/app/outputs/flutter-apk/RoadAssist-Admin.apk'
    Copy-Item -LiteralPath $source -Destination $output -Force
    Write-Host "Admin APK ready: $output"
} finally { Pop-Location }
