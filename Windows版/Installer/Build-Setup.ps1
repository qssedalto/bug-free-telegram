[CmdletBinding()]
param(
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$installerDir = $PSScriptRoot
$sourceRoot = Split-Path -Parent $installerDir
$projectPath = Join-Path $sourceRoot '是否认同.csproj'
$publishDir = Join-Path $installerDir 'artifacts\publish'
$outputDir = Join-Path $installerDir 'Output'
$issPath = Join-Path $installerDir '是否认同.iss'
$isccCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
)
$isccPath = $isccCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

if (-not $isccPath) {
    throw '未找到 Inno Setup 6 编译器。开发电脑请先安装 JRSoftware.InnoSetup；用户电脑不需要安装 Inno Setup。'
}

if (Test-Path -LiteralPath $publishDir) {
    Remove-Item -LiteralPath $publishDir -Recurse -Force
}
New-Item -ItemType Directory -Path $publishDir -Force | Out-Null
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

dotnet publish $projectPath `
    -c $Configuration `
    -r win-x64 `
    --self-contained false `
    -p:PublishSingleFile=false `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    -o $publishDir
if ($LASTEXITCODE -ne 0) { throw "dotnet publish 失败，退出码 $LASTEXITCODE" }

$appExe = Join-Path $publishDir '是否认同.exe'
if (-not (Test-Path -LiteralPath $appExe)) {
    throw "发布目录中缺少主程序：$appExe"
}

& $appExe --self-test
if ($LASTEXITCODE -ne 0) { throw "应用自检失败，退出码 $LASTEXITCODE" }

& $isccPath "/DSourceRoot=$sourceRoot" "/DPublishDir=$publishDir" $issPath
if ($LASTEXITCODE -ne 0) { throw "Inno Setup 编译失败，退出码 $LASTEXITCODE" }

$setupPath = Join-Path $outputDir 'Setup.exe'
if (-not (Test-Path -LiteralPath $setupPath)) {
    throw "未生成安装包：$setupPath"
}

$forbiddenPatterns = @('Qssed', 'L:\Codex', '\.codex')
$setupText = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($setupPath))
foreach ($pattern in $forbiddenPatterns) {
    if ($setupText -match [regex]::Escape($pattern)) {
        throw "安装包中检测到不应包含的开发环境信息：$pattern"
    }
}

$hash = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
$hashLine = "$hash  Setup.exe"
Set-Content -LiteralPath (Join-Path $outputDir 'SHA256SUMS.txt') -Value $hashLine -Encoding ascii

$versionInfo = (Get-Item -LiteralPath $appExe).VersionInfo
[pscustomobject]@{
    Setup = $setupPath
    SHA256 = $hash
    AppFileDescription = $versionInfo.FileDescription
    AppProductName = $versionInfo.ProductName
    AppCompany = $versionInfo.CompanyName
    FrameworkDependent = -not (Test-Path -LiteralPath (Join-Path $publishDir 'coreclr.dll'))
    PublishedFiles = (Get-ChildItem -LiteralPath $publishDir -File -Recurse).Count
} | Format-List

