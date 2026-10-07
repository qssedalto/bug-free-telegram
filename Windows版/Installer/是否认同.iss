#define MyAppName "是否认同"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "TGLab"
#define MyAppExeName "是否认同.exe"
#ifndef SourceRoot
  #define SourceRoot ".."
#endif
#ifndef PublishDir
  #define PublishDir "artifacts\publish"
#endif

[Setup]
AppId={{4D229622-C3A1-4EF6-AC43-7B28EF7B47F1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://tglab.example/
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} 安装程序
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
DefaultDirName={autopf}\TGLab\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=Setup
SetupIconFile={#SourceRoot}\Assets\AppIcon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
AllowNoIcons=yes
WizardStyle=modern
WizardSizePercent=110
Compression=lzma2/ultra64
SolidCompression=yes
SetupLogging=yes
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes
ChangesAssociations=no
MinVersion=10.0

[Languages]
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式："; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe"; DestDir: "{tmp}"; DestName: "windowsdesktop-runtime-8-win-x64.exe"; ExternalSize: 70000000; Flags: external download ignoreversion; Check: ShouldInstallRuntime

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\windowsdesktop-runtime-8-win-x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "正在安装 Microsoft .NET 8 Desktop Runtime，请稍候……"; Flags: waituntilterminated runhidden; Check: ShouldInstallRuntime; AfterInstall: VerifyRuntimeInstalled
Filename: "{app}\{#MyAppExeName}"; Description: "运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
var
  RuntimeRequired: Boolean;
  DeleteUserConfig: Boolean;

function HasRuntime8VersionInDirectory(const RuntimeRoot: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(AddBackslash(RuntimeRoot) + '8.*', FindRec) then
  begin
    try
      repeat
        if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
           (FindRec.Name <> '.') and (FindRec.Name <> '..') then
        begin
          Result := True;
          Break;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

function HasRuntime8VersionInRegistry(RootKey: Integer): Boolean;
var
  ValueNames: TArrayOfString;
  Index: Integer;
begin
  Result := False;
  if RegGetValueNames(
       RootKey,
       'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App',
       ValueNames) then
  begin
    for Index := 0 to GetArrayLength(ValueNames) - 1 do
      if Pos('8.', ValueNames[Index]) = 1 then
      begin
        Result := True;
        Exit;
      end;
  end;
end;

function IsWindowsDesktopRuntime8Installed: Boolean;
var
  DotNetRoot: String;
begin
  { .NET 的 x64 安装登记可能由 32 位安装器写入注册表 32 位视图，两个视图都检查。 }
  Result := HasRuntime8VersionInRegistry(HKLM64) or
            HasRuntime8VersionInRegistry(HKLM32);
  if Result then
    Exit;

  { 再检查 x64 shared host 登记的真实目录，避免自定义 Program Files 位置造成误判。 }
  if RegQueryStringValue(
       HKLM64,
       'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost',
       'Path', DotNetRoot) then
  begin
    Result := HasRuntime8VersionInDirectory(
      AddBackslash(DotNetRoot) + 'shared\Microsoft.WindowsDesktop.App');
    if Result then
      Exit;
  end;

  { 最后检查 Windows 标准的 64 位 Program Files 目录。 }
  Result := HasRuntime8VersionInDirectory(
    ExpandConstant('{commonpf64}\dotnet\shared\Microsoft.WindowsDesktop.App'));
end;

function ShouldInstallRuntime: Boolean;
begin
  Result := RuntimeRequired;
end;

function InitializeSetup: Boolean;
begin
  RuntimeRequired := not IsWindowsDesktopRuntime8Installed;
  Result := True;
  if RuntimeRequired then
  begin
    Result := MsgBox(
      '未检测到 64 位 Microsoft .NET 8 Desktop Runtime。' + #13#10 + #13#10 +
      '“是否认同”需要该 Windows 运行时。是否现在从微软官方下载并安装？',
      mbConfirmation, MB_YESNO) = IDYES;
    if not Result then
      MsgBox('未安装必需的运行时，安装已取消，电脑中不会写入程序文件。', mbInformation, MB_OK);
  end;
end;

procedure VerifyRuntimeInstalled;
begin
  if not IsWindowsDesktopRuntime8Installed then
    RaiseException('Microsoft .NET 8 Desktop Runtime 安装未成功或被取消，无法继续安装“是否认同”。');
  RuntimeRequired := False;
end;

function HasUninstallParameter(const ParameterName: String): Boolean;
begin
  Result := Pos('/' + Uppercase(ParameterName), Uppercase(GetCmdTail)) > 0;
end;

function InitializeUninstall: Boolean;
var
  Choice: Integer;
begin
  DeleteUserConfig := False;
  if UninstallSilent then
  begin
    DeleteUserConfig := HasUninstallParameter('DELETECONFIG');
    Result := True;
    Exit;
  end;

  Choice := MsgBox(
    '请选择卸载方式：' + #13#10 + #13#10 +
    '“是”——卸载程序，但保留当前版本配置' + #13#10 +
    '“否”——卸载程序，并删除当前版本配置' + #13#10 +
    '“取消”——取消卸载',
    mbConfirmation, MB_YESNOCANCEL);

  Result := Choice <> IDCANCEL;
  DeleteUserConfig := Choice = IDNO;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  UserConfigDir: String;
begin
  if (CurUninstallStep = usPostUninstall) and DeleteUserConfig then
  begin
    UserConfigDir := ExpandConstant('{localappdata}\TGLab\{#MyAppName}');
    if DirExists(UserConfigDir) then
      DelTree(UserConfigDir, True, True, True);
  end;
end;
