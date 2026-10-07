[CmdletBinding()]
param(
    [string]$AndroidSdkDirectory,
    [string]$JavaSdkDirectory,
    [string]$SigningPassword = $env:SFR_ANDROID_SIGNING_PASSWORD
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$projectFile = Join-Path $projectRoot '是否认同.Android.csproj'
$keystore = Join-Path $projectRoot 'Signing\tglab-shifourentong.keystore'
$releaseDirectory = Join-Path $projectRoot '发布'
$releaseApk = Join-Path $releaseDirectory 'ShiFouRenTong-Android-v1.1.0.apk'

if ([string]::IsNullOrWhiteSpace($AndroidSdkDirectory)) {
    $AndroidSdkDirectory = Join-Path $workspaceRoot '.android-sdk'
}

if ([string]::IsNullOrWhiteSpace($JavaSdkDirectory)) {
    $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME')
    if (-not [string]::IsNullOrWhiteSpace($javaHome)) {
        $JavaSdkDirectory = $javaHome
    }
}

if (-not (Test-Path -LiteralPath $AndroidSdkDirectory -PathType Container)) {
    throw "找不到 Android SDK：$AndroidSdkDirectory"
}
if ([string]::IsNullOrWhiteSpace($JavaSdkDirectory) -or
    -not (Test-Path -LiteralPath $JavaSdkDirectory -PathType Container)) {
    throw '找不到 JDK。请设置 JAVA_HOME，或使用 -JavaSdkDirectory 指定 JDK 17。'
}
if (-not (Test-Path -LiteralPath $keystore -PathType Leaf)) {
    throw "找不到签名密钥：$keystore"
}
if ([string]::IsNullOrWhiteSpace($SigningPassword)) {
    throw '请先设置环境变量 SFR_ANDROID_SIGNING_PASSWORD。'
}

$env:DOTNET_CLI_HOME = Join-Path $workspaceRoot '.dotnet-android'

dotnet publish $projectFile `
    -c Release `
    -f net8.0-android `
    -p:AndroidSdkDirectory=$AndroidSdkDirectory `
    -p:JavaSdkDirectory=$JavaSdkDirectory `
    -p:AndroidKeyStore=true `
    -p:AndroidSigningKeyStore=$keystore `
    -p:AndroidSigningKeyAlias=tglab-shifourentong `
    -p:AndroidSigningKeyPass=$SigningPassword `
    -p:AndroidSigningStorePass=$SigningPassword `
    -p:AndroidPackageFormat=apk

if ($LASTEXITCODE -ne 0) {
    throw "Android 发布失败，退出代码：$LASTEXITCODE"
}

$signedApk = Join-Path $projectRoot 'bin\Release\net8.0-android\publish\com.tglab.shifourentong-Signed.apk'
if (-not (Test-Path -LiteralPath $signedApk -PathType Leaf)) {
    throw "发布完成，但没有找到签名 APK：$signedApk"
}

New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
Copy-Item -LiteralPath $signedApk -Destination $releaseApk -Force

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $releaseApk).Hash.ToLowerInvariant()
$hashLine = "$hash *$(Split-Path -Leaf $releaseApk)"
[IO.File]::WriteAllText(
    (Join-Path $releaseDirectory 'SHA256SUMS'),
    $hashLine + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))

Write-Host "Android APK：$releaseApk"
Write-Host "SHA-256：$hash"
