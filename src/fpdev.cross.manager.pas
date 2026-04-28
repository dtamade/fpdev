unit fpdev.cross.manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cross.manager

Cross-compilation toolchain management service


## Notice

If you redistribute or use this in your own project, please keep this project's copyright notice. Thank you.

fafafaStudio
Email:dtamade@gmail.com
QQ Group:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config, fpdev.config.interfaces, fpdev.output.intf, fpdev.output.console,
  fpdev.cross.downloader, fpdev.cross.platform,
  fpdev.resource.repo, fpdev.resource.repo.types,
  fpdev.utils, fpdev.utils.fs, fpdev.utils.process, fpdev.paths,
  fpdev.i18n.strings, fpdev.cross.tester, fpdev.cross.query;

type
  TCrossToolchainDownloaderFactory = function(const ADataRoot, AManifestURL: string): TCrossToolchainDownloader;

var
  { Test seam: allows injecting a spy downloader to verify which commands trigger manifest loads.
    Production default is nil => uses TCrossToolchainDownloader.Create. }
  CrossToolchainDownloaderFactory: TCrossToolchainDownloaderFactory;

type
  { TCrossTargetInfo - Re-exported from query helper for backward compatibility }
  TCrossTargetInfo = fpdev.cross.query.TCrossTargetQueryInfo;
  TCrossTargetArray = fpdev.cross.query.TCrossTargetQueryArray;

  { TCrossCompilerManager }
  TCrossCompilerManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;  // fpdev-repo integration (legacy)
    FBuildTester: TCrossBuildTester;     // Cross-build testing service
    FDownloader: TCrossToolchainDownloader;  // Modern toolchain downloader
    FQuery: TCrossTargetQuery;           // Target query helper

    function DetectSystemCompilerForTarget(const ATarget: string; out ABinutilsPath: string): Boolean;
    function GetCrossTargetConfig(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function GetPackageManagerInstructionsForTarget(const ATarget: string): string;
    function RemoveCrossTargetConfig(const ATarget: string): Boolean;
    function SaveCrossTargetConfig(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function GetDownloaderLastError: string;
    function ExecuteDownloaderBinutils(const ATarget: string): Boolean;
    function ExecuteDownloaderLibraries(const ATarget: string): Boolean;
    function ExecuteProcess(const AExecutable: string;
      const AParams: SysUtils.TStringArray; const AWorkDir: string): TProcessResult;
    function ExecuteBuildTest(const ATarget, ACPU, AOS, ABinutilsPath, ALibrariesPath,
      ASourceFile: string): TCrossBuildTestResult;
    function DownloadBinutils(
      const ATarget: string;
      const {%H-} ATargetInfo: TCrossTargetInfo;
      Outp: IOutput = nil
    ): Boolean;
    function DownloadLibraries(
      const ATarget: string;
      const {%H-} ATargetInfo: TCrossTargetInfo;
      Outp: IOutput = nil
    ): Boolean;
    function SetupCrossEnvironment(
      const ATarget: string;
      const {%H-} ATargetInfo: TCrossTargetInfo
    ): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager); overload;
    constructor Create(AConfigManager: IConfigManager); overload;
    destructor Destroy; override;

    // Target query
    function GetAvailableTargets: TCrossTargetArray;
    function GetInstalledTargets: TCrossTargetArray;

    // Cross-compilation target management
    function InstallTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UninstallTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListTargets(const AShowAll: Boolean = False; Outp: IOutput = nil): Boolean;
    function EnableTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function DisableTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;

    // Toolchain operations
    function ShowTargetInfo(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function TestTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function BuildTest(
      const ATarget: string;
      const ASourceFile: string = '';
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;

    // Configuration management
    function ConfigureTarget(
      const ATarget: string;
      const ABinutilsPath, ALibrariesPath: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function UpdateTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function CleanTarget(const ATarget: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
  end;

implementation

uses
  fpdev.cross.targets,
  fpdev.cross.targetflow,
  fpdev.cross.managerflow,
  fpdev.cross.installsupportflow;

const
  DEFAULT_CROSS_MANIFEST_URL =
    'https://raw.githubusercontent.com/fpdev/fpdev-repo/main/cross-manifest.json';

{ TCrossCompilerManager }

constructor TCrossCompilerManager.Create(AConfigManager: TFPDevConfigManager);
begin
  Create(AConfigManager.AsConfigManager);
end;

constructor TCrossCompilerManager.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
  RepoConfig: TResourceRepoConfig;
  ManifestURL: string;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    FInstallRoot := GetDataRoot;
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
  ManifestURL := get_env('FPDEV_CROSS_MANIFEST_URL');
  if ManifestURL = '' then
    ManifestURL := DEFAULT_CROSS_MANIFEST_URL;

  if Assigned(CrossToolchainDownloaderFactory) then
    FDownloader := CrossToolchainDownloaderFactory(FInstallRoot, ManifestURL)
  else
    FDownloader := TCrossToolchainDownloader.Create(FInstallRoot, ManifestURL);

  // Manifest is loaded lazily by download operations; listing/doctor should not block on network I/O.

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

function TCrossCompilerManager.DetectSystemCompilerForTarget(const ATarget: string;
  out ABinutilsPath: string): Boolean;
begin
  Result := DetectSystemCrossCompiler(ATarget, ABinutilsPath);
end;

function TCrossCompilerManager.GetCrossTargetConfig(const ATarget: string; out AInfo: TCrossTarget): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, AInfo);
end;

function TCrossCompilerManager.GetPackageManagerInstructionsForTarget(const ATarget: string): string;
begin
  Result := GetPackageManagerInstructions(ATarget);
end;

function TCrossCompilerManager.RemoveCrossTargetConfig(const ATarget: string): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.RemoveCrossTarget(ATarget);
end;

function TCrossCompilerManager.SaveCrossTargetConfig(const ATarget: string; const AInfo: TCrossTarget): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, AInfo);
end;

function TCrossCompilerManager.GetDownloaderLastError: string;
begin
  if Assigned(FDownloader) then
    Result := FDownloader.LastError
  else
    Result := '';
end;

function TCrossCompilerManager.ExecuteDownloaderBinutils(const ATarget: string): Boolean;
begin
  Result := Assigned(FDownloader) and FDownloader.DownloadBinutils(ATarget);
end;

function TCrossCompilerManager.ExecuteDownloaderLibraries(const ATarget: string): Boolean;
begin
  Result := Assigned(FDownloader) and FDownloader.DownloadLibraries(ATarget);
end;

function TCrossCompilerManager.ExecuteProcess(const AExecutable: string;
  const AParams: SysUtils.TStringArray; const AWorkDir: string): TProcessResult;
begin
  Result := TProcessExecutor.Execute(AExecutable, AParams, AWorkDir);
end;

function TCrossCompilerManager.ExecuteBuildTest(const ATarget, ACPU, AOS, ABinutilsPath, ALibrariesPath,
  ASourceFile: string): TCrossBuildTestResult;
begin
  Result := FBuildTester.ExecuteTest(ATarget, ACPU, AOS, ABinutilsPath, ALibrariesPath, ASourceFile);
end;

function TCrossCompilerManager.GetAvailableTargets: TCrossTargetArray;
begin
  Result := FQuery.GetAvailableTargets;
end;

function TCrossCompilerManager.GetInstalledTargets: TCrossTargetArray;
begin
  Result := FQuery.GetInstalledTargets;
end;

function TCrossCompilerManager.DownloadBinutils(
  const ATarget: string;
  const {%H-} ATargetInfo: TCrossTargetInfo;
  Outp: IOutput
): Boolean;
var
  LO: IOutput;
  DownloadAction: TCrossInstallSupportDownloadFunc;
  ErrorAction: TCrossInstallSupportErrorFunc;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  if Assigned(FDownloader) then
  begin
    DownloadAction := @ExecuteDownloaderBinutils;
    ErrorAction := @GetDownloaderLastError;
  end
  else
  begin
    DownloadAction := nil;
    ErrorAction := nil;
  end;

  Result := ExecuteCrossDownloadBinutilsSurfaceCore(
    ATarget,
    ATargetInfo,
    DownloadAction,
    ErrorAction,
    LO
  );
end;

function TCrossCompilerManager.DownloadLibraries(
  const ATarget: string;
  const {%H-} ATargetInfo: TCrossTargetInfo;
  Outp: IOutput
): Boolean;
var
  LO: IOutput;
  DownloadAction: TCrossInstallSupportDownloadFunc;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  if Assigned(FDownloader) then
    DownloadAction := @ExecuteDownloaderLibraries
  else
    DownloadAction := nil;

  Result := ExecuteCrossDownloadLibrariesSurfaceCore(
    ATarget,
    ATargetInfo,
    DownloadAction,
    LO
  );
end;

function TCrossCompilerManager.SetupCrossEnvironment(
  const ATarget: string;
  const {%H-} ATargetInfo: TCrossTargetInfo
): Boolean;
begin
  Result := ExecuteCrossSetupEnvironmentSurfaceCore(
    ATarget,
    ATargetInfo,
    @FQuery.GetTargetInstallPath,
    @SaveCrossTargetConfig
  );
end;

function TCrossCompilerManager.InstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  LO: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  Result := ExecuteCrossInstallTargetCore(
    ATarget,
    @FQuery.ValidateTarget,
    @FQuery.IsTargetInstalled,
    @FQuery.GetTargetInfo,
    @FQuery.GetTargetInstallPath,
    @DetectSystemCompilerForTarget,
    @SaveCrossTargetConfig,
    @DownloadBinutils,
    @DownloadLibraries,
    @SetupCrossEnvironment,
    @GetPackageManagerInstructionsForTarget,
    LO,
    Errp
  );
end;

function TCrossCompilerManager.UninstallTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := ExecuteCrossUninstallTargetCore(
    ATarget,
    @FQuery.IsTargetInstalled,
    @FQuery.GetTargetInstallPath,
    @RemoveCrossTargetConfig,
    Outp,
    Errp
  );
end;

function TCrossCompilerManager.ListTargets(const AShowAll: Boolean; Outp: IOutput): Boolean;
var
  LO: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  Result := ExecuteCrossListTargetsCore(
    AShowAll,
    @GetAvailableTargets,
    @GetInstalledTargets,
    LO
  );
end;

function TCrossCompilerManager.EnableTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := SetCrossTargetEnabledCore(ATarget, True, @GetCrossTargetConfig, @SaveCrossTargetConfig, Outp, Errp);
end;

function TCrossCompilerManager.DisableTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := SetCrossTargetEnabledCore(ATarget, False, @GetCrossTargetConfig, @SaveCrossTargetConfig, Outp, Errp);
end;

function TCrossCompilerManager.ShowTargetInfo(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  LO, LE: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  Result := ExecuteCrossShowTargetInfoCore(
    ATarget,
    @FQuery.ValidateTarget,
    @FQuery.GetTargetInfo,
    @FQuery.GetTargetInstallPath,
    LO,
    LE
  );
end;

function TCrossCompilerManager.TestTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := TestCrossTargetCore(
    ATarget,
    FQuery.IsTargetInstalled(ATarget),
    FQuery.GetTargetInfo(ATarget),
    @GetCrossTargetConfig,
    @ExecuteProcess,
    Outp,
    Errp
  );
end;

function TCrossCompilerManager.BuildTest(
  const ATarget: string;
  const ASourceFile: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
var
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  Result := BuildCrossTargetTestCore(
    ATarget,
    ASourceFile,
    FQuery.IsTargetInstalled(ATarget),
    FQuery.GetTargetInfo(ATarget),
    @GetCrossTargetConfig,
    @ExecuteBuildTest,
    LO,
    LE
  );
end;

function TCrossCompilerManager.ConfigureTarget(
  const ATarget: string;
  const ABinutilsPath, ALibrariesPath: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Result := ConfigureCrossTargetCore(
    ATarget,
    ABinutilsPath,
    ALibrariesPath,
    FQuery.ValidateTarget(ATarget),
    @SaveCrossTargetConfig,
    Outp,
    Errp
  );
end;

function TCrossCompilerManager.UpdateTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  LO, LE: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  Result := ExecuteCrossUpdateTargetCore(
    ATarget,
    @FQuery.ValidateTarget,
    @FQuery.IsTargetInstalled,
    @FQuery.GetTargetInfo,
    @DownloadBinutils,
    @DownloadLibraries,
    LO,
    LE
  );
end;

function TCrossCompilerManager.CleanTarget(const ATarget: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  LO, LE: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  Result := ExecuteCrossCleanTargetCore(
    ATarget,
    @FQuery.ValidateTarget,
    @FQuery.IsTargetInstalled,
    @FQuery.GetTargetInstallPath,
    @GetCrossTargetConfig,
    LO,
    LE
  );
end;

end.
