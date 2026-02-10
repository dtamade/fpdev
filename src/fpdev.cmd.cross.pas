unit fpdev.cmd.cross;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.cross

交叉编译工具链管理


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config, fpdev.config.interfaces, fpdev.output.intf, fpdev.output.console,
  fpdev.cross.downloader, fpdev.cross.platform,
  fpdev.resource.repo, fpdev.resource.repo.types,
  fpdev.utils.fs, fpdev.utils.process,
  fpdev.i18n, fpdev.i18n.strings, fpdev.cross.tester, fpdev.cmd.cross.query;

type
  { TCrossTargetInfo - Re-exported from query helper for backward compatibility }
  TCrossTargetInfo = fpdev.cmd.cross.query.TCrossTargetQueryInfo;
  TCrossTargetArray = fpdev.cmd.cross.query.TCrossTargetQueryArray;

  { TCrossCompilerManager }
  TCrossCompilerManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;  // fpdev-repo integration (legacy)
    FBuildTester: TCrossBuildTester;     // Cross-build testing service
    FDownloader: TCrossToolchainDownloader;  // Modern toolchain downloader
    FQuery: TCrossTargetQuery;           // Target query helper

    function DownloadBinutils(const ATarget: string; const {%H-} ATargetInfo: TCrossTargetInfo; Outp: IOutput = nil): Boolean;
    function DownloadLibraries(const ATarget: string; const {%H-} ATargetInfo: TCrossTargetInfo; Outp: IOutput = nil): Boolean;
    function SetupCrossEnvironment(const ATarget: string; const {%H-} ATargetInfo: TCrossTargetInfo): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager); overload;
    constructor Create(AConfigManager: IConfigManager); overload;
    destructor Destroy; override;

    // 目标查询
    function GetAvailableTargets: TCrossTargetArray;
    function GetInstalledTargets: TCrossTargetArray;

    // 交叉编译目标管理
    function InstallTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UninstallTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListTargets(const AShowAll: Boolean = False; Outp: IOutput = nil): Boolean;
    function EnableTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function DisableTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;

    // 工具链操作
    function ShowTargetInfo(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function TestTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function BuildTest(const ATarget: string; const ASourceFile: string = ''; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;

    // 配置管理
    function ConfigureTarget(const ATarget: string; const ABinutilsPath, ALibrariesPath: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UpdateTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function CleanTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
  end;

implementation

uses fpdev.cross.targets;

{ TCrossCompilerManager }

constructor TCrossCompilerManager.Create(AConfigManager: TFPDevConfigManager);
begin
  Create(AConfigManager.AsConfigManager);
end;

constructor TCrossCompilerManager.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
  RepoConfig: TResourceRepoConfig;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev';
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev';
    {$ENDIF}

    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  // Ensure install directory exists
  if not DirectoryExists(FInstallRoot) then
    EnsureDir(FInstallRoot);

  // Initialize fpdev-repo integration
  RepoConfig := CreateDefaultConfig;
  FResourceRepo := TResourceRepository.Create(RepoConfig);
  if DirectoryExists(RepoConfig.LocalPath) then
    FResourceRepo.LoadManifest;

  // Initialize build tester service
  FBuildTester := TCrossBuildTester.Create(FConfigManager, FInstallRoot);

  // Initialize modern toolchain downloader
  FDownloader := TCrossToolchainDownloader.Create(
    FInstallRoot,
    'https://raw.githubusercontent.com/fpdev/fpdev-repo/main/cross-manifest.json'
  );
  FDownloader.LoadManifest;

  // Initialize target query helper
  FQuery := TCrossTargetQuery.Create(FConfigManager, FResourceRepo, FInstallRoot);
end;

destructor TCrossCompilerManager.Destroy;
begin
  if Assigned(FQuery) then
    FQuery.Free;
  if Assigned(FDownloader) then
    FDownloader.Free;
  if Assigned(FBuildTester) then
    FBuildTester.Free;
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TCrossCompilerManager.GetAvailableTargets: TCrossTargetArray;
begin
  Result := FQuery.GetAvailableTargets;
end;

function TCrossCompilerManager.GetInstalledTargets: TCrossTargetArray;
begin
  Result := FQuery.GetInstalledTargets;
end;

function TCrossCompilerManager.DownloadBinutils(const ATarget: string; const {%H-} ATargetInfo: TCrossTargetInfo; Outp: IOutput): Boolean;
var
  LO: IOutput;
begin
  Result := False;
  if Pointer(@ATargetInfo) = nil then;
  if ATarget = '' then Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  // Use modern TCrossToolchainDownloader
  if not Assigned(FDownloader) then
  begin
    LO.WriteLn(_(MSG_ERROR) + ': Toolchain downloader not initialized');
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_CROSS_DOWNLOADING_BINUTILS, [ATarget]));

  // Delegate to modern downloader
  Result := FDownloader.DownloadBinutils(ATarget);

  if Result then
    LO.WriteLn(_(MSG_CROSS_BINUTILS_SUCCESS))
  else
  begin
    LO.WriteLn(_(MSG_ERROR) + ': ' + FDownloader.LastError);
    LO.WriteLn(_Fmt(MSG_CROSS_MANIFEST_NOT_FOUND, ['cross-manifest.json']));
  end;
end;

function TCrossCompilerManager.DownloadLibraries(const ATarget: string; const {%H-} ATargetInfo: TCrossTargetInfo; Outp: IOutput): Boolean;
var
  LO: IOutput;
begin
  Result := False;
  if Pointer(@ATargetInfo) = nil then;
  if ATarget = '' then Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  // Use modern TCrossToolchainDownloader
  if not Assigned(FDownloader) then
  begin
    LO.WriteLn(_(MSG_ERROR) + ': Toolchain downloader not initialized');
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_CROSS_DOWNLOADING_LIBS, [ATarget]));

  // Delegate to modern downloader
  Result := FDownloader.DownloadLibraries(ATarget);

  if Result then
    LO.WriteLn(_(MSG_CROSS_LIBS_SUCCESS))
  else
  begin
    // Libraries are optional - allow manual configuration
    LO.WriteLn(_(MSG_CROSS_LIBS_MANUAL_INSTALL));
    LO.WriteLn(_(MSG_CROSS_LIBS_NOTE));
    Result := True; // Allow manual configuration
  end;
end;

function TCrossCompilerManager.SetupCrossEnvironment(const ATarget: string; const {%H-} ATargetInfo: TCrossTargetInfo): Boolean;
var
  CrossTarget: TCrossTarget;
  InstallPath: string;
begin
  Result := False;
  if Pointer(@ATargetInfo) = nil then;
  // ATargetInfo parameter reserved for future use

  try
    InstallPath := FQuery.GetTargetInstallPath(ATarget);

    // 创建交叉编译目标配置
    System.Initialize(CrossTarget);
    try
      CrossTarget.Enabled := True;
      CrossTarget.BinutilsPath := InstallPath + PathDelim + 'bin';
      CrossTarget.LibrariesPath := InstallPath + PathDelim + 'lib';

      // 添加到配置
      Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, CrossTarget);
    finally
      System.Finalize(CrossTarget);
    end;
    if Result then

  except
    on E: Exception do
      Result := False;
  end;
end;

function TCrossCompilerManager.InstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  TargetInfo: TCrossTargetInfo;
  InstallPath: string;
  SystemBinutilsPath: string;
  CrossTarget: TCrossTarget;
  Instructions: string;
  LO: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  if not FQuery.ValidateTarget(ATarget) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  if FQuery.IsTargetInstalled(ATarget) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_ALREADY_INSTALLED, [ATarget]));
    Result := True;
    Exit;
  end;

  try
    TargetInfo := FQuery.GetTargetInfo(ATarget);
    InstallPath := FQuery.GetTargetInstallPath(ATarget);

    LO.WriteLn(_Fmt(MSG_CROSS_INSTALLING, [ATarget]));
    LO.WriteLn('');

    // Step 1: Check for system-installed cross compiler
    LO.WriteLn(_(MSG_CROSS_INSTALL_STEP1));
    if DetectSystemCrossCompiler(ATarget, SystemBinutilsPath) then
    begin
      LO.WriteLn(_Fmt(MSG_CROSS_SYSTEM_FOUND, [SystemBinutilsPath]));
      LO.WriteLn('');
      LO.WriteLn(_(MSG_CROSS_SKIP_DOWNLOAD));
      LO.WriteLn(_(MSG_CROSS_INSTALL_STEP3));

      // Configure to use system compiler
      System.Initialize(CrossTarget);
      try
        CrossTarget.Enabled := True;
        CrossTarget.BinutilsPath := SystemBinutilsPath;
        CrossTarget.LibrariesPath := '';  // System libs

        Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, CrossTarget);
      finally
        System.Finalize(CrossTarget);
      end;

      if Result then
      begin
        LO.WriteLn('');
        LO.WriteLn(_Fmt(MSG_CROSS_INSTALL_SUCCESS, [ATarget]));
        LO.WriteLn(_Fmt(MSG_CROSS_USING_SYSTEM, [SystemBinutilsPath]));
      end
      else
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_CONFIGURE_FAILED, [ATarget]));
      end;
      Exit;
    end;

    LO.WriteLn(_(MSG_CROSS_SYSTEM_NOT_FOUND));
    LO.WriteLn('');

    // Ensure install directory exists
    if not DirectoryExists(InstallPath) then
      EnsureDir(InstallPath);

    // Step 2: Try to download binutils
    LO.WriteLn(_(MSG_CROSS_INSTALL_STEP2));
    if not DownloadBinutils(ATarget, TargetInfo, LO) then
    begin
      // Download failed - show package manager instructions
      LO.WriteLn('');
      LO.WriteLn(_(MSG_CROSS_DOWNLOAD_UNAVAIL));
      LO.WriteLn('');
      Instructions := GetPackageManagerInstructions(ATarget);
      LO.WriteLn(Instructions);
      LO.WriteLn('');
      LO.WriteLn(_(MSG_CROSS_AFTER_INSTALL_HINT));
      LO.WriteLn(_Fmt(MSG_CROSS_INSTALL_HINT, [ATarget]));
      LO.WriteLn(_(MSG_CROSS_MANUAL_CONFIG_HINT));
      LO.WriteLn(_Fmt(MSG_CROSS_CONFIGURE_HINT, [ATarget]));

      // Return success since we provided instructions
      Result := False;
      Exit;
    end;

    // Download libraries (optional - don't fail if unavailable)
    if not DownloadLibraries(ATarget, TargetInfo, LO) then
    begin
      LO.WriteLn(_(MSG_CROSS_LIBS_SKIP_NOTE));
    end;

    // Step 3: Configure environment
    LO.WriteLn(_(MSG_CROSS_INSTALL_STEP3));
    Result := SetupCrossEnvironment(ATarget, TargetInfo);

    if Result then
    begin
      LO.WriteLn('');
      LO.WriteLn(_Fmt(MSG_CROSS_INSTALL_SUCCESS, [ATarget]));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_CROSS_SETUP_FAILED));
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['installation', E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.UninstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not FQuery.IsTargetInstalled(ATarget) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_TARGET_NOT_INSTALLED_MSG, [ATarget]));
    Result := True;
    Exit;
  end;

  try
    InstallPath := FQuery.GetTargetInstallPath(ATarget);

    // 删除安装目录
    if DirectoryExists(InstallPath) then
      DeleteDirRecursive(InstallPath);

    // 从配置中移除
    FConfigManager.GetCrossTargetManager.RemoveCrossTarget(ATarget);

    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_UNINSTALLED, [ATarget]));
    Result := True;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['uninstallation', E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.ListTargets(const AShowAll: Boolean; Outp: IOutput): Boolean;
var
  Targets: TCrossTargetArray;
  i: Integer;
  Line: string;
  LO: IOutput;
begin
  Result := True;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    if AShowAll then
      Targets := GetAvailableTargets
    else
      Targets := GetInstalledTargets;

    // Output header
    if AShowAll then
      LO.WriteLn(_(MSG_CROSS_LIST_AVAILABLE))
    else
      LO.WriteLn(_(MSG_CROSS_LIST_INSTALLED));

    LO.WriteLn('');

    if Length(Targets) = 0 then
    begin
      if AShowAll then
        LO.WriteLn(_(MSG_CROSS_LIST_NO_AVAILABLE))
      else
        LO.WriteLn(_(MSG_CROSS_LIST_NO_INSTALLED));
      LO.WriteLn('');
      LO.WriteLn(_(MSG_CROSS_LIST_USE_ALL));
      Exit;
    end;

    LO.WriteLn(_(MSG_CROSS_LIST_TABLE_HEADER));
    LO.WriteLn(_(MSG_CROSS_LIST_TABLE_LINE));

    for i := 0 to High(Targets) do
    begin
      Line := Format('%-10s  ', [Targets[i].Name]);

      if Targets[i].Installed then
        Line := Line + _(MSG_CROSS_STATUS_INSTALLED)
      else
        Line := Line + _(MSG_CROSS_STATUS_AVAILABLE);

      Line := Line + Format('%-20s  ', [Targets[i].DisplayName]);
      Line := Line + Format('%-8s  ', [Targets[i].CPU]);
      Line := Line + Targets[i].OS;

      LO.WriteLn(Line);
    end;

    LO.WriteLn('');
    LO.WriteLn(_Fmt(MSG_CROSS_LIST_TOTAL, [IntToStr(Length(Targets))]));

  except
    on E: Exception do
    begin
      LO.WriteLn(_Fmt(MSG_CROSS_LIST_ERROR, [E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.EnableTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := False;

  try
    if FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, CrossTarget) then
    begin
      CrossTarget.Enabled := True;
      Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, CrossTarget);
      if Result then
      begin
        if Outp <> nil then
          Outp.WriteLn(_Fmt(MSG_CROSS_ENABLED, [ATarget]));
      end
      else
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_ENABLE_FAILED, [ATarget]));
      end;
    end else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_CONFIGURED, [ATarget]));
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['enabling target', E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.DisableTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := False;

  try
    if FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, CrossTarget) then
    begin
      CrossTarget.Enabled := False;
      Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, CrossTarget);
      if Result then
      begin
        if Outp <> nil then
          Outp.WriteLn(_Fmt(MSG_CROSS_DISABLED, [ATarget]));
      end
      else
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_DISABLE_FAILED, [ATarget]));
      end;
    end else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_CONFIGURED, [ATarget]));
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['disabling target', E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.ShowTargetInfo(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  TargetInfo: TCrossTargetInfo;
  InstallPath: string;
  LO: IOutput;
  LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if not FQuery.ValidateTarget(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  try
    TargetInfo := FQuery.GetTargetInfo(ATarget);
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_DISPLAY_NAME, [TargetInfo.DisplayName]));
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_CPU, [TargetInfo.CPU]));
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_OS, [TargetInfo.OS]));
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_BINUTILS_PREFIX, [TargetInfo.BinutilsPrefix]));

    if TargetInfo.Installed then
    begin
      InstallPath := FQuery.GetTargetInstallPath(ATarget);
      if InstallPath <> '' then
        LO.WriteLn('Install Path: ' + InstallPath);
    end;

    Result := True;

  except
    on E: Exception do
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['displaying target info', E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.TestTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  CrossTarget: TCrossTarget;
  LResult: TProcessResult;
  GCCExe: string;
begin
  Result := False;

  if not FQuery.IsTargetInstalled(ATarget) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_INSTALLED, [ATarget]));
    Exit;
  end;

  try
    if not FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, CrossTarget) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_CROSS_CONFIG_GET_FAILED));
      Exit;
    end;

    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_TEST_TESTING, [ATarget]));

    // 查找交叉编译器
    GCCExe := CrossTarget.BinutilsPath + PathDelim + FQuery.GetTargetInfo(ATarget).BinutilsPrefix + 'gcc';
    {$IFDEF MSWINDOWS}
    GCCExe := GCCExe + '.exe';
    {$ENDIF}

    if not FileExists(GCCExe) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_COMPILER_NOT_FOUND, [GCCExe]));
      Exit;
    end;

    LResult := TProcessExecutor.Execute(GCCExe, ['--version'], '');
    Result := LResult.Success;
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(MSG_CROSS_TEST_PASSED, [ATarget]));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_Fmt(MSG_CROSS_TEST_FAILED_MSG, [ATarget]))
      else if Outp <> nil then
        Outp.WriteLn(_Fmt(MSG_CROSS_TEST_FAILED_MSG, [ATarget]));
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['testing target', E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.BuildTest(const ATarget: string; const ASourceFile: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  CrossTarget: TCrossTarget;
  TargetInfo: TCrossTargetInfo;
  TestResult: TCrossBuildTestResult;
  LO, LE: IOutput;
begin
  Result := False;

  if ATarget = '' then Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Check if target is installed
  if not FQuery.IsTargetInstalled(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_INSTALLED, [ATarget]));
    Exit;
  end;

  // Get target configuration
  if not FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, CrossTarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_CROSS_CONFIG_GET_FAILED));
    Exit;
  end;

  TargetInfo := FQuery.GetTargetInfo(ATarget);

  LO.WriteLn(_Fmt(MSG_CROSS_BUILDING_TEST, [ATarget]));
  LO.WriteLn(_Fmt(MSG_CROSS_BUILD_TARGET_CPU, [TargetInfo.CPU]));
  LO.WriteLn(_Fmt(MSG_CROSS_BUILD_TARGET_OS, [TargetInfo.OS]));

  // Delegate to build tester service
  TestResult := FBuildTester.ExecuteTest(ATarget, TargetInfo.CPU, TargetInfo.OS,
    CrossTarget.BinutilsPath, CrossTarget.LibrariesPath, ASourceFile);

  if TestResult.Success then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_BUILD_PASSED, [ATarget]));
    LO.WriteLn(_Fmt(MSG_CROSS_OUTPUT_FILE, [TestResult.OutputFile]));
    Result := True;
  end
  else
  begin
    LE.WriteLn(_Fmt(MSG_CROSS_BUILD_FAILED, [TestResult.ErrorMessage]));
    Result := False;
  end;
end;

function TCrossCompilerManager.ConfigureTarget(const ATarget: string; const ABinutilsPath, ALibrariesPath: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := False;

  if not FQuery.ValidateTarget(ATarget) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  try
    // Validate paths
    if not DirectoryExists(ABinutilsPath) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_BINUTILS_PATH_NOT_FOUND, [ABinutilsPath]));
      Exit;
    end;

    if not DirectoryExists(ALibrariesPath) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_LIBS_PATH_NOT_FOUND, [ALibrariesPath]));
      Exit;
    end;

    // Create configuration
    System.Initialize(CrossTarget);
    try
      CrossTarget.Enabled := True;
      CrossTarget.BinutilsPath := ABinutilsPath;
      CrossTarget.LibrariesPath := ALibrariesPath;

      Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, CrossTarget);
    finally
      System.Finalize(CrossTarget);
    end;
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(string('Cross-compilation target ') + ATarget + string(' configured successfully'));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_CONFIGURE_FAILED, [ATarget]));
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['configuring target', E.Message]));
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.UpdateTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  TargetInfo: TCrossTargetInfo;
  LO, LE: IOutput;
begin
  Result := False;

  if ATarget = '' then Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Validate target
  if not FQuery.ValidateTarget(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  // Check if target is installed
  if not FQuery.IsTargetInstalled(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_INSTALLED, [ATarget]));
    LO.WriteLn(_Fmt(MSG_CROSS_USE_INSTALL_FIRST, [ATarget]));
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_CROSS_UPDATING, [ATarget]));

  TargetInfo := FQuery.GetTargetInfo(ATarget);

  // Re-download binutils
  LO.WriteLn(_(MSG_CROSS_UPDATE_STEP1));
  if not DownloadBinutils(ATarget, TargetInfo, LO) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_UPDATE_BINUTILS_WARN, [ATarget]));
    // Continue anyway - might be manual installation
  end;

  // Re-download libraries
  LO.WriteLn(_(MSG_CROSS_UPDATE_STEP2));
  if not DownloadLibraries(ATarget, TargetInfo, LO) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_UPDATE_LIBS_WARN, [ATarget]));
    // Continue anyway - might be manual installation
  end;

  LO.WriteLn(_Fmt(MSG_CROSS_UPDATE_DONE, [ATarget]));
  Result := True;
end;

function TCrossCompilerManager.CleanTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath: string;
  BinutilsPath, LibPath: string;
  CrossTarget: TCrossTarget;
  LO, LE: IOutput;
begin
  Result := False;

  if ATarget = '' then Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Validate target
  if not FQuery.ValidateTarget(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  // Check if target is installed
  if not FQuery.IsTargetInstalled(ATarget) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_NOT_INSTALLED_NOTHING, [ATarget]));
    Result := True;
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_CROSS_CLEANING, [ATarget]));

  // Get paths
  InstallPath := FQuery.GetTargetInstallPath(ATarget);
  BinutilsPath := InstallPath + PathDelim + 'bin';
  LibPath := InstallPath + PathDelim + 'lib';

  // Get current configuration
  if FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, CrossTarget) then
  begin
    // Use configured paths if different
    if (CrossTarget.BinutilsPath <> '') and (CrossTarget.BinutilsPath <> BinutilsPath) then
      BinutilsPath := CrossTarget.BinutilsPath;
    if (CrossTarget.LibrariesPath <> '') and (CrossTarget.LibrariesPath <> LibPath) then
      LibPath := CrossTarget.LibrariesPath;
  end;

  // Clean binutils directory
  if DirectoryExists(BinutilsPath) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_CLEANING_BINUTILS, [BinutilsPath]));
    DeleteDirRecursive(BinutilsPath);
  end;

  // Clean libraries directory
  if DirectoryExists(LibPath) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_CLEANING_LIBS, [LibPath]));
    DeleteDirRecursive(LibPath);
  end;

  // Clean downloaded archives
  if FileExists(InstallPath + PathDelim + 'binutils.tar.xz') then
    DeleteFile(InstallPath + PathDelim + 'binutils.tar.xz');
  if FileExists(InstallPath + PathDelim + 'binutils.zip') then
    DeleteFile(InstallPath + PathDelim + 'binutils.zip');
  if FileExists(InstallPath + PathDelim + 'libraries.tar.xz') then
    DeleteFile(InstallPath + PathDelim + 'libraries.tar.xz');
  if FileExists(InstallPath + PathDelim + 'libraries.zip') then
    DeleteFile(InstallPath + PathDelim + 'libraries.zip');

  // Clean test artifacts
  if FileExists(InstallPath + PathDelim + 'cross_test.pas') then
    DeleteFile(InstallPath + PathDelim + 'cross_test.pas');
  if FileExists(InstallPath + PathDelim + 'cross_test') then
    DeleteFile(InstallPath + PathDelim + 'cross_test');
  if FileExists(InstallPath + PathDelim + 'cross_test.exe') then
    DeleteFile(InstallPath + PathDelim + 'cross_test.exe');

  LO.WriteLn(_Fmt(MSG_CROSS_CLEAN_DONE, [ATarget]));
  LO.WriteLn(_Fmt(MSG_CROSS_CLEAN_NOTE, [ATarget]));
  Result := True;
end;

end.
