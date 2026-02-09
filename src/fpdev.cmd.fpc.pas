unit fpdev.cmd.fpc;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.fpc

FPC 版本管理命令


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
  SysUtils, Classes, Process, StrUtils, fpjson, jsonparser,
  fpdev.output.intf, fpdev.config, fpdev.config.interfaces, fpdev.fpc.source,
  fpdev.types, fpdev.fpc.types, fpdev.fpc.metadata, fpdev.resource.repo, fpdev.utils.fs, fpdev.utils.process,
  fpdev.utils.git, fpdev.i18n, fpdev.i18n.strings,
  fpdev.fpc.activation, fpdev.fpc.validator, fpdev.fpc.version, fpdev.fpc.installer,
  fpdev.fpc.builder, fpdev.fpc.verify, fpdev.constants, fpdev.build.cache, fpdev.paths;

type
  { TFPCManager }
  TFPCManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;  // 资源仓库管理器
    FActivationMgr: TFPCActivationManager;  // Activation service (Facade delegation)
    FValidatorMgr: TFPCValidator;  // Validation service (Facade delegation)
    FVersionMgr: TFPCVersionManager;  // Version service (Facade delegation)
    FInstallerMgr: TFPCBinaryInstaller;  // Binary installation service (Facade delegation)
    FBuilderMgr: TFPCSourceBuilder;  // Source build service (Facade delegation)
    FBuildCache: TBuildCache;  // Build artifact cache for fast version switching

    FOut: IOutput;
    FErr: IOutput;

    function GetAvailableVersions: TFPCVersionArray;
    function GetInstalledVersions: TFPCVersionArray;
    function DownloadSource(const AVersion, ATargetDir: string): Boolean;
    function BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
    function ValidateVersion(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;

    // Bootstrap compiler management (delegated to FBuilderMgr)
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function GetCurrentFPCVersion: string;
    function GetBootstrapCompilerPath(const AVersion: string): string;
    function IsBootstrapAvailable(const AVersion: string): Boolean;
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager; const AOut: IOutput = nil; const AErr: IOutput = nil);
    destructor Destroy; override;

    // 版本管理
    function InstallVersion(const AVersion: string; const AFromSource: Boolean = False; const APrefix: string = ''; const AEnsure: Boolean = False): Boolean;
    function UninstallVersion(const AVersion: string): Boolean;
    function ListVersions(const AShowAll: Boolean = False): Boolean; overload;
    function ListVersions(const Outp: IOutput; const AShowAll: Boolean = False): Boolean; overload;
    function SetDefaultVersion(const AVersion: string): Boolean; overload;
    function SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function GetCurrentVersion: string;
    function ActivateVersion(const AVersion: string): TActivationResult;

    // 二进制安装
    function GetBinaryDownloadURL(const AVersion: string): string;
    function DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
    function GetBinaryDownloadURLLegacy(const AVersion: string): string;
    function DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
    function VerifyChecksum(const AFilePath, AVersion: string): Boolean;
    function ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
    function InstallFromBinary(const AVersion: string; const APrefix: string = ''): Boolean;

    // 源码管理
    function UpdateSources(const AVersion: string = ''): Boolean;
    function CleanSources(const AVersion: string = ''): Boolean;

    // 工具链操作
    function ShowVersionInfo(const AVersion: string): Boolean; overload;
    function ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean; overload;
    function TestInstallation(const AVersion: string): Boolean; overload;
    function TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;

    // Metadata operations (public for testing)
    function WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
    function ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;

    // Environment setup (public for cache restore)
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
  end;

// 导出索引更新过程，供子命令调用
procedure FPC_UpdateIndex;

implementation

uses
  fpdev.output.console, fpdev.version.registry;

procedure SafeWriteAllText(const APath, AText: string);
var
  Dir: string;
  L: TStringList;
begin
  Dir := ExtractFileDir(APath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    EnsureDir(Dir);
  L := TStringList.Create;
  try
    L.Text := AText;
    L.SaveToFile(APath);
  finally
    L.Free;
  end;
end;

function ReadAllTextIfExists(const APath: string): string;
var
  L: TStringList;
begin
  Result := '';
  if not FileExists(APath) then Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(APath);
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

var
  FPDEV_LOGFILE: string = '';

procedure LogLine(const S: string);
begin
  if FPDEV_LOGFILE <> '' then
  begin
    try
      with TStringList.Create do
      try
        if FileExists(FPDEV_LOGFILE) then
          LoadFromFile(FPDEV_LOGFILE);
        Add(S);
        SaveToFile(FPDEV_LOGFILE);
      finally
        Free;
      end;
    except
      // 忽略日志写入异常
    end;
  end;
end;


function TryParseInt(const S: string; out N: Integer): Boolean;
var
  Code: Integer;
begin
  Val(S, N, Code);
  Result := Code = 0;
end;

procedure ParseVersion(const Ver: string; out A, B, C: Integer);
var
  i, p1, p2: Integer;
  s: string;
begin
  A := 0; B := 0; C := 0;
  s := Ver;
  p1 := Pos('.', s);
  if p1 > 0 then
  begin
    if not TryParseInt(Copy(s, 1, p1-1), A) then A := 0;
    Delete(s, 1, p1);
    p2 := Pos('.', s);
    if p2 > 0 then
    begin
      if not TryParseInt(Copy(s, 1, p2-1), B) then B := 0;
      Delete(s, 1, p2);
      // 剩余为 patch（可能含后缀，取数字前缀）
      i := 1;
      while (i <= Length(s)) and (s[i] in ['0'..'9']) do Inc(i);
      if i > 1 then
        if not TryParseInt(Copy(s, 1, i-1), C) then C := 0;
    end
    else
    begin
      if not TryParseInt(s, B) then B := 0;
    end;
  end
  else
  begin
    TryParseInt(s, A);
  end;
end;

function CompareSemVer(const V1, V2: string): Integer;
var
  a1,b1,c1,a2,b2,c2: Integer;
begin
  ParseVersion(V1, a1,b1,c1);
  ParseVersion(V2, a2,b2,c2);
  if a1 <> a2 then Exit(Ord(a1 > a2) - Ord(a1 < a2));
  if b1 <> b2 then Exit(Ord(b1 > b2) - Ord(b1 < b2));
  if c1 <> c2 then Exit(Ord(c1 > c2) - Ord(c1 < c2));
  Result := 0;
end;

function SameMajorMinor(const V1, V2: string): Boolean;
var
  a1,b1,c1,a2,b2,c2: Integer;
begin
  ParseVersion(V1, a1,b1,c1);
  ParseVersion(V2, a2,b2,c2);
  Result := (a1=a2) and (b1=b2);
end;

// --- FPC command helpers (no inline vars) ----------------------------------

procedure FPC_UpdateIndex;
var
  Cfg: TFPDevConfigManager;
  S: TStringList;
  CacheDir, IndexPath, NowIso, Channel: string;
  i: Integer;
  Releases: TFPCReleaseArray;
begin
  LogLine('[update] begin');
  Cfg := TFPDevConfigManager.Create('');
  try
    Cfg.LoadConfig;
    CacheDir := Cfg.GetSettings.InstallRoot + PathDelim + 'cache' + PathDelim + 'fpc';
    EnsureDir(CacheDir);
    IndexPath := CacheDir + PathDelim + 'index.json';
    NowIso := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', Now);
    Releases := TVersionRegistry.Instance.GetFPCReleases;
    S := TStringList.Create;
    try
      S.Add('{');
      S.Add('  "version": "1",');
      S.Add('  "updated_at": "' + NowIso + '",');
      S.Add('  "items": [');
      for i := 0 to High(Releases) do
      begin
        Channel := Releases[i].Channel;
        S.Add('    {');
        S.Add('      "version": "' + Releases[i].Version + '",');
        S.Add('      "tag": "' + Releases[i].GitTag + '",');
        S.Add('      "branch": "' + Releases[i].Branch + '",');
        S.Add('      "channel": "' + Channel + '"');
        if i < High(Releases) then S.Add('    },') else S.Add('    }');
      end;
      S.Add('  ]');
      S.Add('}');
      S.SaveToFile(IndexPath);
      LogLine('[update] index: ' + IndexPath);
    finally
      S.Free;
    end;
  finally
    Cfg.Free;
  end;
  LogLine('[update] done');
end;


{ TFPCManager }

constructor TFPCManager.Create(AConfigManager: IConfigManager; const AOut: IOutput; const AErr: IOutput);
var
  Settings: TFPDevSettings;
  CacheDir: string;
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := nil;  // 延迟初始化
  FActivationMgr := TFPCActivationManager.Create(AConfigManager);  // Activation service
  FValidatorMgr := TFPCValidator.Create(AConfigManager);  // Validation service
  FVersionMgr := TFPCVersionManager.Create(AConfigManager);  // Version service
  FInstallerMgr := TFPCBinaryInstaller.Create(AConfigManager, AOut, AErr);  // Installer service
  FBuilderMgr := TFPCSourceBuilder.Create(AConfigManager, AOut, AErr);  // Builder service

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    // 默认优先使用程序旁 data 目录，不可写时再由 ConfigManager 回退
    FInstallRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  // 确保安装目录存在
  if not DirectoryExists(FInstallRoot) then
    EnsureDir(FInstallRoot);

  // Initialize build cache
  CacheDir := FInstallRoot + PathDelim + 'cache' + PathDelim + 'builds';
  FBuildCache := TBuildCache.Create(CacheDir);

  // Pass cache instance to installer for binary caching
  FInstallerMgr.SetCache(FBuildCache);
end;

destructor TFPCManager.Destroy;
begin
  if Assigned(FBuildCache) then
    FBuildCache.Free;
  if Assigned(FBuilderMgr) then
    FBuilderMgr.Free;
  if Assigned(FInstallerMgr) then
    FInstallerMgr.Free;
  if Assigned(FVersionMgr) then
    FVersionMgr.Free;
  if Assigned(FValidatorMgr) then
    FValidatorMgr.Free;
  if Assigned(FActivationMgr) then
    FActivationMgr.Free;
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TFPCManager.WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
begin
  Result := WriteFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': WriteMetadata failed');
end;

function TFPCManager.ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
begin
  Result := ReadFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': ReadMetadata failed');
end;

function TFPCManager.GetVersionInstallPath(const AVersion: string): string;
var
  Scope: TInstallScope;
  ProjectRoot: string;
begin
  // Detect current scope (delegate to activation manager)
  Scope := FActivationMgr.DetectInstallScope(GetCurrentDir);

  if Scope = isProject then
  begin
    // Find project root by searching for .fpdev
    ProjectRoot := GetCurrentDir;
    while ProjectRoot <> '' do
    begin
      if DirectoryExists(ProjectRoot + PathDelim + FPDEV_CONFIG_DIR) then
      begin
        Result := ProjectRoot + PathDelim + FPDEV_CONFIG_DIR + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + AVersion;
        Exit;
      end;
      ProjectRoot := ExtractFileDir(ProjectRoot);
      if ProjectRoot = ExtractFileDir(ProjectRoot) then
        Break;
    end;
  end;

  // Default to user scope - use unified path from fpdev.paths
  Result := GetToolchainsDir + PathDelim + 'fpc' + PathDelim + AVersion;
end;

function TFPCManager.IsVersionInstalled(const AVersion: string): Boolean;
var
  InstallPath: string;
  FPCExe: string;
begin
  InstallPath := GetVersionInstallPath(AVersion);
  {$IFDEF MSWINDOWS}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  Result := FileExists(FPCExe);
end;

function TFPCManager.ValidateVersion(const AVersion: string): Boolean;
begin
  // Delegate to version manager service
  Result := FVersionMgr.ValidateVersion(AVersion);
end;

function TFPCManager.GetAvailableVersions: TFPCVersionArray;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetAvailableVersions;
end;

function TFPCManager.GetInstalledVersions: TFPCVersionArray;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetInstalledVersions;
end;

function TFPCManager.DownloadSource(const AVersion, ATargetDir: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.DownloadSource(AVersion, ATargetDir);
end;

{ Bootstrap Compiler Management }

function TFPCManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetRequiredBootstrapVersion(ATargetVersion);
end;

function TFPCManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.EnsureBootstrapCompiler(ATargetVersion);
end;

function TFPCManager.GetCurrentFPCVersion: string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetCurrentFPCVersion;
end;

function TFPCManager.GetBootstrapCompilerPath(const AVersion: string): string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetBootstrapCompilerPath(AVersion);
end;

function TFPCManager.IsBootstrapAvailable(const AVersion: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.IsBootstrapAvailable(AVersion);
end;

function TFPCManager.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.BuildFromSource(ASourceDir, AInstallDir);
end;

function TFPCManager.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
begin
  Result := False;

  if (AVersion = '') then
  begin
    Exit;
  end;

  if AInstallPath <> '' then
    InstallPath := AInstallPath
  else
    InstallPath := GetVersionInstallPath(AVersion);

  if not DirectoryExists(InstallPath) then
  begin
    Exit;
  end;

  try
    // 创建工具链信息
    Initialize(ToolchainInfo);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := AVersion;
    ToolchainInfo.InstallPath := InstallPath;
    ToolchainInfo.SourceURL := FPC_OFFICIAL_REPO;
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;

    // 添加到配置
    Result := FConfigManager.GetToolchainManager.AddToolchain('fpc-' + AVersion, ToolchainInfo);
    if not Result then
      FErr.WriteLn(_(MSG_ERROR) + ': Failed to add toolchain to configuration');

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': SetupEnvironment failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.InstallVersion(const AVersion: string; const AFromSource: Boolean; const APrefix: string; const AEnsure: Boolean): Boolean;
var
  InstallPath, SourceDir, FPCExe: string;
  CacheRestored: Boolean;
  Verifier: TFPCVerifier;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
    FErr.WriteLn(_Fmt(ERR_INVALID_VERSION, [AVersion]));
    Exit;
  end;

  // If already installed and not forcing reinstall, verify it works
  if IsVersionInstalled(AVersion) and (APrefix = '') and (not AEnsure) then
  begin
    FOut.WriteLn(_Fmt(ERR_ALREADY_INSTALLED, ['FPC ' + AVersion]));
    FOut.WriteLn('Verifying installation...');

    // Verify the installation actually works
    InstallPath := GetVersionInstallPath(AVersion);
    {$IFDEF MSWINDOWS}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}

    Verifier := TFPCVerifier.Create;
    try
      if Verifier.VerifyVersion(FPCExe, AVersion) then
      begin
        FOut.WriteLn('Installation verified successfully');
        Result := True;
        Exit;
      end
      else
      begin
        FOut.WriteLn('Warning: Installation verification failed');
        FOut.WriteLn('Reason: ' + Verifier.GetLastError);
        FOut.WriteLn('Proceeding with reinstallation...');
        // Continue with installation below
      end;
    finally
      Verifier.Free;
    end;
  end;

  try
    if APrefix <> '' then
      InstallPath := ExpandFileName(APrefix)
    else
      InstallPath := GetVersionInstallPath(AVersion);

    FOut.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [AVersion]) + ' to: ' + InstallPath);

    if AFromSource then
    begin
      CacheRestored := False;

      // Try to restore from build cache first (fast path)
      if Assigned(FBuildCache) and FBuildCache.HasArtifacts(AVersion) then
      begin
        FOut.WriteLn('Restoring from build cache...');
        if FBuildCache.RestoreArtifacts(AVersion, InstallPath) then
        begin
          FOut.WriteLn('Build cache restored successfully');
          CacheRestored := True;
          FOut.WriteLn(_(MSG_FPC_STEP_SETUP));
          Result := SetupEnvironment(AVersion, InstallPath);
        end
        else
          FOut.WriteLn('Cache restore failed, building from source...');
      end;

      // If cache restore failed or no cache, build from source
      if not CacheRestored then
      begin
        // Install from source
        SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;

        FOut.WriteLn(_(MSG_FPC_STEP_DOWNLOAD));
        if not DownloadSource(AVersion, SourceDir) then
        begin
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_DOWNLOAD_FAILED));
          Exit;
        end;

        FOut.WriteLn(_(MSG_FPC_STEP_BOOTSTRAP));
        if not EnsureBootstrapCompiler(AVersion) then
        begin
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_BOOTSTRAP_CHECK_FAILED));
          Exit;
        end;

        FOut.WriteLn(_(MSG_FPC_STEP_BUILD));
        if not BuildFromSource(SourceDir, InstallPath) then
        begin
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_BUILD_FROM_SOURCE_FAILED));
          Exit;
        end;

        FOut.WriteLn(_(MSG_FPC_STEP_SETUP));
        Result := SetupEnvironment(AVersion, InstallPath);

        // Save to build cache after successful build
        if Result and Assigned(FBuildCache) then
        begin
          FOut.WriteLn('Saving build artifacts to cache...');
          if FBuildCache.SaveArtifacts(AVersion, InstallPath) then
            FOut.WriteLn('Build artifacts cached successfully')
          else
            FOut.WriteLn('Warning: Failed to cache build artifacts');
        end;
      end;

    end else
    begin
      // Binary installation
      FOut.WriteLn(_(MSG_FPC_STEP_DOWNLOAD_BIN));
      Result := InstallFromBinary(AVersion, APrefix);
    end;

    if Result then
      FOut.WriteLn(_Fmt(CMD_FPC_INSTALL_DONE, [AVersion]));

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallVersion failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.UninstallVersion(const AVersion: string): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);

    // 删除安装目录
    if DirectoryExists(InstallPath) then
      DeleteDirRecursive(InstallPath);

    // 从配置中移除
    FConfigManager.GetToolchainManager.RemoveToolchain('fpc-' + AVersion);

    Result := True;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': UninstallVersion failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.ListVersions(const AShowAll: Boolean): Boolean;
begin
  Result := ListVersions(nil, AShowAll);
end;

function TFPCManager.ListVersions(const Outp: IOutput; const AShowAll: Boolean): Boolean;
var
  Versions: TFPCVersionArray;
  i: Integer;
  DefaultVersion: string;
  Line: string;
begin
  Result := True;

  try
    if AShowAll then
      Versions := GetAvailableVersions
    else
      Versions := GetInstalledVersions;

    DefaultVersion := FConfigManager.GetToolchainManager.GetDefaultToolchain;
    if DefaultVersion <> '' then
      DefaultVersion := StringReplace(DefaultVersion, 'fpc-', '', [rfReplaceAll]);

    if AShowAll then
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_LIST_ALL_HEADER))
      else
        FOut.WriteLn(_(CMD_FPC_LIST_ALL_HEADER));
    end
    else
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_LIST_HEADER))
      else
        FOut.WriteLn(_(CMD_FPC_LIST_HEADER));
    end;


    for i := 0 to High(Versions) do
    begin
      Line := Format('%-8s  ', [Versions[i].Version]);

      if Versions[i].Installed then
      begin
        if SameText(Versions[i].Version, DefaultVersion) then
          Line := Line + 'Installed*  '
        else
          Line := Line + 'Installed   ';
      end
      else
        Line := Line + 'Available   ';

      Line := Line + Format('%-10s  ', [Versions[i].ReleaseDate]);
      Line := Line + Versions[i].Branch;

      if Outp <> nil then
        Outp.WriteLn(Line)
      else
        FOut.WriteLn(Line);
    end;

    if DefaultVersion <> '' then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_FPC_CURRENT_VERSION, [DefaultVersion]))
      else
        FOut.WriteLn(_Fmt(CMD_FPC_CURRENT_VERSION, [DefaultVersion]));
    end
    else
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_CURRENT_NONE))
      else
        FOut.WriteLn(_(CMD_FPC_CURRENT_NONE));
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := SetDefaultVersion(nil, nil, AVersion);
end;

function TFPCManager.SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_Fmt(CMD_FPC_USE_NOT_FOUND, [AVersion]));
    Exit;
  end;

  try
    Result := FConfigManager.GetToolchainManager.SetDefaultToolchain('fpc-' + AVersion);
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_FPC_USE_ACTIVATED, [AVersion]));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_FAILED) + ': set default version');
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.GetCurrentVersion: string;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetCurrentVersion;
end;

function TFPCManager.ActivateVersion(const AVersion: string): TActivationResult;
var
  InstallPath, BinPath: string;
begin
  // Initialize result
  Initialize(Result);
  Result.Success := False;

  // Check if version is installed
  if not IsVersionInstalled(AVersion) then
  begin
    Result.ErrorMessage := 'FPC version ' + AVersion + ' is not installed';
    Exit;
  end;

  // Get install path and bin path
  InstallPath := GetVersionInstallPath(AVersion);
  BinPath := InstallPath + PathDelim + 'bin';

  // Delegate to activation manager service
  Result := FActivationMgr.ActivateVersion(AVersion, BinPath);
  if not Result.Success then
    Exit;

  // Set as default version
  if not SetDefaultVersion(AVersion) then
  begin
    Result.ErrorMessage := 'Failed to set default version';
    Result.Success := False;
    Exit;
  end;
end;

function TFPCManager.UpdateSources(const AVersion: string): Boolean;
var
  SourceDir: string;
  Git: TGitOperations;
begin
  Result := False;

  // Determine source directory
  if AVersion = '' then
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-main'
  else
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;

  // Validate source directory exists
  if not DirectoryExists(SourceDir) then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [SourceDir]));
    Exit;
  end;

  Git := TGitOperations.Create;
  try
    // Check Git backend availability
    if Git.Backend = gbNone then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_NO_GIT_BACKEND));
      Exit;
    end;

    // Check if it's a git repository
    if not Git.IsRepository(SourceDir) then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_NOT_GIT_REPO, [SourceDir]));
      Exit;
    end;

    // If no remote configured, repository is already up-to-date (local only)
    if not Git.HasRemote(SourceDir) then
    begin
      FOut.WriteLn(_(MSG_FPC_SOURCE_LOCAL_ONLY) + ' ' + SourceDir);
      Result := True;
      Exit;
    end;

    // Execute git pull to update sources
    if Git.Pull(SourceDir) then
    begin
      FOut.WriteLn(_(CMD_FPC_UPDATE_DONE) + ': ' + SourceDir);
      Result := True;
    end
    else
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_PULL_FAILED, [Git.LastError]));

  finally
    Git.Free;
  end;
end;

function TFPCManager.CleanSources(const AVersion: string): Boolean;
var
  SourceDir: string;
  DeletedCount: Integer;
begin
  Result := False;

  // 确定源码目录
  if AVersion = '' then
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-main'
  else
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;

  // 验证源码目录存在
  if not DirectoryExists(SourceDir) then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [SourceDir]));
    Exit;
  end;

  try
    // 使用共享清理函数（包含平台可执行文件）
    DeletedCount := CleanBuildArtifacts(SourceDir, nil, True);
    FOut.WriteLn(_(CMD_FPC_CLEAN_DONE) + ' - ' + IntToStr(DeletedCount) + ' file(s): ' + SourceDir);
    Result := True;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': CleanSources failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.ShowVersionInfo(const AVersion: string): Boolean;
begin
  Result := ShowVersionInfo(nil, AVersion);
end;

function TFPCManager.ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
begin
  Result := False;
  Initialize(ToolchainInfo);

  if not ValidateVersion(AVersion) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_UNSUPPORTED_VERSION, [AVersion]))
    else
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_UNSUPPORTED_VERSION, [AVersion]));
    Exit;
  end;

  try

    if IsVersionInstalled(AVersion) then
    begin
      InstallPath := GetVersionInstallPath(AVersion);
      if InstallPath = '' then
      begin
        if Outp <> nil then
          Outp.WriteLn(_(MSG_ERROR) + ': Install path not found')
        else
          FErr.WriteLn(_(MSG_ERROR) + ': Install path not found');
        Exit;
      end;

      if FConfigManager.GetToolchainManager.GetToolchain('fpc-' + AVersion, ToolchainInfo) then
      begin
        if Outp <> nil then
        begin
          Outp.WriteLn(_Fmt(MSG_FPC_INSTALL_DATE, [FormatDateTime('yyyy-mm-dd hh:nn:ss', ToolchainInfo.InstallDate)]));
          Outp.WriteLn(_Fmt(MSG_FPC_SOURCE_URL, [ToolchainInfo.SourceURL]));
        end
        else
        begin
          FOut.WriteLn(_Fmt(MSG_FPC_INSTALL_DATE, [FormatDateTime('yyyy-mm-dd hh:nn:ss', ToolchainInfo.InstallDate)]));
          FOut.WriteLn(_Fmt(MSG_FPC_SOURCE_URL, [ToolchainInfo.SourceURL]));
        end;
      end;
    end else
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(ERR_NOT_INSTALLED, ['FPC ' + AVersion]))
      else
        FErr.WriteLn(_Fmt(ERR_NOT_INSTALLED, ['FPC ' + AVersion]));
    end;

    Result := True;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ShowVersionInfo failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.TestInstallation(const AVersion: string): Boolean;
begin
  Result := TestInstallation(nil, nil, AVersion);
end;

function TFPCManager.TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean;
var
  LResult: TProcessResult;
  FPCExe: string;
  InstallPath: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_Fmt(CMD_FPC_USE_NOT_FOUND, [AVersion]));
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    {$IFDEF MSWINDOWS}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}

    if Outp <> nil then
      Outp.WriteLn(_Fmt(CMD_FPC_DOCTOR_CHECKING, [AVersion]));

    LResult := TProcessExecutor.Execute(FPCExe, ['-i'], '');
    Result := LResult.Success;
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_DOCTOR_OK));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_Fmt(CMD_FPC_DOCTOR_ISSUES, [1]))
      else if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_FPC_DOCTOR_ISSUES, [1]));
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
begin
  // Delegate to validator service
  Result := FValidatorMgr.VerifyInstallation(AVersion, VerifResult);
end;

// ============================================================================
// Binary Installation Methods - Delegated to FInstallerMgr
// ============================================================================

function TFPCManager.GetBinaryDownloadURL(const AVersion: string): string;
begin
  Result := FInstallerMgr.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCManager.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstallerMgr.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCManager.GetBinaryDownloadURLLegacy(const AVersion: string): string;
begin
  Result := FInstallerMgr.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCManager.DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstallerMgr.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCManager.VerifyChecksum(const AFilePath, AVersion: string): Boolean;
begin
  Result := FInstallerMgr.VerifyChecksum(AFilePath, AVersion);
end;

function TFPCManager.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
begin
  Result := FInstallerMgr.ExtractArchive(AArchivePath, ADestPath);
end;

function TFPCManager.InstallFromBinary(const AVersion: string; const APrefix: string): Boolean;
begin
  Result := FInstallerMgr.InstallFromBinary(AVersion, APrefix);
end;

end.

