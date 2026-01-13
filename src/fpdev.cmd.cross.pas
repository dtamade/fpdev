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
  fpdev.cross.manifest, fpdev.toolchain.fetcher, fpdev.toolchain.extract,
  fpdev.resource.repo, fpdev.utils.fs, fpdev.utils.process,
  fpdev.i18n, fpdev.i18n.strings, fpdev.cross.tester;

type
  { TCrossTargetPlatform }
  TCrossTargetPlatform = (
    ctpWin32, ctpWin64, ctpLinux32, ctpLinux64, ctpLinuxARM, ctpLinuxARM64,
    ctpDarwin32, ctpDarwin64, ctpDarwinARM64, ctpAndroid, ctpiOS,
    ctpFreeBSD32, ctpFreeBSD64, ctpCustom
  );

  { TCrossTargetInfo }
  TCrossTargetInfo = record
    Platform: TCrossTargetPlatform;
    Name: string;
    DisplayName: string;
    CPU: string;
    OS: string;
    BinutilsPrefix: string;
    LibrariesURL: string;
    BinutilsURL: string;
    Available: Boolean;
    Installed: Boolean;
  end;

  TCrossTargetArray = array of TCrossTargetInfo;

  { TCrossCompilerManager }
  TCrossCompilerManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;  // fpdev-repo integration
    FBuildTester: TCrossBuildTester;     // Cross-build testing service

    function GetAvailableTargets: TCrossTargetArray;
    function GetInstalledTargets: TCrossTargetArray;
    function DownloadBinutils(const ATarget: string; const ATargetInfo: TCrossTargetInfo; Outp: IOutput = nil): Boolean;
    function DownloadLibraries(const ATarget: string; const ATargetInfo: TCrossTargetInfo; Outp: IOutput = nil): Boolean;
    function SetupCrossEnvironment(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
    function ValidateTarget(const ATarget: string): Boolean;
    function GetTargetInstallPath(const ATarget: string): string;
    function IsTargetInstalled(const ATarget: string): Boolean;
    function GetTargetInfo(const ATarget: string): TCrossTargetInfo;
    function PlatformToString(APlatform: TCrossTargetPlatform): string;
    function StringToPlatform(const AStr: string): TCrossTargetPlatform;

    // System cross compiler detection
    function DetectSystemCrossCompiler(const ATarget: string; out ABinutilsPath: string): Boolean;
    function GetPackageManagerInstructions(const ATarget: string): string;

  public
    constructor Create(AConfigManager: TFPDevConfigManager); overload;
    constructor Create(AConfigManager: IConfigManager); overload;
    destructor Destroy; override;

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

const
  // 支持的交叉编译目标
  CROSS_TARGETS: array[0..11] of TCrossTargetInfo = (
    (Platform: ctpWin32; Name: 'win32'; DisplayName: 'Windows 32-bit'; CPU: 'i386'; OS: 'win32'; BinutilsPrefix: 'i686-w64-mingw32-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpWin64; Name: 'win64'; DisplayName: 'Windows 64-bit'; CPU: 'x86_64'; OS: 'win64'; BinutilsPrefix: 'x86_64-w64-mingw32-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinux32; Name: 'linux32'; DisplayName: 'Linux 32-bit'; CPU: 'i386'; OS: 'linux'; BinutilsPrefix: 'i686-linux-gnu-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinux64; Name: 'linux64'; DisplayName: 'Linux 64-bit'; CPU: 'x86_64'; OS: 'linux'; BinutilsPrefix: 'x86_64-linux-gnu-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinuxARM; Name: 'linuxarm'; DisplayName: 'Linux ARM'; CPU: 'arm'; OS: 'linux'; BinutilsPrefix: 'arm-linux-gnueabihf-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinuxARM64; Name: 'linuxarm64'; DisplayName: 'Linux ARM64'; CPU: 'aarch64'; OS: 'linux'; BinutilsPrefix: 'aarch64-linux-gnu-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpDarwin32; Name: 'darwin32'; DisplayName: 'macOS 32-bit'; CPU: 'i386'; OS: 'darwin'; BinutilsPrefix: 'i686-apple-darwin-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpDarwin64; Name: 'darwin64'; DisplayName: 'macOS 64-bit'; CPU: 'x86_64'; OS: 'darwin'; BinutilsPrefix: 'x86_64-apple-darwin-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpDarwinARM64; Name: 'darwinarm64'; DisplayName: 'macOS ARM64'; CPU: 'aarch64'; OS: 'darwin'; BinutilsPrefix: 'aarch64-apple-darwin-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpAndroid; Name: 'android'; DisplayName: 'Android'; CPU: 'arm'; OS: 'android'; BinutilsPrefix: 'arm-linux-androideabi-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpiOS; Name: 'ios'; DisplayName: 'iOS'; CPU: 'aarch64'; OS: 'ios'; BinutilsPrefix: 'aarch64-apple-ios-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpFreeBSD64; Name: 'freebsd64'; DisplayName: 'FreeBSD 64-bit'; CPU: 'x86_64'; OS: 'freebsd'; BinutilsPrefix: 'x86_64-freebsd-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False)
  );

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
end;

destructor TCrossCompilerManager.Destroy;
begin
  if Assigned(FBuildTester) then
    FBuildTester.Free;
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TCrossCompilerManager.PlatformToString(APlatform: TCrossTargetPlatform): string;
begin
  case APlatform of
    ctpWin32: Result := 'win32';
    ctpWin64: Result := 'win64';
    ctpLinux32: Result := 'linux32';
    ctpLinux64: Result := 'linux64';
    ctpLinuxARM: Result := 'linuxarm';
    ctpLinuxARM64: Result := 'linuxarm64';
    ctpDarwin32: Result := 'darwin32';
    ctpDarwin64: Result := 'darwin64';
    ctpDarwinARM64: Result := 'darwinarm64';
    ctpAndroid: Result := 'android';
    ctpiOS: Result := 'ios';
    ctpFreeBSD64: Result := 'freebsd64';
    ctpCustom: Result := 'custom';
  else
    Result := 'unknown';
  end;
end;

function TCrossCompilerManager.StringToPlatform(const AStr: string): TCrossTargetPlatform;
begin
  if SameText(AStr, 'win32') then Result := ctpWin32
  else if SameText(AStr, 'win64') then Result := ctpWin64
  else if SameText(AStr, 'linux32') then Result := ctpLinux32
  else if SameText(AStr, 'linux64') then Result := ctpLinux64
  else if SameText(AStr, 'linuxarm') then Result := ctpLinuxARM
  else if SameText(AStr, 'linuxarm64') then Result := ctpLinuxARM64
  else if SameText(AStr, 'darwin32') then Result := ctpDarwin32
  else if SameText(AStr, 'darwin64') then Result := ctpDarwin64
  else if SameText(AStr, 'darwinarm64') then Result := ctpDarwinARM64
  else if SameText(AStr, 'android') then Result := ctpAndroid
  else if SameText(AStr, 'ios') then Result := ctpiOS
  else if SameText(AStr, 'freebsd64') then Result := ctpFreeBSD64
  else Result := ctpCustom;
end;

function TCrossCompilerManager.DetectSystemCrossCompiler(const ATarget: string; out ABinutilsPath: string): Boolean;
var
  SearchPaths: array of string;
  Prefix, GCCExe: string;
  i: Integer;
begin
  Result := False;
  ABinutilsPath := '';

  // Determine binutils prefix based on target
  case StringToPlatform(ATarget) of
    ctpWin32: Prefix := 'i686-w64-mingw32-';
    ctpWin64: Prefix := 'x86_64-w64-mingw32-';
    ctpLinux32: Prefix := 'i686-linux-gnu-';
    ctpLinux64: Prefix := 'x86_64-linux-gnu-';
    ctpLinuxARM: Prefix := 'arm-linux-gnueabihf-';
    ctpLinuxARM64: Prefix := 'aarch64-linux-gnu-';
    ctpDarwin64: Prefix := 'x86_64-apple-darwin-';
    ctpDarwinARM64: Prefix := 'aarch64-apple-darwin-';
    ctpAndroid: Prefix := 'arm-linux-androideabi-';
  else
    Exit;
  end;

  // Search paths for cross compilers
  SearchPaths := nil;
  {$IFDEF UNIX}
  SetLength(SearchPaths, 4);
  SearchPaths[0] := '/usr/bin';
  SearchPaths[1] := '/usr/local/bin';
  SearchPaths[2] := '/opt/cross/bin';
  SearchPaths[3] := ExpandFileName('~/.local/bin');
  {$ELSE}
  SetLength(SearchPaths, 3);
  SearchPaths[0] := 'C:' + PathDelim + 'mingw64' + PathDelim + 'bin';
  SearchPaths[1] := 'C:' + PathDelim + 'mingw32' + PathDelim + 'bin';
  SearchPaths[2] := GetEnvironmentVariable('MINGW_HOME') + PathDelim + 'bin';
  {$ENDIF}

  // Search for GCC with the target prefix
  for i := 0 to High(SearchPaths) do
  begin
    GCCExe := SearchPaths[i] + PathDelim + Prefix + 'gcc';
    {$IFDEF MSWINDOWS}
    GCCExe := GCCExe + '.exe';
    {$ENDIF}

    if FileExists(GCCExe) then
    begin
      ABinutilsPath := SearchPaths[i];
      Result := True;
      Exit;
    end;
  end;
end;

function TCrossCompilerManager.GetPackageManagerInstructions(const ATarget: string): string;
begin
  Result := '';

  {$IFDEF LINUX}
  case StringToPlatform(ATarget) of
    ctpWin32, ctpWin64:
      Result := 'Install MinGW cross compiler:' + LineEnding +
                '  Debian/Ubuntu: sudo apt-get install gcc-mingw-w64' + LineEnding +
                '  Fedora/RHEL:   sudo dnf install mingw64-gcc mingw32-gcc' + LineEnding +
                '  Arch Linux:    sudo pacman -S mingw-w64-gcc';
    ctpLinuxARM:
      Result := 'Install ARM cross compiler:' + LineEnding +
                '  Debian/Ubuntu: sudo apt-get install gcc-arm-linux-gnueabihf' + LineEnding +
                '  Fedora/RHEL:   sudo dnf install arm-linux-gnueabihf-gcc' + LineEnding +
                '  Arch Linux:    sudo pacman -S arm-linux-gnueabihf-gcc';
    ctpLinuxARM64:
      Result := 'Install AArch64 cross compiler:' + LineEnding +
                '  Debian/Ubuntu: sudo apt-get install gcc-aarch64-linux-gnu' + LineEnding +
                '  Fedora/RHEL:   sudo dnf install aarch64-linux-gnu-gcc' + LineEnding +
                '  Arch Linux:    sudo pacman -S aarch64-linux-gnu-gcc';
  else
    Result := 'Cross compiler not available via package manager.' + LineEnding +
              'Please install manually and use "fpdev cross configure".';
  end;
  {$ENDIF}

  {$IFDEF DARWIN}
  case StringToPlatform(ATarget) of
    ctpWin32, ctpWin64:
      Result := 'Install MinGW cross compiler:' + LineEnding +
                '  Homebrew: brew install mingw-w64';
    ctpLinuxARM, ctpLinuxARM64:
      Result := 'Install ARM cross compiler:' + LineEnding +
                '  Homebrew: brew install arm-linux-gnueabihf-binutils';
  else
    Result := 'Cross compiler not available via Homebrew.' + LineEnding +
              'Please install manually and use "fpdev cross configure".';
  end;
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  case StringToPlatform(ATarget) of
    ctpLinux32, ctpLinux64, ctpLinuxARM, ctpLinuxARM64:
      Result := 'Install cross compiler from:' + LineEnding +
                '  https://gnutoolchains.com/raspberry/' + LineEnding +
                '  Or use WSL for Linux cross-compilation.';
  else
    Result := 'Cross compiler not readily available.' + LineEnding +
              'Please install manually and use "fpdev cross configure".';
  end;
  {$ENDIF}

  if Result = '' then
    Result := 'Please install the cross compiler manually and use "fpdev cross configure".';
end;

function TCrossCompilerManager.GetTargetInstallPath(const ATarget: string): string;
begin
  Result := FInstallRoot + PathDelim + 'cross' + PathDelim + ATarget;
end;

function TCrossCompilerManager.IsTargetInstalled(const ATarget: string): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, CrossTarget) and CrossTarget.Enabled;
end;

function TCrossCompilerManager.ValidateTarget(const ATarget: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(CROSS_TARGETS) do
  begin
    if SameText(CROSS_TARGETS[i].Name, ATarget) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TCrossCompilerManager.GetTargetInfo(const ATarget: string): TCrossTargetInfo;
var
  i: Integer;
begin
  System.Initialize(Result);
  for i := 0 to High(CROSS_TARGETS) do
  begin
    if SameText(CROSS_TARGETS[i].Name, ATarget) then
    begin
      Result := CROSS_TARGETS[i];
      Result.Installed := IsTargetInstalled(ATarget);
      Break;
    end;
  end;
end;

function TCrossCompilerManager.GetAvailableTargets: TCrossTargetArray;
var
  i: Integer;
  RepoTargets: SysUtils.TStringArray;
  RepoInfo: fpdev.resource.repo.TCrossToolchainInfo;
  HostPlatform: string;
begin
  Result := nil;

  // First try to get targets from fpdev-repo
  if Assigned(FResourceRepo) then
  begin
    RepoTargets := FResourceRepo.ListCrossTargets;
    HostPlatform := GetCurrentPlatform;

    if Length(RepoTargets) > 0 then
    begin
      SetLength(Result, Length(RepoTargets));
      for i := 0 to High(RepoTargets) do
      begin
        Result[i].Platform := StringToPlatform(RepoTargets[i]);
        Result[i].Name := RepoTargets[i];
        Result[i].Available := FResourceRepo.HasCrossToolchain(RepoTargets[i], HostPlatform);
        Result[i].Installed := IsTargetInstalled(RepoTargets[i]);

        // Get detailed info from fpdev-repo
        if FResourceRepo.GetCrossToolchainInfo(RepoTargets[i], HostPlatform, RepoInfo) then
        begin
          Result[i].DisplayName := RepoInfo.DisplayName;
          Result[i].CPU := RepoInfo.CPU;
          Result[i].OS := RepoInfo.OS;
          Result[i].BinutilsPrefix := RepoInfo.BinutilsPrefix;
        end
        else
        begin
          // Fallback to built-in info
          Result[i].DisplayName := RepoTargets[i];
          Result[i].CPU := '';
          Result[i].OS := '';
          Result[i].BinutilsPrefix := '';
        end;
      end;
      Exit;
    end;
  end;

  // Fallback to built-in targets
  SetLength(Result, Length(CROSS_TARGETS));
  for i := 0 to High(CROSS_TARGETS) do
  begin
    Result[i] := CROSS_TARGETS[i];
    Result[i].Installed := IsTargetInstalled(Result[i].Name);
  end;
end;

function TCrossCompilerManager.GetInstalledTargets: TCrossTargetArray;
var
  AllTargets: TCrossTargetArray;
  i, Count: Integer;
begin
  Result := nil;
  AllTargets := GetAvailableTargets;
  Count := 0;

  // 计算已安装目标数量
  for i := 0 to High(AllTargets) do
    if AllTargets[i].Installed then
      Inc(Count);

  // 创建结果数组
  SetLength(Result, Count);
  Count := 0;

  for i := 0 to High(AllTargets) do
  begin
    if AllTargets[i].Installed then
    begin
      Result[Count] := AllTargets[i];
      Inc(Count);
    end;
  end;
end;

function TCrossCompilerManager.DownloadBinutils(const ATarget: string; const ATargetInfo: TCrossTargetInfo; Outp: IOutput): Boolean;
var
  Manifest: TCrossManifest;
  ManifestTarget: TCrossManifestTarget;
  Binutils: TCrossBinutils;
  HostPlatform: string;
  DestPath, ExtractPath, Err: string;
  ManifestPath: string;
  RepoInfo: fpdev.resource.repo.TCrossToolchainInfo;
  LResult: TProcessResult;
  LO: IOutput;
begin
  Result := False;
  if ATarget = '' then Exit;
  if ATargetInfo.Name = '' then Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  HostPlatform := GetCurrentPlatform;

  // First try to install from fpdev-repo
  if Assigned(FResourceRepo) and FResourceRepo.HasCrossToolchain(ATarget, HostPlatform) then
  begin
    if FResourceRepo.GetCrossToolchainInfo(ATarget, HostPlatform, RepoInfo) then
    begin
      DestPath := GetTargetInstallPath(ATarget);
      if FResourceRepo.InstallCrossToolchain(ATarget, HostPlatform, DestPath) then
      begin
        LO.WriteLn(_(MSG_CROSS_BINUTILS_INSTALLED));
        Result := True;
        Exit;
      end;
    end;
  end;

  // Fallback to cross_manifest.json
  Manifest := TCrossManifest.Create;
  try
    // Try to load from install root first, then from current directory
    ManifestPath := FInstallRoot + PathDelim + 'cross_manifest.json';
    if not FileExists(ManifestPath) then
      ManifestPath := 'cross_manifest.json';

    if not Manifest.LoadFromFile(ManifestPath) then
    begin
      // Manifest not found - return False to trigger instructions
      LO.WriteLn(_Fmt(MSG_CROSS_MANIFEST_NOT_FOUND, [ManifestPath]));
      Result := False;
      Exit;
    end;

    // Get target info from manifest
    if not Manifest.GetTarget(ATarget, ManifestTarget) then
    begin
      LO.WriteLn(_Fmt(MSG_CROSS_TARGET_NOT_IN_MANIFEST, [ATarget]));
      Result := False;
      Exit;
    end;

    // Get binutils for current host platform
    if not Manifest.GetBinutilsForHost(ManifestTarget, HostPlatform, Binutils) then
    begin
      LO.WriteLn(_Fmt(MSG_CROSS_NO_BINUTILS, [ATarget, HostPlatform]));
      Result := False;
      Exit;
    end;

    // Check if we have download URLs
    if Length(Binutils.URLs) = 0 then
    begin
      LO.WriteLn(_Fmt(MSG_CROSS_NO_DOWNLOAD_URLS, [ATarget]));
      Result := False;
      Exit;
    end;

    // Download binutils
    DestPath := GetTargetInstallPath(ATarget) + PathDelim + 'binutils.tar.xz';
    ExtractPath := GetTargetInstallPath(ATarget) + PathDelim + 'bin';

    LO.WriteLn(_Fmt(MSG_CROSS_DOWNLOADING_BINUTILS, [ATarget]));
    LO.WriteLn(_Fmt(MSG_CROSS_URL, [Binutils.URLs[0]]));

    if not EnsureDownloadedCached(Binutils.URLs, DestPath, Binutils.Sha256, 120000, Err) then
    begin
      LO.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_DOWNLOAD_FAILED, [Err]));
      Exit(False);
    end;

    LO.WriteLn(_(MSG_CROSS_EXTRACTING));

    // Create extraction directory
    if not DirectoryExists(ExtractPath) then
      EnsureDir(ExtractPath);

    // Extract based on file extension
    if (Pos('.zip', LowerCase(DestPath)) > 0) or (Pos('.zip', LowerCase(Binutils.URLs[0])) > 0) then
    begin
      if not ZipExtract(DestPath, ExtractPath, Err) then
      begin
        LO.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXTRACT_FAILED, [Err]));
        Exit(False);
      end;
    end
    else
    begin
      // For tar.xz, tar.gz, use system tar command
      LResult := TProcessExecutor.Execute('tar', ['-xf', DestPath, '-C', ExtractPath], '');
      if not LResult.Success then
      begin
        LO.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TAR_FAILED, [LResult.ExitCode]));
        Exit(False);
      end;
    end;

    LO.WriteLn(_(MSG_CROSS_BINUTILS_SUCCESS));
    Result := True;

  finally
    Manifest.Free;
  end;
end;

function TCrossCompilerManager.DownloadLibraries(const ATarget: string; const ATargetInfo: TCrossTargetInfo; Outp: IOutput): Boolean;
var
  Manifest: TCrossManifest;
  ManifestTarget: TCrossManifestTarget;
  DestPath, ExtractPath, Err: string;
  ManifestPath: string;
  LResult: TProcessResult;
  LO: IOutput;
begin
  Result := False;
  if ATarget = '' then Exit;
  if ATargetInfo.Name = '' then Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  // Load manifest
  Manifest := TCrossManifest.Create;
  try
    // Try to load from install root first, then from current directory
    ManifestPath := FInstallRoot + PathDelim + 'cross_manifest.json';
    if not FileExists(ManifestPath) then
      ManifestPath := 'cross_manifest.json';

    if not Manifest.LoadFromFile(ManifestPath) then
    begin
      // Manifest not found - allow manual configuration
      LO.WriteLn(_(MSG_CROSS_LIBS_MANIFEST_NOT_FOUND));
      LO.WriteLn(_(MSG_CROSS_LIBS_MANUAL_INSTALL));
      Result := True; // Allow manual configuration
      Exit;
    end;

    // Get target info from manifest
    if not Manifest.GetTarget(ATarget, ManifestTarget) then
    begin
      LO.WriteLn(_Fmt(MSG_CROSS_TARGET_NOT_IN_MANIFEST, [ATarget]));
      LO.WriteLn(_(MSG_CROSS_LIBS_MANUAL_INSTALL));
      Result := True; // Allow manual configuration
      Exit;
    end;

    // Check if we have library download URLs
    if Length(ManifestTarget.Libraries.URLs) = 0 then
    begin
      LO.WriteLn(_Fmt(MSG_CROSS_NO_LIBS_URL, [ATarget]));
      LO.WriteLn(_(MSG_CROSS_LIBS_NOTE));
      Result := True; // Allow manual configuration
      Exit;
    end;

    // Download libraries
    DestPath := GetTargetInstallPath(ATarget) + PathDelim + 'libraries.tar.xz';
    ExtractPath := GetTargetInstallPath(ATarget) + PathDelim + 'lib';

    LO.WriteLn(_Fmt(MSG_CROSS_DOWNLOADING_LIBS, [ATarget]));
    LO.WriteLn(_Fmt(MSG_CROSS_URL, [ManifestTarget.Libraries.URLs[0]]));

    if not EnsureDownloadedCached(ManifestTarget.Libraries.URLs, DestPath,
                                   ManifestTarget.Libraries.Sha256, 120000, Err) then
    begin
      LO.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_DOWNLOAD_FAILED, [Err]));
      Exit(False);
    end;

    LO.WriteLn(_(MSG_CROSS_EXTRACTING));

    // Create extraction directory
    if not DirectoryExists(ExtractPath) then
      EnsureDir(ExtractPath);

    // Extract based on file extension
    if (Pos('.zip', LowerCase(DestPath)) > 0) or (Pos('.zip', LowerCase(ManifestTarget.Libraries.URLs[0])) > 0) then
    begin
      if not ZipExtract(DestPath, ExtractPath, Err) then
      begin
        LO.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXTRACT_FAILED, [Err]));
        Exit(False);
      end;
    end
    else
    begin
      // For tar.xz, tar.gz, use system tar command
      LResult := TProcessExecutor.Execute('tar', ['-xf', DestPath, '-C', ExtractPath], '');
      if not LResult.Success then
      begin
        LO.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TAR_FAILED, [LResult.ExitCode]));
        Exit(False);
      end;
    end;

    LO.WriteLn(_(MSG_CROSS_LIBS_SUCCESS));
    Result := True;

  finally
    Manifest.Free;
  end;
end;

function TCrossCompilerManager.SetupCrossEnvironment(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
var
  CrossTarget: TCrossTarget;
  InstallPath: string;
begin
  Result := False;
  if ATargetInfo.Name = '' then;

  try
    InstallPath := GetTargetInstallPath(ATarget);

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

  if not ValidateTarget(ATarget) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  if IsTargetInstalled(ATarget) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_ALREADY_INSTALLED, [ATarget]));
    Result := True;
    Exit;
  end;

  try
    TargetInfo := GetTargetInfo(ATarget);
    InstallPath := GetTargetInstallPath(ATarget);

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

  if not IsTargetInstalled(ATarget) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_TARGET_NOT_INSTALLED_MSG, [ATarget]));
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetTargetInstallPath(ATarget);

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

  if not ValidateTarget(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  try
    TargetInfo := GetTargetInfo(ATarget);
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_DISPLAY_NAME, [TargetInfo.DisplayName]));
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_CPU, [TargetInfo.CPU]));
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_OS, [TargetInfo.OS]));
    LO.WriteLn(_Fmt(MSG_CROSS_SHOW_BINUTILS_PREFIX, [TargetInfo.BinutilsPrefix]));

    if TargetInfo.Installed then
    begin
      InstallPath := GetTargetInstallPath(ATarget);
      if InstallPath = '' then;
      // Note: CrossTarget info retrieved but not currently displayed
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

  if not IsTargetInstalled(ATarget) then
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
    GCCExe := CrossTarget.BinutilsPath + PathDelim + GetTargetInfo(ATarget).BinutilsPrefix + 'gcc';
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
  if not IsTargetInstalled(ATarget) then
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

  TargetInfo := GetTargetInfo(ATarget);

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

  if not ValidateTarget(ATarget) then
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
  if not ValidateTarget(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  // Check if target is installed
  if not IsTargetInstalled(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_INSTALLED, [ATarget]));
    LO.WriteLn(_Fmt(MSG_CROSS_USE_INSTALL_FIRST, [ATarget]));
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_CROSS_UPDATING, [ATarget]));

  TargetInfo := GetTargetInfo(ATarget);

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
  if not ValidateTarget(ATarget) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  // Check if target is installed
  if not IsTargetInstalled(ATarget) then
  begin
    LO.WriteLn(_Fmt(MSG_CROSS_NOT_INSTALLED_NOTHING, [ATarget]));
    Result := True;
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_CROSS_CLEANING, [ATarget]));

  // Get paths
  InstallPath := GetTargetInstallPath(ATarget);
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
