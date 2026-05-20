unit fpdev.package.manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.package.manager

Free Pascal package management service


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
  fpdev.toolchain.fetcher, fpdev.toolchain.extract, fpdev.paths,
  fpdev.resource.repo, fpdev.resource.repo.types,
  fpdev.utils.fs,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes, fpdev.pkg.builder, fpdev.pkg.repository,
  fpdev.pkg.version, fpdev.package.types, fpdev.package.fetch, fpdev.package.managerflow,
  fpdev.package.metadataio;

type
  TPackageManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FPackageRegistry: string;
    FLastPublishExitCode: Integer;
    FResourceRepo: TResourceRepository;
    FBuilder: TPackageBuilder;
    FRepoService: TPackageRepositoryService;
    FOfflineMode: Boolean;

    function GetAvailablePackages: TPackageArray;
    function GetInstalledPackages: TPackageArray;
    function DownloadPackage(const APackageName, AVersion: string): Boolean;
    function InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
    function ValidatePackage(const APackageName: string): Boolean;
    function ResolveAndInstallDependencies(
      const APackageInfo: TPackageInfo;
      Outp: IOutput;
      Errp: IOutput
    ): Boolean;
    function GetPackageInstallPath(const APackageName: string): string;
    function IsPackageInstalled(const APackageName: string): Boolean;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
    function ResolveDependencies(const APackageName: string): TStringArray;
    function BuildPackage(const ASourcePath: string): Boolean;
    function BuildPackageDownloadPlan(
      const APackageName, AVersion, ACacheDir: string;
      const AAvailablePackages: TPackageArray;
      out APlan: TPackageDownloadPlan
    ): Boolean;
    function EnsurePackageDownloaded(
      const AURLs: TStringArray;
      const ADestFile: string;
      const AOptions: TFetchOptions;
      out AErr: string
    ): Boolean;
    function InstallPackageArchive(
      const APackageName, AVersion, AZipPath, ASandboxDir: string;
      AKeepArtifacts: Boolean;
      out ACleanupWarningPath: string;
      out AErr: string
    ): Boolean;
    function PathExists(const APath: string): Boolean;
    function DeletePath(const APath: string): Boolean;
    function ResolveLocalPackageName(const AMetaPath, ADefaultName: string): string;
    function WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;
    function ParseLocalPackageIndex(const AIndexPath: string): TPackageArray;

  public
    constructor Create(AConfigManager: TFPDevConfigManager); overload;
    constructor Create(AConfigManager: IConfigManager); overload;
    destructor Destroy; override;

    procedure SetKeepBuildArtifacts(const AValue: Boolean);
    procedure SetOfflineMode(const AValue: Boolean);
    function GetAvailablePackageList: TPackageArray;
    function GetInstalledPackageList: TPackageArray;
    function Clean(
      const Scope: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function InstallPackage(
      const APackageName: string;
      const AVersion: string = '';
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function UninstallPackage(
      const APackageName: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function UpdatePackage(
      const APackageName: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function ListPackages(const AShowAll: Boolean = False; Outp: IOutput = nil): Boolean;
    function SearchPackages(const AQuery: string; Outp: IOutput = nil): Boolean;
    function ShowPackageInfo(const APackageName: string; Outp: IOutput = nil): Boolean;
    function ShowPackageDependencies(const APackageName: string): Boolean;
    function VerifyPackage(
      const APackageName: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function AddRepository(
      const AName, AURL: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function RemoveRepository(
      const AName: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function UpdateRepositories(Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListRepositories(Outp: IOutput = nil): Boolean;
    function InstallFromLocal(
      const APackagePath: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function CreatePackage(
      const APackageName, APath: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function PublishPackage(
      const APackageName: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function GetLastPublishExitCode: Integer;
    function GetDepsForPackage(const APackageName: string): TStringArray;
    function TraceDependencyPath(const APackageName: string): TStringArray;
    function GetProjectDependencies: TStringArray;
  end;

implementation

uses
  fpdev.package.cleanflow,
  fpdev.package.facadeflow,
  fpdev.package.indexparser,
  fpdev.package.installflow,
  fpdev.package.lifecycle,
  fpdev.package.lockfile,
  fpdev.package.publishflow,
  fpdev.package.query.available,
  fpdev.package.query.info,
  fpdev.package.query.installed,
  fpdev.package.queryflow,
  fpdev.package.verification,
  fpdev.package.creation;

const
  PACKAGE_NAME_PATH_SEPARATOR: Char = '/';
  PACKAGE_NAME_PATH_SEPARATOR_STR = '/';
  PACKAGE_DEFAULT_VERSION = '1.0.0';

constructor TPackageManager.Create(AConfigManager: TFPDevConfigManager);
begin
  Create(AConfigManager.AsConfigManager);
end;

constructor TPackageManager.Create(AConfigManager: IConfigManager);
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
    FInstallRoot := GetDataRoot;

    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  FPackageRegistry := FInstallRoot + PathDelim + 'packages';
  EnsureDir(FPackageRegistry);

  RepoConfig := CreateDefaultConfig;
  FResourceRepo := TResourceRepository.Create(RepoConfig);
  if DirectoryExists(RepoConfig.LocalPath) then
    FResourceRepo.LoadManifest;

  FBuilder := TPackageBuilder.Create;
  FRepoService := TPackageRepositoryService.Create(FConfigManager, FPackageRegistry);
  FLastPublishExitCode := EXIT_OK;
end;

procedure TPackageManager.SetKeepBuildArtifacts(const AValue: Boolean);
begin
  FBuilder.KeepArtifacts := AValue;
end;

procedure TPackageManager.SetOfflineMode(const AValue: Boolean);
begin
  FOfflineMode := AValue;
end;

function TPackageManager.Clean(const Scope: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := ExecutePackageCleanCore(
    Scope,
    GetSandboxDir,
    IncludeTrailingPathDelimiter(GetCacheDir) + 'packages',
    @PathExists,
    @DeletePath,
    Outp,
    Errp
  );
end;

destructor TPackageManager.Destroy;
begin
  if Assigned(FRepoService) then
    FRepoService.Free;
  if Assigned(FBuilder) then
    FBuilder.Free;
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TPackageManager.ResolveAndInstallDependencies(
  const APackageInfo: TPackageInfo;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
var
  AvailablePackages: TPackageArray;
begin
  AvailablePackages := GetAvailablePackages;
  Result := ExecutePackageDependencyInstallCore(
    APackageInfo,
    AvailablePackages,
    @InstallPackage,
    Outp,
    Errp
  );
end;

function TPackageManager.GetPackageInstallPath(const APackageName: string): string;
begin
  Result := GetPackageInstallPathCore(FPackageRegistry, APackageName);
end;

function TPackageManager.IsPackageInstalled(const APackageName: string): Boolean;
begin
  Result := IsPackageInstalledCore(FPackageRegistry, APackageName);
end;

function TPackageManager.ValidatePackage(const APackageName: string): Boolean;
begin
  Result := ValidatePackageNameCore(APackageName, PACKAGE_NAME_PATH_SEPARATOR_STR);
end;

function TPackageManager.GetPackageInfo(const APackageName: string): TPackageInfo;
var
  Available: TPackageArray;
  I: Integer;
begin
  Result := GetPackageInfoCore(APackageName, FPackageRegistry, '');
  if Result.Installed and (Result.Version <> '') and (Length(Result.Dependencies) > 0) then
    Exit;

  Available := GetAvailablePackages;
  for I := 0 to High(Available) do
    if SameText(Available[I].Name, APackageName) then
    begin
      if Result.Version = '' then
        Result.Version := Available[I].Version;
      if Result.Description = '' then
        Result.Description := Available[I].Description;
      if Result.Author = '' then
        Result.Author := Available[I].Author;
      if Result.License = '' then
        Result.License := Available[I].License;
      if Result.Homepage = '' then
        Result.Homepage := Available[I].Homepage;
      if Result.Repository = '' then
        Result.Repository := Available[I].Repository;
      if Length(Result.Dependencies) = 0 then
        Result.Dependencies := Available[I].Dependencies;
      Exit;
    end;
end;

function TPackageManager.ParseLocalPackageIndex(const AIndexPath: string): TPackageArray;
var
  RegistryIndexPath, CustomIndexPath: string;
  RegistryPkgs, CustomPkgs: TPackageArray;
  I, J, Count: Integer;
  Found: Boolean;
begin
  RegistryIndexPath := IncludeTrailingPathDelimiter(FInstallRoot) +
    'registry' + PathDelim + 'packages' + PathDelim + 'index.json';
  CustomIndexPath := FPackageRegistry + PathDelim + 'index.json';

  if FileExists(RegistryIndexPath) then
    RegistryPkgs := ParseLocalPackageIndexCore(RegistryIndexPath)
  else
    SetLength(RegistryPkgs, 0);

  if FileExists(CustomIndexPath) then
    CustomPkgs := ParseLocalPackageIndexCore(CustomIndexPath)
  else
    SetLength(CustomPkgs, 0);

  SetLength(Result, Length(CustomPkgs) + Length(RegistryPkgs));
  Count := 0;

  for I := 0 to High(CustomPkgs) do
  begin
    Result[Count] := CustomPkgs[I];
    Inc(Count);
  end;

  for I := 0 to High(RegistryPkgs) do
  begin
    Found := False;
    for J := 0 to Count - 1 do
      if SameText(Result[J].Name, RegistryPkgs[I].Name) then
      begin
        Found := True;
        Break;
      end;
    if not Found then
    begin
      Result[Count] := RegistryPkgs[I];
      Inc(Count);
    end;
  end;

  SetLength(Result, Count);
end;

function TPackageManager.GetAvailablePackages: TPackageArray;
var
  RepoListPackages: TAvailablePackageRepoLister;
  RepoGetPackageInfo: TAvailablePackageRepoInfoGetter;
begin
  RepoListPackages := nil;
  RepoGetPackageInfo := nil;
  if Assigned(FResourceRepo) then
  begin
    RepoListPackages := @FResourceRepo.ListPackages;
    RepoGetPackageInfo := @FResourceRepo.GetPackageInfo;
  end;

  Result := GetAvailablePackagesCore(
    FPackageRegistry,
    PACKAGE_NAME_PATH_SEPARATOR,
    RepoListPackages,
    RepoGetPackageInfo,
    @IsPackageInstalled,
    @ParseLocalPackageIndex
  );
end;

function TPackageManager.GetInstalledPackages: TPackageArray;
begin
  Result := GetInstalledPackagesCore(FPackageRegistry, @GetPackageInfo);
end;

function TPackageManager.DownloadPackage(const APackageName, AVersion: string): Boolean;
var
  Avail: TPackageArray;
begin
  Avail := GetAvailablePackages;
  Result := DownloadPackageCore(
    APackageName,
    AVersion,
    GetCacheDir,
    Avail,
    @EnsureDownloadedCached
  );
end;

function TPackageManager.BuildPackage(const ASourcePath: string): Boolean;
begin
  Result := FBuilder.BuildPackage(ASourcePath);
end;

function TPackageManager.BuildPackageDownloadPlan(
  const APackageName, AVersion, ACacheDir: string;
  const AAvailablePackages: TPackageArray;
  out APlan: TPackageDownloadPlan
): Boolean;
begin
  Result := BuildPackageDownloadPlanCore(APackageName, AVersion, ACacheDir, AAvailablePackages, APlan);
end;

function TPackageManager.EnsurePackageDownloaded(
  const AURLs: TStringArray;
  const ADestFile: string;
  const AOptions: TFetchOptions;
  out AErr: string
): Boolean;
begin
  Result := EnsureDownloadedCached(AURLs, ADestFile, AOptions, AErr);
end;

function TPackageManager.InstallPackageArchive(
  const APackageName, AVersion, AZipPath, ASandboxDir: string;
  AKeepArtifacts: Boolean;
  out ACleanupWarningPath: string;
  out AErr: string
): Boolean;
begin
  Result := InstallPackageArchiveCore(
    APackageName,
    AVersion,
    AZipPath,
    ASandboxDir,
    AKeepArtifacts,
    @ZipExtract,
    @InstallPackageFromSource,
    ACleanupWarningPath,
    AErr
  );
end;

function TPackageManager.PathExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

function TPackageManager.DeletePath(const APath: string): Boolean;
begin
  Result := DeleteDirRecursive(APath);
end;

function TPackageManager.ResolveLocalPackageName(const AMetaPath, ADefaultName: string): string;
begin
  Result := ResolvePackageNameFromMetadataCore(AMetaPath, ADefaultName);
end;

function TPackageManager.WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;
var
  BuildTool: string;
  BuildLog: string;
begin
  BuildTool := '';
  BuildLog := '';
  if Assigned(FBuilder) then
  begin
    BuildTool := FBuilder.LastBuildTool;
    BuildLog := FBuilder.LastBuildLog;
  end;

  Result := WritePackageMetadataCore(AInstallPath, Info, BuildTool, BuildLog);
end;

function TPackageManager.InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
begin
  Result := ExecutePackageInstallFromSourceCore(
    APackageName,
    ASourcePath,
    GetPackageInstallPath(APackageName),
    @DeleteDirRecursive,
    @CopyDirRecursive,
    @EnsureDir,
    @GetPackageInfo,
    @BuildPackage,
    @WritePackageMetadata
  );
end;

function TPackageManager.ResolveDependencies(const APackageName: string): TStringArray;
var
  AvailablePackages: TPackageArray;
  InstalledPackages: TPackageArray;
begin
  AvailablePackages := GetAvailablePackages;
  InstalledPackages := GetInstalledPackages;
  Result := ResolvePackageDependenciesCore(
    APackageName,
    AvailablePackages,
    InstalledPackages,
    @ExtractPackageName
  );
end;

function TPackageManager.InstallPackage(
  const APackageName: string;
  const AVersion: string;
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

  try
    Result := ExecutePackageManagerInstallCore(
      APackageName,
      AVersion,
      GetCacheDir,
      GetSandboxDir,
      FBuilder.KeepArtifacts,
      FOfflineMode,
      @ValidatePackage,
      @IsPackageInstalled,
      @GetAvailablePackages,
      @BuildPackageDownloadPlan,
      @ResolveAndInstallDependencies,
      @EnsurePackageDownloaded,
      @InstallPackageArchive,
      LO,
      LE
    );
  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.UninstallPackage(
  const APackageName: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Result := False;

  try
    Result := UninstallPackageCore(
      APackageName,
      GetPackageInstallPath(APackageName),
      IsPackageInstalled(APackageName),
      @DeleteDirRecursive,
      Outp,
      Errp
    );
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_UNINSTALL_FAILED, [E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageManager.UpdatePackage(
  const APackageName: string;
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

  Result := ExecutePackageManagerUpdateCore(
    APackageName,
    @ValidatePackage,
    @IsPackageInstalled,
    @GetPackageInfo,
    @GetAvailablePackages,
    @UninstallPackage,
    @InstallPackage,
    LO,
    LE
  );
end;

function TPackageManager.ListPackages(const AShowAll: Boolean; Outp: IOutput): Boolean;
var
  LO: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    Result := ExecutePackageListCore(
      AShowAll,
      @GetAvailablePackages,
      @GetInstalledPackages,
      _(CMD_PKG_LIST_HEADER),
      _(CMD_PKG_LIST_AVAILABLE_HEADER),
      _(CMD_PKG_LIST_EMPTY),
      _(CMD_PKG_LIST_AVAILABLE_EMPTY),
      LO
    );
  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.SearchPackages(const AQuery: string; Outp: IOutput): Boolean;
var
  LO: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    Result := ExecutePackageSearchCore(
      AQuery,
      @GetAvailablePackages,
      _(CMD_PKG_SEARCH_STATUS_INSTALLED),
      _(CMD_PKG_SEARCH_STATUS_AVAILABLE),
      _(CMD_PKG_SEARCH_NO_RESULTS),
      LO
    );
  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ShowPackageInfo(const APackageName: string; Outp: IOutput): Boolean;
var
  LO: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    Result := ExecutePackageInfoCore(
      APackageName,
      @GetPackageInfo,
      _(MSG_PKG_INFO_NAME),
      _(MSG_PKG_INFO_VERSION),
      _(MSG_PKG_INFO_DESC),
      _(MSG_PKG_INFO_PATH),
      LO
    );
  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ShowPackageDependencies(const APackageName: string): Boolean;
var
  Dependencies: TStringArray;
  LO: IOutput;
begin
  Result := False;

  try
    Dependencies := ResolveDependencies(APackageName);
    LO := TConsoleOutput.Create(False) as IOutput;
    Result := WritePackageDependencyLinesCore(APackageName, Dependencies, LO);
  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.VerifyPackage(
  const APackageName: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
var
  LO, LE: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  Result := ExecutePackageVerifyCore(
    APackageName,
    @IsPackageInstalled,
    @GetPackageInstallPath,
    LO,
    LE
  );
end;

function TPackageManager.AddRepository(
  const AName, AURL: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Result := FRepoService.AddRepository(AName, AURL, Outp, Errp);
end;

function TPackageManager.RemoveRepository(
  const AName: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Result := FRepoService.RemoveRepository(AName, Outp, Errp);
end;

function TPackageManager.UpdateRepositories(Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := FRepoService.UpdateRepositories(Outp, Errp);
end;

function TPackageManager.ListRepositories(Outp: IOutput): Boolean;
begin
  Result := FRepoService.ListRepositories(Outp);
end;

function TPackageManager.InstallFromLocal(
  const APackagePath: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Result := ExecutePackageInstallFromLocalCore(
    APackagePath,
    Outp,
    Errp,
    @PathExists,
    @ResolveLocalPackageName,
    @InstallPackageFromSource
  );
end;

function TPackageManager.CreatePackage(
  const APackageName, APath: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
var
  LO: IOutput;
begin
  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  Result := ExecutePackageCreateCore(
    APackageName,
    APath,
    GetCurrentDir,
    LO,
    Errp,
    @ValidatePackage,
    @PathExists,
    @EnsurePackageMetadataFileCore
  );
end;

function TPackageManager.PublishPackage(
  const APackageName: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
var
  LO, LE: IOutput;
begin
  FLastPublishExitCode := EXIT_ERROR;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  Result := ExecutePackagePublishCore(
    APackageName,
    PACKAGE_DEFAULT_VERSION,
    FInstallRoot,
    LO,
    LE,
    @IsPackageInstalled,
    @GetPackageInstallPath,
    @TryResolvePublishMetadataCore,
    @HandlePublishMetadataFailureCore,
    @CreatePublishArchiveCore,
    FLastPublishExitCode
  );
end;

function TPackageManager.GetLastPublishExitCode: Integer;
begin
  Result := FLastPublishExitCode;
end;

function TPackageManager.GetAvailablePackageList: TPackageArray;
begin
  Result := GetAvailablePackages;
end;

function TPackageManager.GetInstalledPackageList: TPackageArray;
begin
  Result := GetInstalledPackages;
end;

function TPackageManager.GetDepsForPackage(const APackageName: string): TStringArray;
var
  Info: TPackageInfo;
begin
  Info := GetPackageInfo(APackageName);
  Result := Info.Dependencies;
end;

function ExtractDepName(const ADep: string): string;
var
  SpacePos: SizeInt;
begin
  SpacePos := Pos(' ', ADep);
  if SpacePos > 0 then
    Result := Copy(ADep, 1, SpacePos - 1)
  else
    Result := ADep;
end;

function TPackageManager.TraceDependencyPath(const APackageName: string): TStringArray;
var
  AllPkgs: TPackageArray;
  ProjectDeps: TStringArray;
  ProjectPkg: TPackageInfo;
  Visited: TStringList;
  I, J: Integer;

  function FindParent(const ATarget: string): string;
  var
    PI, DJ: Integer;
  begin
    Result := '';
    for PI := 0 to High(AllPkgs) do
      for DJ := 0 to High(AllPkgs[PI].Dependencies) do
        if SameText(ExtractDepName(AllPkgs[PI].Dependencies[DJ]), ATarget) then
          Exit(AllPkgs[PI].Name);
  end;

  procedure BuildPath(const ATarget: string);
  var
    Parent: string;
    Chain: TStringArray;
    Len, K: Integer;
  begin
    Chain := nil;
    SetLength(Chain, 1);
    Chain[0] := ATarget;
    Visited := TStringList.Create;
    try
      Visited.CaseSensitive := False;
      Visited.Add(ATarget);
      Parent := FindParent(ATarget);
      while Parent <> '' do
      begin
        if Visited.IndexOf(Parent) >= 0 then
          Break;
        Visited.Add(Parent);
        Len := Length(Chain);
        SetLength(Chain, Len + 1);
        Chain[Len] := Parent;
        Parent := FindParent(Parent);
      end;
    finally
      Visited.Free;
    end;

    if Length(Chain) < 2 then
    begin
      Result := nil;
      Exit;
    end;

    SetLength(Result, Length(Chain) + 1);
    Result[0] := _(CMD_PKG_DEPS_CURRENT_PROJECT);
    for K := High(Chain) downto 0 do
      Result[Length(Chain) - K] := Chain[K];
  end;

begin
  Result := nil;
  AllPkgs := GetInstalledPackages;
  if Length(AllPkgs) = 0 then
    AllPkgs := GetAvailablePackages;

  ProjectDeps := GetProjectDependencies;
  if Length(ProjectDeps) > 0 then
  begin
    ProjectPkg := EmptyPackageInfo;
    ProjectPkg.Name := _(CMD_PKG_DEPS_CURRENT_PROJECT);
    ProjectPkg.Dependencies := ProjectDeps;
    SetLength(AllPkgs, Length(AllPkgs) + 1);
    AllPkgs[High(AllPkgs)] := ProjectPkg;
  end;

  for I := 0 to High(AllPkgs) do
    for J := 0 to High(AllPkgs[I].Dependencies) do
      if SameText(ExtractDepName(AllPkgs[I].Dependencies[J]), APackageName) then
      begin
        BuildPath(APackageName);
        Exit;
      end;
end;

function TPackageManager.GetProjectDependencies: TStringArray;
var
  LockPath: string;
  LockFile: TPackageLockFile;
  Names: TStringList;
  I: Integer;
begin
  Result := nil;
  LockPath := IncludeTrailingPathDelimiter(GetCurrentDir) + LOCKFILE_NAME;
  if not FileExists(LockPath) then
    Exit;

  LockFile := TPackageLockFile.Create(LockPath);
  try
    if not LockFile.Load then
      Exit;
    Names := LockFile.GetPackageNames;
    try
      SetLength(Result, Names.Count);
      for I := 0 to Names.Count - 1 do
        Result[I] := Names[I];
    finally
      Names.Free;
    end;
  finally
    LockFile.Free;
  end;
end;

end.
