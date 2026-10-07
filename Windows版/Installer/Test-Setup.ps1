[CmdletBinding()]
param(
    [string]$SetupPath = (Join-Path $PSScriptRoot 'Output\Setup.exe'),
    [string]$TestRoot = (Join-Path $PSScriptRoot 'TestArea\中文 安装目录'),
    [switch]$ProgramFilesTest
)

$ErrorActionPreference = 'Stop'
$appId = '{4D229622-C3A1-4EF6-AC43-7B28EF7B47F1}_is1'
$uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$appId"
$configDir = Join-Path $env:LOCALAPPDATA 'TGLab\是否认同'
$logDir = Join-Path $PSScriptRoot 'TestLogs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $SetupPath)) { throw "找不到 $SetupPath" }

function Invoke-Setup([string]$Directory, [string]$LogName) {
    $logPath = Join-Path $logDir $LogName
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$Directory`"", "/LOG=`"$logPath`"")
    $process = Start-Process -FilePath $SetupPath -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "安装失败：$LogName，退出码 $($process.ExitCode)" }
    if (-not (Test-Path -LiteralPath (Join-Path $Directory '是否认同.exe'))) { throw '安装后缺少主程序。' }
    if (-not (Test-Path -LiteralPath $uninstallKey)) { throw '安装后未找到“已安装的应用”登记。' }
}

function Invoke-Uninstall([bool]$DeleteConfig, [string]$LogName) {
    $uninstaller = (Get-ItemProperty -LiteralPath $uninstallKey).UninstallString.Trim('"')
    $logPath = Join-Path $logDir $LogName
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$logPath`"")
    if ($DeleteConfig) { $arguments += '/DELETECONFIG' }
    $process = Start-Process -FilePath $uninstaller -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "卸载失败：$LogName，退出码 $($process.ExitCode)" }
    if (Test-Path -LiteralPath $uninstallKey) { throw '卸载登记未被删除。' }
}

$target = if ($ProgramFilesTest) { Join-Path $env:ProgramFiles 'TGLab\是否认同' } else { $TestRoot }

Invoke-Setup $target '01-fresh-install.log'
Invoke-Setup $target '02-upgrade-overwrite.log'

New-Item -ItemType Directory -Path $configDir -Force | Out-Null
$keepMarker = Join-Path $configDir 'keep-test.marker'
Set-Content -LiteralPath $keepMarker -Value 'keep'
Invoke-Uninstall $false '03-uninstall-keep.log'
if (-not (Test-Path -LiteralPath $keepMarker)) { throw '保留配置卸载测试失败。' }

Invoke-Setup $target '04-reinstall.log'
$deleteMarker = Join-Path $configDir 'delete-test.marker'
Set-Content -LiteralPath $deleteMarker -Value 'delete'
Invoke-Uninstall $true '05-uninstall-delete.log'
if (Test-Path -LiteralPath $configDir) { throw '删除配置卸载测试失败。' }

[pscustomobject]@{
    FreshInstall = '通过'
    UpgradeOverwrite = '通过'
    InstalledAppsRegistration = '通过'
    KeepConfiguration = '通过'
    DeleteConfiguration = '通过'
    ChineseAndSpacesPath = if ($ProgramFilesTest) { '未在本次模式测试' } else { '通过' }
    ProgramFiles = if ($ProgramFilesTest) { '通过' } else { '未在本次模式测试' }
} | Format-List
