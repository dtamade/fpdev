unit fpdev.cmd.package;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.package

FreePascal 包管理系统


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
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config, fpdev.config.interfaces, fpdev.output.intf, fpdev.output.console,
  fpdev.toolchain.fetcher, fpdev.toolchain.extract, fpdev.paths, fpdev.hash,
  fpdev.resource.repo, fpdev.pkg.deps, fpdev.utils.fs, fpdev.utils, fpdev.utils.process,
  fpdev.i18n, fpdev.i18n.strings, fpdev.pkg.builder, fpdev.pkg.repository,
  fpdev.package.archiver, fpdev.pkg.version;

type
  { TPackageInfo }
  TPackageInfo = record
    Name: string;
    Version: string;
    Description: string;
    Author: string;
    License: string;
    Homepage: string;
    Repository: string;
    Dependencies: TStringArray;
    URLs: TStringArray;   // 下载地址（可空）
    Sha256: string;       // 期望校验（可空）
    SourcePath: string;   // 本地源码/包路径（可空）
    Installed: Boolean;
    InstallPath: string;
    InstallDate: TDateTime;
  end;

  TPackageArray = array of TPackageInfo;

  { TSemanticVersion - Semantic version parsing and comparison }
  TSemanticVersion = record
    Valid: Boolean;
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
    PreRelease: string;
  end;

  { TDependencyGraph - Array-based dependency graph for test compatibility }
  TDependencyGraph = TDependencyNodeArray;

  { TVerificationStatus - Package verification status enum }
  TVerificationStatus = (vsValid, vsInvalid, vsMissingFiles, vsMetadataError);

  { TPackageVerificationResult - Package verification result }
  TPackageVerificationResult = record
    Status: TVerificationStatus;
    PackageName: string;
    Version: string;
    MissingFiles: TStringArray;
  end;

  { TPackageCreationOptions - Package creation options }
  TPackageCreationOptions = record
    Name: string;
    Version: string;
    SourcePath: string;
    ExcludePatterns: TStringArray;
  end;

  { TPackageErrorCode - Package operation error codes }
  TPackageErrorCode = (
    pecNone,
    pecPackageNotFound,
    pecDependencyNotFound,
    pecCircularDependency,
    pecVersionConflict,
    pecInvalidMetadata,
    pecChecksumMismatch,
    pecNetworkError,
    pecFileSystemError,
    pecRepositoryNotConfigured
  );

  { TPackageOperationResult - Package operation result }
  TPackageOperationResult = record
    Success: Boolean;
    ErrorCode: TPackageErrorCode;
    ErrorMessage: string;
  end;

  { TPackageManager }
  TPackageManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FPackageRegistry: string;
    FResourceRepo: TResourceRepository;  // fpdev-repo integration
    FBuilder: TPackageBuilder;  // Build service (Facade delegation)
    FRepoService: TPackageRepositoryService;  // Repository service (Facade delegation)

    function GetAvailablePackages: TPackageArray;
    function GetInstalledPackages: TPackageArray;
    function DownloadPackage(const APackageName, AVersion: string): Boolean;
    function InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
    function ValidatePackage(const APackageName: string): Boolean;
    { Dependency resolution }
    function ResolveAndInstallDependencies(const APackageInfo: TPackageInfo; Outp, Errp: IOutput): Boolean;

  function GetPackageInstallPath(const APackageName: string): string;
    function IsPackageInstalled(const APackageName: string): Boolean;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
    function ResolveDependencies(const APackageName: string): TStringArray;
    function BuildPackage(const ASourcePath: string): Boolean;

    function WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager); overload;
    constructor Create(AConfigManager: IConfigManager); overload;
    destructor Destroy; override;

    // 设置
    procedure SetKeepBuildArtifacts(const AValue: Boolean);

    // 查询（供测试和上层使用）
    function GetAvailablePackageList: TPackageArray;

    // 清理
    function Clean(const Scope: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean; // 'sandbox' | 'cache' | 'all'

    // 包管理
    function InstallPackage(const APackageName: string; const AVersion: string = ''; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UninstallPackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UpdatePackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListPackages(const AShowAll: Boolean = False; Outp: IOutput = nil): Boolean;
    function SearchPackages(const AQuery: string; Outp: IOutput = nil): Boolean;

    // 包信息
    function ShowPackageInfo(const APackageName: string; Outp: IOutput = nil): Boolean;
    function ShowPackageDependencies(const APackageName: string): Boolean;
    function VerifyPackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;

    // 仓库管理
    function AddRepository(const AName, AURL: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function RemoveRepository(const AName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UpdateRepositories(Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListRepositories(Outp: IOutput = nil): Boolean;

    // 本地包管理
    function InstallFromLocal(const APackagePath: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function CreatePackage(const APackageName, APath: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function PublishPackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
  end;

{ Semantic Version Functions }
function ParseSemanticVersion(const AVersion: string): TSemanticVersion;
function CompareVersions(const AVersion1, AVersion2: string): Integer;
function VersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;

{ Dependency Graph Functions }
function BuildDependencyGraph(const ARootPackage: string; const APackages: TPackageArray): TDependencyNodeArray;
function TopologicalSortDependencies(const AGraph: TDependencyNodeArray): TStringArray;

{ Package Verification Functions }
function VerifyInstalledPackage(const TestDir: string): TPackageVerificationResult;
function VerifyPackageChecksum(const FilePath, Hash: string): Boolean;

{ Package Creation Functions }
function CollectPackageSourceFiles(const SourceDir: string; const ExcludePatterns: TStringArray): TStringArray;
function IsBuildArtifact(const FileName: string): Boolean;
function GeneratePackageMetadataJson(const Options: TPackageCreationOptions): string;
function CreatePackageZipArchive(const SourceDir: string; const Files: TStringArray; const OutputPath: string; var Err: string): Boolean;

{ Package Validation Functions }
function ValidatePackageSourcePath(const SourcePath: string): Boolean;
function ValidatePackageMetadata(const MetadataPath: string): Boolean;
function CheckPackageRequiredFiles(const PackageDir: string): TStringArray;

implementation

{ TPackageManager }

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
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev';
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev';
    {$ENDIF}

    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  FPackageRegistry := FInstallRoot + PathDelim + 'packages';

  // Ensure package directory exists
  EnsureDir(FPackageRegistry);

  // Initialize fpdev-repo integration
  RepoConfig := CreateDefaultConfig;
  FResourceRepo := TResourceRepository.Create(RepoConfig);
  if DirectoryExists(RepoConfig.LocalPath) then
    FResourceRepo.LoadManifest;

  // Initialize build service
  FBuilder := TPackageBuilder.Create;

  // Initialize repository service
  FRepoService := TPackageRepositoryService.Create(FConfigManager, FPackageRegistry);
end;

procedure TPackageManager.SetKeepBuildArtifacts(const AValue: Boolean);
begin
  FBuilder.KeepArtifacts := AValue;
end;

function TPackageManager.Clean(const Scope: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  S: string;
  Ok: Boolean;
  Path: string;
  Existed: Boolean;
  SectionOk: Boolean;
begin
  Result := True;
  S := LowerCase(Trim(Scope));
  Ok := True;
  if (S='sandbox') or (S='all') then
  begin
    Path := GetSandboxDir;
    Existed := DirectoryExists(Path);
    if Existed then
      SectionOk := DeleteDirRecursive(Path)
    else
      SectionOk := True;
    Ok := Ok and SectionOk;
    if Existed then
    begin
      if (Outp <> nil) and SectionOk then
        Outp.WriteLn(_Fmt(MSG_CLEANED, [Path]))
      else if (Errp <> nil) and (not SectionOk) then
        Errp.WriteLn(_Fmt(MSG_CLEAN_FAILED, [Path]));
    end;
  end;
  if (S='cache') or (S='all') then
  begin
    Path := IncludeTrailingPathDelimiter(GetCacheDir) + 'packages';
    Existed := DirectoryExists(Path);
    if Existed then
      SectionOk := DeleteDirRecursive(Path)
    else
      SectionOk := True;
    Ok := Ok and SectionOk;
    if Existed then
    begin
      if (Outp <> nil) and SectionOk then
        Outp.WriteLn(_Fmt(MSG_CLEANED, [Path]))
      else if (Errp <> nil) and (not SectionOk) then
        Errp.WriteLn(_Fmt(MSG_CLEAN_FAILED, [Path]));
    end;
  end;
  Result := Ok;
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

function TPackageManager.ResolveAndInstallDependencies(const APackageInfo: TPackageInfo; Outp, Errp: IOutput): Boolean;
var
  Graph: fpdev.pkg.deps.TDependencyGraph;
  Avail: TPackageArray;
  i, j, DepIdx: Integer;
  ResolveResult: TResolveResult;
  DepPkg: TPackageInfo;
begin
  Result := False;

  if Length(APackageInfo.Dependencies) = 0 then
  begin
    Result := True;  // No dependencies to resolve
    Exit;
  end;

  // Get all available packages for dependency lookup
  Avail := GetAvailablePackages;

  // Build dependency graph
  Graph := fpdev.pkg.deps.TDependencyGraph.Create;
  try
    // Add root package
    Graph.AddNode(APackageInfo.Name, APackageInfo.Version);

    // Add all dependency nodes and edges
    for i := 0 to High(APackageInfo.Dependencies) do
    begin
      // Find dependency package info
      DepIdx := -1;
      for j := 0 to High(Avail) do
      begin
        if SameText(Avail[j].Name, APackageInfo.Dependencies[i]) then
        begin
          DepIdx := j;
          Break;
        end;
      end;

      if DepIdx < 0 then
      begin
        if Errp <> nil then
          Errp.WriteLn('Error: Dependency package not found: ' + APackageInfo.Dependencies[i]);
        Exit;
      end;

      // Add dependency node
      Graph.AddNode(Avail[DepIdx].Name, Avail[DepIdx].Version);

      // Add edge: root -> dependency
      Graph.AddDependency(APackageInfo.Name, Avail[DepIdx].Name);

      // Recursively add dependency's dependencies
      if Length(Avail[DepIdx].Dependencies) > 0 then
      begin
      if Outp <> nil then
        Outp.WriteLn('Adding dependency: ' + Avail[DepIdx].Name);
        // Note: For now, we only add direct dependencies
        // Recursive dependency resolution would require a more complex algorithm
      end;
    end;

    // Resolve installation order
    ResolveResult := Graph.Resolve;

    if not ResolveResult.Success then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + ResolveResult.ErrorMessage);
      Exit;
    end;

    // Install dependencies in reverse order (dependencies first, root last)
    if Outp <> nil then
      Outp.WriteLn('Installing dependencies...');

    for i := High(ResolveResult.ResolvedOrder) downto 0 do
    begin
      if SameText(ResolveResult.ResolvedOrder[i], APackageInfo.Name) then
        Continue;  // Skip the root package

      // Find dependency package
      DepIdx := -1;
      for j := 0 to High(Avail) do
      begin
        if SameText(Avail[j].Name, ResolveResult.ResolvedOrder[i]) then
        begin
          DepIdx := j;
          Break;
        end;
      end;

      if DepIdx < 0 then
        Continue;

      DepPkg := Avail[DepIdx];

      if Outp <> nil then
        Outp.WriteLn('Installing dependency: ' + DepPkg.Name);

      // Install dependency
      if not InstallPackage(DepPkg.Name, DepPkg.Version, Outp, Errp) then
      begin
        if Errp <> nil then
          Errp.WriteLn('Error: Failed to install dependency: ' + DepPkg.Name);
        Exit;
      end;
    end;

    Result := True;
  finally
    Graph.Free;
  end;
end;

function TPackageManager.GetPackageInstallPath(const APackageName: string): string;
begin
  Result := FPackageRegistry + PathDelim + APackageName;
end;

function TPackageManager.IsPackageInstalled(const APackageName: string): Boolean;
var
  InstallPath: string;
begin
  InstallPath := GetPackageInstallPath(APackageName);
  Result := DirectoryExists(InstallPath);
end;

function TPackageManager.ValidatePackage(const APackageName: string): Boolean;
begin
  // 简单的包名验证
  Result := (APackageName <> '') and (Pos(' ', APackageName) = 0) and (Pos('/', APackageName) = 0);
end;

function TPackageManager.GetPackageInfo(const APackageName: string): TPackageInfo;
var
  MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
begin
  // 初始化包信息
  Initialize(Result);
  Result.Name := APackageName;
  Result.Installed := IsPackageInstalled(APackageName);

  if Result.Installed then
  begin
    Result.InstallPath := GetPackageInstallPath(APackageName);
    // 尝试读取元数据
    MetaPath := IncludeTrailingPathDelimiter(Result.InstallPath) + 'package.json';
    if FileExists(MetaPath) then
    begin
      SL := TStringList.Create;
      try
        SL.LoadFromFile(MetaPath);
        J := GetJSON(SL.Text);
        try
          if J.JSONType=jtObject then
          begin
            O := TJSONObject(J);
            Result.Name := O.Get('name', APackageName);
            Result.Version := O.Get('version', '');
            Result.Description := O.Get('description', '');
            Result.Homepage := O.Get('homepage', '');
            Result.License := O.Get('license', '');
            Result.Repository := O.Get('repository', '');
            Result.SourcePath := O.Get('source_path', '');
          end;
        finally
          J.Free;
        end;
      finally
        SL.Free;
      end;
    end
    else
    begin
      Result.Version := '';
      Result.Description := 'Installed package';
    end;
  end;
end;

function TPackageManager.GetAvailablePackages: TPackageArray;
var
  IndexPath: string;
  JSONData: TJSONData = nil;
  Arr: TJSONArray;
  i, j, Count: Integer;
  Pkg: TPackageInfo;
  Names: TStringList;
  RepoPackages: SysUtils.TStringArray;
  RepoInfo: fpdev.resource.repo.TPackageInfo;

// Internal helper functions
  function TryGetArray(AData: TJSONData): TJSONArray;
  begin
    Result := nil;
    if AData=nil then Exit(nil);
    if AData.JSONType=jtArray then Exit(TJSONArray(AData));
    if (AData.JSONType=jtObject) and Assigned(TJSONObject(AData).Arrays['packages']) then
      Exit(TJSONObject(AData).Arrays['packages']);
  end;

  procedure MaybeReadURLsAndSha(const O: TJSONObject; var P: TPackageInfo);
  var U: TJSONData; K: Integer;
  begin
    P.Sha256 := O.Get('sha256','');
    SetLength(P.URLs, 0);
    U := O.Find('url');
    if Assigned(U) then
    begin
      if U.JSONType=jtString then
      begin
        SetLength(P.URLs, 1);
        P.URLs[0] := U.AsString;
      end
      else if U.JSONType=jtArray then
      begin
        SetLength(P.URLs, TJSONArray(U).Count);
        for K := 0 to TJSONArray(U).Count-1 do
          P.URLs[K] := TJSONArray(U).Items[K].AsString;
      end;
    end;
  end;

begin
  Initialize(Result);
  SetLength(Result, 0);

  // First try to get packages from fpdev-repo
  if Assigned(FResourceRepo) then
  begin
    RepoPackages := FResourceRepo.ListPackages('');
    if Length(RepoPackages) > 0 then
    begin
      SetLength(Result, Length(RepoPackages));
      Count := 0;
      for i := 0 to High(RepoPackages) do
      begin
        // Skip category entries (ending with /)
        if (Length(RepoPackages[i]) > 0) and (RepoPackages[i][Length(RepoPackages[i])] = '/') then
          Continue;

        Initialize(Pkg);
        if FResourceRepo.GetPackageInfo(RepoPackages[i], '', RepoInfo) then
        begin
          Pkg.Name := RepoInfo.Name;
          Pkg.Version := RepoInfo.Version;
          Pkg.Description := RepoInfo.Description;
          Pkg.Installed := IsPackageInstalled(Pkg.Name);
          Result[Count] := Pkg;
          Inc(Count);
        end;
      end;
      SetLength(Result, Count);
      if Count > 0 then
        Exit;  // Found packages in fpdev-repo
    end;
  end;

  // Fallback to local index.json
  IndexPath := FPackageRegistry + PathDelim + 'index.json';
  if not FileExists(IndexPath) then
  begin
    Exit;
  end;
  try
    with TStringList.Create do
    try
      LoadFromFile(IndexPath);
      JSONData := GetJSON(Text);
    finally
      Free;
    end;

    Arr := TryGetArray(JSONData);
    if Arr=nil then Exit;

    // 过滤无效条目：必须有 name、version、url（字符串或数组非空）
    // 去重：按 name 选择最高版本
    Names := TStringList.Create;
    try
      Initialize(Pkg);
      Names.Sorted := True; Names.Duplicates := dupIgnore; Names.CaseSensitive := False;
      for i := 0 to Arr.Count-1 do
      begin
        if (Arr.Items[i].JSONType<>jtObject) then Continue;
        if TJSONObject(Arr.Items[i]).Get('name','')='' then Continue;
        if TJSONObject(Arr.Items[i]).Get('version','')='' then Continue;
        // url 校验：字符串非空或数组长度>0
        if Assigned(TJSONObject(Arr.Items[i]).Find('url')) then
        begin
          if (TJSONObject(Arr.Items[i]).Find('url').JSONType=jtString) and (TJSONObject(Arr.Items[i]).Get('url','')='') then Continue;
          if (TJSONObject(Arr.Items[i]).Find('url').JSONType=jtArray) and (TJSONArray(TJSONObject(Arr.Items[i]).Find('url')).Count=0) then Continue;
        end
        else
          Continue;
        Names.Add(TJSONObject(Arr.Items[i]).Get('name',''));
      end;

      Count := 0;
      SetLength(Result, Names.Count);
      for i := 0 to Names.Count-1 do
      begin
        Finalize(Pkg);
        Initialize(Pkg);
        for j := 0 to Arr.Count-1 do
        begin
          if Arr.Items[j].JSONType<>jtObject then Continue;
          if not SameText(TJSONObject(Arr.Items[j]).Get('name',''), Names[i]) then Continue;
          // 二次校验（防御）
          if (TJSONObject(Arr.Items[j]).Get('version','')='') then Continue;
          if Assigned(TJSONObject(Arr.Items[j]).Find('url')) then
          begin
            if (TJSONObject(Arr.Items[j]).Find('url').JSONType=jtString) and (TJSONObject(Arr.Items[j]).Get('url','')='') then Continue;
            if (TJSONObject(Arr.Items[j]).Find('url').JSONType=jtArray) and (TJSONArray(TJSONObject(Arr.Items[j]).Find('url')).Count=0) then Continue;
          end
          else Continue;

          // 选择最高版本
          if (Pkg.Name='') or IsVersionHigher(TJSONObject(Arr.Items[j]).Get('version',''), Pkg.Version) then
          begin
            Pkg.Name := TJSONObject(Arr.Items[j]).Get('name','');
            Pkg.Version := TJSONObject(Arr.Items[j]).Get('version','');
            Pkg.Description := TJSONObject(Arr.Items[j]).Get('description','');
            Pkg.Homepage := TJSONObject(Arr.Items[j]).Get('homepage','');
            Pkg.License := TJSONObject(Arr.Items[j]).Get('license','');
            Pkg.Repository := TJSONObject(Arr.Items[j]).Get('repository','');
            MaybeReadURLsAndSha(TJSONObject(Arr.Items[j]), Pkg);
          end;
        end;
        if (Pkg.Name<>'') then
        begin
          Result[Count] := Pkg;
          Inc(Count);
        end;
      end;
      SetLength(Result, Count);
    finally
      Finalize(Pkg);
      Names.Free;
    end;
  finally
    if Assigned(JSONData) then JSONData.Free;
  end;
end;

function TPackageManager.GetInstalledPackages: TPackageArray;
var
  SearchRec: TSearchRec;
  Count: Integer;
begin
  Initialize(Result);
  SetLength(Result, 0);
  Count := 0;

  if FindFirst(FPackageRegistry + PathDelim + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory <> 0) and
         (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        SetLength(Result, Count + 1);
        Result[Count] := GetPackageInfo(SearchRec.Name);
        Inc(Count);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

function TPackageManager.DownloadPackage(const APackageName, AVersion: string): Boolean;
var
  Avail: TPackageArray;
  i, BestIdx: Integer;
  UseVersion, ZipPath, Err: string;
  Opt: TFetchOptions;
  URLs: array of string;

begin
  Result := False;
  URLs := nil;

  if (APackageName = '') then
    Exit;

  // Find package in available index
  Avail := GetAvailablePackages;
  BestIdx := -1;
  for i := 0 to High(Avail) do
  begin
    if SameText(Avail[i].Name, APackageName) then
    begin
      if (AVersion='') then
      begin
        if (BestIdx<0) or IsVersionHigher(Avail[i].Version, Avail[BestIdx].Version) then
          BestIdx := i;
      end
      else if SameText(Avail[i].Version, AVersion) then
        BestIdx := i;
    end;
  end;

  if BestIdx < 0 then
    Exit;  // Package not found in index

  UseVersion := Avail[BestIdx].Version;
  if Length(Avail[BestIdx].URLs) = 0 then
    Exit;  // No download URLs available

  // Construct cache path
  ZipPath := IncludeTrailingPathDelimiter(GetCacheDir) + 'packages' + PathDelim +
             APackageName + '-' + UseVersion + '.zip';
  EnsureDir(ExtractFileDir(ZipPath));

  // Prepare URLs array
  SetLength(URLs, Length(Avail[BestIdx].URLs));
  for i := 0 to High(URLs) do
    URLs[i] := Avail[BestIdx].URLs[i];

  // Setup fetch options
  Opt.DestDir := ExtractFileDir(ZipPath);
  Opt.Hash := Avail[BestIdx].Sha256;
  Opt.HashAlgorithm := haSHA256;
  Opt.HashDigest := Avail[BestIdx].Sha256;
  Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;
  Opt.ExpectedSize := 0;

  // Download with mirror fallback and SHA256 verification
  Result := EnsureDownloadedCached(URLs, ZipPath, Opt, Err);
end;

function TPackageManager.BuildPackage(const ASourcePath: string): Boolean;
begin
  // Delegate to build service
  Result := FBuilder.BuildPackage(ASourcePath);
end;



function TPackageManager.InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
var
  InstallPath: string;
  Info: TPackageInfo;
begin
  Result := False;

  try
    InstallPath := GetPackageInstallPath(APackageName);

    // 确保安装目录存在
    if not DirectoryExists(InstallPath) then
      EnsureDir(InstallPath);

    // 复制源码到安装目录（后续实现为递归拷贝；当前保留源路径记录）
    Info := GetPackageInfo(APackageName);
    Info.SourcePath := ASourcePath;

    if not BuildPackage(ASourcePath) then
    begin
      Exit;
    end;

    // 写入元数据（补充构建工具信息）
    Info := GetPackageInfo(APackageName);
    Info.SourcePath := ASourcePath;
    Info.Version := Info.Version; // 保持占位逻辑
    Info.Description := Info.Description;
    if not WritePackageMetadata(InstallPath, Info) then

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ResolveDependencies(const APackageName: string): TStringArray;
var
  Graph: fpdev.pkg.deps.TDependencyGraph;
  ResolveResult: TResolveResult;
  Avail: TPackageArray;
  Visited: TStringList;
  i: Integer;

  procedure BuildDependencyTree(const APkgName: string);
  var
    Idx, k: Integer;
    PkgInfo: TPackageInfo;
    DepName: string;
  begin
    // Avoid infinite recursion
    if Visited.IndexOf(APkgName) >= 0 then
      Exit;
    Visited.Add(APkgName);

    // Find package in available packages
    Idx := -1;
    for k := 0 to High(Avail) do
    begin
      if SameText(Avail[k].Name, APkgName) then
      begin
        Idx := k;
        Break;
      end;
    end;

    if Idx < 0 then
    begin
      // Try to get from installed packages
      PkgInfo := GetPackageInfo(APkgName);
      if PkgInfo.Name = '' then
        Exit;  // Package not found
      Graph.AddNode(APkgName, PkgInfo.Version);
      // Add dependencies from installed package
      for k := 0 to High(PkgInfo.Dependencies) do
      begin
        // Parse version constraint to extract package name
        DepName := ExtractPackageName(PkgInfo.Dependencies[k]);
        if DepName = '' then
          DepName := PkgInfo.Dependencies[k];  // Fallback to original if parsing fails
        Graph.AddDependency(APkgName, DepName);
        BuildDependencyTree(DepName);
      end;
    end
    else
    begin
      // Add node from available packages
      Graph.AddNode(APkgName, Avail[Idx].Version);
      // Add dependencies
      for k := 0 to High(Avail[Idx].Dependencies) do
      begin
        // Parse version constraint to extract package name
        DepName := ExtractPackageName(Avail[Idx].Dependencies[k]);
        if DepName = '' then
          DepName := Avail[Idx].Dependencies[k];  // Fallback to original if parsing fails
        Graph.AddDependency(APkgName, DepName);
        BuildDependencyTree(DepName);
      end;
    end;
  end;

begin
  Initialize(Result);
  SetLength(Result, 0);

  if APackageName = '' then
    Exit;

  // Get all available packages for dependency lookup
  Avail := GetAvailablePackages;

  Graph := fpdev.pkg.deps.TDependencyGraph.Create;
  Visited := TStringList.Create;
  try
    Visited.CaseSensitive := False;

    // Build dependency tree starting from root package
    BuildDependencyTree(APackageName);

    // Resolve dependencies with topological sort
    ResolveResult := Graph.Resolve;

    if ResolveResult.Success then
    begin
      // Copy resolved order to result (dependencies first, then dependents)
      SetLength(Result, Length(ResolveResult.ResolvedOrder));
      for i := 0 to High(ResolveResult.ResolvedOrder) do
        Result[i] := ResolveResult.ResolvedOrder[i];
    end
    else
    begin
      // On failure (e.g., cycle detected), return just the root package
      // and log the error
      if ResolveResult.HasCycle then
      begin
        // Cycle detected - falling back to root package only
      end;
      SetLength(Result, 1);
      Result[0] := APackageName;
    end;
  finally
    Visited.Free;
    Graph.Free;
  end;
end;

function TPackageManager.InstallPackage(const APackageName: string; const AVersion: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  UseVersion: string;
  Avail: TPackageArray;
  i, BestIdx: Integer;
  ZipPath, TmpDir, Err: string;
  Opt: TFetchOptions;
  URLs: array of string;
  InstalledOK: Boolean;
  LO, LE: IOutput;

begin
  Result := False;
  URLs := nil;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if not ValidatePackage(APackageName) then
  begin
    Exit;
  end;

  if IsPackageInstalled(APackageName) then
  begin
    Exit(True);
  end;

  try
    // 从可用索引选择版本
    Avail := GetAvailablePackages;
    BestIdx := -1;
    for i := 0 to High(Avail) do
    begin
      if SameText(Avail[i].Name, APackageName) then
      begin
        if (AVersion='') then
        begin
          if (BestIdx<0) or IsVersionHigher(Avail[i].Version, Avail[BestIdx].Version) then
            BestIdx := i;
        end
        else if SameText(Avail[i].Version, AVersion) then
          BestIdx := i;
      end;
    end;

    if BestIdx < 0 then
    begin
      Exit;
    end;

    // Resolve dependencies before downloading
    if Length(Avail[BestIdx].Dependencies) > 0 then
    begin
      if Outp <> nil then
        Outp.WriteLn('Resolving dependencies...');
      if not ResolveAndInstallDependencies(Avail[BestIdx], Outp, Errp) then
      begin
        Exit;
      end;
    end;

    UseVersion := Avail[BestIdx].Version;

    if Length(Avail[BestIdx].URLs)=0 then
    begin
      Exit;
    end;

    // 下载到缓存 zip
    ZipPath := IncludeTrailingPathDelimiter(GetCacheDir) + 'packages' + PathDelim + APackageName + '-' + UseVersion + '.zip';
    EnsureDir(ExtractFileDir(ZipPath));

    SetLength(URLs, Length(Avail[BestIdx].URLs));
    for i := 0 to High(URLs) do URLs[i] := Avail[BestIdx].URLs[i];

    Opt.DestDir := ExtractFileDir(ZipPath);
    Opt.Hash := Avail[BestIdx].Sha256;
    Opt.HashAlgorithm := haSHA256;
    Opt.HashDigest := Avail[BestIdx].Sha256;
    Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;
    Opt.ExpectedSize := 0;

    if not EnsureDownloadedCached(URLs, ZipPath, Opt, Err) then
    begin
      Exit;
    end;

    // 解压到临时目录
    TmpDir := IncludeTrailingPathDelimiter(GetSandboxDir) + 'pkg-' + APackageName + '-' + UseVersion;
    if DirectoryExists(TmpDir) then
      ; // 可考虑清理

    if not ZipExtract(ZipPath, TmpDir, Err) then
    begin
      // Extract failed, error message is in Err
      Exit;
    end;

    // 编译安装
    InstalledOK := InstallPackageFromSource(APackageName, TmpDir);
    if not InstalledOK then
    begin
      Exit(False);
    end
    else
    begin
      // Install succeeded, clean up temp directory if configured
      if not FBuilder.KeepArtifacts then
      begin
        if DirectoryExists(TmpDir) then
        begin
          try
            if not DeleteDirRecursive(TmpDir) then
            begin
              LE.WriteLn(_(MSG_WARNING) + ': ' + _Fmt(MSG_PKG_CLEAN_TMP_FAILED, [TmpDir]));
            end;
          except
            on E: Exception do
          end;
        end;
      end
      else
    end;

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.UninstallPackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsPackageInstalled(APackageName) then
  begin
    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_NOT_INSTALLED, [APackageName]));
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetPackageInstallPath(APackageName);

    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_UNINSTALLING, [APackageName]));

    // 删除安装目录
    if DirectoryExists(InstallPath) then
    begin
      if not DeleteDirRecursive(InstallPath) then
      begin
        if Errp <> nil then Errp.WriteLn(_Fmt(MSG_PKG_REMOVE_WARNING, [InstallPath]));
      end;
    end;

    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_UNINSTALL_COMPLETE, [APackageName]));
    Result := True;

  except
    on E: Exception do
    begin
      if Errp <> nil then Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_UNINSTALL_FAILED, [E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageManager.UpdatePackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstalledInfo: TPackageInfo;
  Avail: TPackageArray;
  i, BestIdx: Integer;
  InstalledVersion, LatestVersion: string;
  LO, LE: IOutput;

begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Validate package name
  if not ValidatePackage(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_INVALID_NAME, [APackageName]));
    Exit;
  end;

  // Check if package is installed
  if not IsPackageInstalled(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APackageName]));
    LE.WriteLn(_Fmt(MSG_PKG_INSTALL_HINT, [APackageName]));
    Exit;
  end;

  // Get installed package info
  InstalledInfo := GetPackageInfo(APackageName);
  InstalledVersion := InstalledInfo.Version;
  if InstalledVersion = '' then
    InstalledVersion := '0.0.0';

  LO.WriteLn(_Fmt(MSG_PKG_CHECKING_UPDATES, [APackageName]));
  LO.WriteLn(_Fmt(MSG_PKG_INSTALLED_VERSION, [InstalledVersion]));

  // Get available packages from index
  Avail := GetAvailablePackages;
  BestIdx := -1;

  // Find the latest version in available packages
  for i := 0 to High(Avail) do
  begin
    if SameText(Avail[i].Name, APackageName) then
    begin
      if (BestIdx < 0) or IsVersionHigher(Avail[i].Version, Avail[BestIdx].Version) then
        BestIdx := i;
    end;
  end;

  if BestIdx < 0 then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_IN_INDEX, [APackageName]));
    LE.WriteLn(_(MSG_PKG_REPO_UPDATE_HINT));
    Exit;
  end;

  LatestVersion := Avail[BestIdx].Version;
  LO.WriteLn(_Fmt(MSG_PKG_LATEST_VERSION, [LatestVersion]));

  // Check if update is needed
  if not IsVersionHigher(LatestVersion, InstalledVersion) then
  begin
    LO.WriteLn(_Fmt(MSG_PKG_UP_TO_DATE, [APackageName]));
    Result := True;
    Exit;
  end;

  // Perform update: uninstall old, install new
  LO.WriteLn(_Fmt(MSG_PKG_UPDATING, [APackageName, InstalledVersion, LatestVersion]));

  // Uninstall old version
  LO.WriteLn(_(MSG_PKG_REMOVING_OLD));
  if not UninstallPackage(APackageName, nil, LE) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_UNINSTALL_OLD_FAILED));
    Exit;
  end;

  // Install new version
  LO.WriteLn(_(MSG_PKG_INSTALLING_NEW));
  if not InstallPackage(APackageName, LatestVersion, nil, LE) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_INSTALL_NEW_FAILED));
    LE.WriteLn(_(MSG_PKG_REINSTALL_HINT));
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_PKG_UPDATE_SUCCESS, [APackageName, LatestVersion]));
  Result := True;
end;

function TPackageManager.ListPackages(const AShowAll: Boolean; Outp: IOutput): Boolean;
var
  Packages: TPackageArray;
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
      Packages := GetAvailablePackages
    else
      Packages := GetInstalledPackages;

    if AShowAll then
      LO.WriteLn('Available packages:')
    else
      LO.WriteLn('Installed packages:');

    if Length(Packages) = 0 then
    begin
      if AShowAll then
        LO.WriteLn('  No packages available in index')
      else
        LO.WriteLn('  No packages installed');
    end
    else
    begin
      for i := 0 to High(Packages) do
      begin
        Line := Format('  %-16s  %-10s  %s',
                [Packages[i].Name, Packages[i].Version, Packages[i].Description]);
        LO.WriteLn(Line);
      end;
    end;


  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.SearchPackages(const AQuery: string; Outp: IOutput): Boolean;
var
  Packages: TPackageArray;
  i, Matches: Integer;
  Q: string;
  Line: string;
  LO: IOutput;
  StatusStr: string;
begin
  Result := True;
  Matches := 0;
  Q := LowerCase(Trim(AQuery));
  if Q = '' then
  begin
    Exit(False);
  end;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    // Search in all available packages (including remote index)
    Packages := GetAvailablePackages;


    for i := 0 to High(Packages) do
    begin
      if (Pos(Q, LowerCase(Packages[i].Name)) > 0) or
         (Pos(Q, LowerCase(Packages[i].Description)) > 0) then
      begin
        Inc(Matches);
        if Packages[i].Installed then
          StatusStr := 'Installed'
        else
          StatusStr := 'Available';
        Line := Format('%-16s  %-10s  %-10s  %s',
                [Packages[i].Name, Packages[i].Version, StatusStr, Packages[i].Description]);
        LO.WriteLn(Line);
      end;
    end;

    if Matches = 0 then
      LO.WriteLn('No packages found matching: ' + AQuery);


  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ShowPackageInfo(const APackageName: string; Outp: IOutput): Boolean;
var
  PackageInfo: TPackageInfo;
  LO: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    PackageInfo := GetPackageInfo(APackageName);

    LO.WriteLn(_Fmt(MSG_PKG_INFO_NAME, [PackageInfo.Name]));
    LO.WriteLn(_Fmt(MSG_PKG_INFO_VERSION, [PackageInfo.Version]));
    LO.WriteLn(_Fmt(MSG_PKG_INFO_DESC, [PackageInfo.Description]));

    if PackageInfo.Installed then
      LO.WriteLn(_Fmt(MSG_PKG_INFO_PATH, [PackageInfo.InstallPath]));

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ShowPackageDependencies(const APackageName: string): Boolean;
var
  Dependencies: TStringArray;
  i: Integer;
begin
  Result := False;

  try
    Dependencies := ResolveDependencies(APackageName);


    if Length(Dependencies) = 0 then
    else
    begin
      for i := 0 to High(Dependencies) do
    end;

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.VerifyPackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath, MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  ExpectedSha256, ActualSha256: string;
  FilePath: string;
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Check if package is installed
  if not IsPackageInstalled(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APackageName]));
    Exit;
  end;

  InstallPath := GetPackageInstallPath(APackageName);
  MetaPath := IncludeTrailingPathDelimiter(InstallPath) + 'package.json';

  // Check if metadata exists
  if not FileExists(MetaPath) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_NOT_FOUND, [MetaPath]));
    Exit;
  end;

  // Validate metadata JSON
  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetaPath);
    try
      J := GetJSON(SL.Text);
    except
      on E: Exception do
      begin
        LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_INVALID, [E.Message]));
        Exit;
      end;
    end;

    try
      if J.JSONType <> jtObject then
      begin
        LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_META_NOT_JSON));
        Exit;
      end;

      O := TJSONObject(J);

      // Verify required fields
      if O.Get('name', '') = '' then
      begin
        LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_NAME_MISSING));
        Exit;
      end;

      if O.Get('version', '') = '' then
      begin
        LO.WriteLn(_(MSG_PKG_VERSION_MISSING));
      end;

      // Verify SHA256 if present
      ExpectedSha256 := O.Get('sha256', '');
      if ExpectedSha256 <> '' then
      begin
        FilePath := O.Get('source_path', '');
        if (FilePath <> '') and FileExists(FilePath) then
        begin
          ActualSha256 := SHA256FileHex(FilePath);
          if not SameText(ExpectedSha256, ActualSha256) then
          begin
            LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_CHECKSUM_MISMATCH));
            LE.WriteLn(_Fmt(MSG_PKG_CHECKSUM_EXPECTED, [ExpectedSha256]));
            LE.WriteLn(_Fmt(MSG_PKG_CHECKSUM_ACTUAL, [ActualSha256]));
            Exit;
          end;
          LO.WriteLn(_(MSG_PKG_CHECKSUM_OK));
        end;
      end;

      LO.WriteLn(_Fmt(MSG_PKG_VERIFY_SUCCESS, [APackageName]));
      Result := True;

    finally
      J.Free;
    end;
  finally
    SL.Free;
  end;
end;

function TPackageManager.WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;
var
  MetaPath: string;
  O: TJSONObject;
  SL: TStringList;
  i: Integer;
begin
  Result := False;
  try
    MetaPath := IncludeTrailingPathDelimiter(AInstallPath) + 'package.json';
    O := TJSONObject.Create;
    try
      O.Add('name', Info.Name);
      O.Add('version', Info.Version);
      O.Add('description', Info.Description);
      O.Add('homepage', Info.Homepage);
      O.Add('license', Info.License);
      O.Add('repository', Info.Repository);
      O.Add('install_path', AInstallPath);
      O.Add('install_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
      O.Add('source_path', Info.SourcePath);
      if FBuilder.LastBuildTool<>'' then O.Add('build_tool', FBuilder.LastBuildTool);
      if FBuilder.LastBuildLog<>'' then O.Add('build_log', FBuilder.LastBuildLog);
      if Length(Info.URLs)>0 then
      begin
        begin
          // FPC 不支持局部 var inline 声明，使用临时变量
          // 注意：此处在嵌套 begin..end 内创建并释放数组
          // 改为直接构造数组后添加
          // 为避免生命周期问题，先构造到临时变量再加入对象
          // 但 JSON 对象接管后会拥有其生命周期，这里仍手动释放可能导致双重释放
          // 因此采用：先构造，加入时不释放（由 O 拥有）；无需 finally free
          // 兼容写法：先构造，O.Add 后不要手动 Free
          // 构造
          // 注意：FPC 无匿名块局部变量，改为上层声明（简化实现：直接逐项 Add 到新数组并交给 O 持有）
          // 具体如下：
          // 由于不方便引入上层变量，这里采用直接序列化字符串数组的方式留待改进
          // 简化：不再使用局部变量，直接创建数组并附加
          // create array
          O.Add('url', TJSONArray.Create);
          for i := 0 to High(Info.URLs) do
            TJSONArray(O.Arrays['url']).Add(Info.URLs[i]);
        end;
      end;
      if Info.Sha256<>'' then O.Add('sha256', Info.Sha256);

      SL := TStringList.Create;
      try
        SL.Text := O.FormatJSON;
        EnsureDir(AInstallPath);
        SL.SaveToFile(MetaPath);
        Result := True;
      finally
        SL.Free;
      end;
    finally
      O.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;






function TPackageManager.AddRepository(const AName, AURL: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.AddRepository(AName, AURL, Outp, Errp);
end;

function TPackageManager.RemoveRepository(const AName: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.RemoveRepository(AName, Outp, Errp);
end;

function TPackageManager.UpdateRepositories(Outp: IOutput; Errp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.UpdateRepositories(Outp, Errp);
end;

function TPackageManager.ListRepositories(Outp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.ListRepositories(Outp);
end;

function TPackageManager.InstallFromLocal(const APackagePath: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  PackageName: string;
begin
  Result := False;

  if not DirectoryExists(APackagePath) then
  begin
    if Errp <> nil then Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_PATH_NOT_FOUND, [APackagePath]));
    Exit;
  end;

  try
    // 从路径提取包名
    PackageName := ExtractFileName(APackagePath);
    if PackageName = '' then
      PackageName := 'local_package';

    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_INSTALL_LOCAL, [APackagePath]));
    Result := InstallPackageFromSource(PackageName, APackagePath);
    if Result and (Outp <> nil) then Outp.WriteLn(_Fmt(MSG_PKG_INSTALL_COMPLETE, [PackageName]));

  except
    on E: Exception do
    begin
      if Errp <> nil then Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_EXCEPTION, ['install-local', E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageManager.CreatePackage(const APackageName, APath: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  PackageDir, MetaPath, SourceDir: string;
  O: TJSONObject;
  SL: TStringList;
  LO: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  // Validate package name
  if not ValidatePackage(APackageName) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_INVALID_NAME, [APackageName]));
    Exit;
  end;

  // Determine source directory
  if APath = '' then
    SourceDir := GetCurrentDir
  else
    SourceDir := ExpandFileName(APath);

  if not DirectoryExists(SourceDir) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_SOURCE_NOT_FOUND, [SourceDir]));
    Exit;
  end;

  // Create package directory structure
  PackageDir := SourceDir;
  MetaPath := IncludeTrailingPathDelimiter(PackageDir) + 'package.json';

  // Create package.json if it doesn't exist
  if not FileExists(MetaPath) then
  begin
    O := TJSONObject.Create;
    try
      O.Add('name', APackageName);
      O.Add('version', '1.0.0');
      O.Add('description', 'A FreePascal package');
      O.Add('author', '');
      O.Add('license', 'MIT');
      O.Add('homepage', '');
      O.Add('repository', '');
      O.Add('dependencies', TJSONArray.Create);
      O.Add('keywords', TJSONArray.Create);

      SL := TStringList.Create;
      try
        SL.Text := O.FormatJSON;
        SL.SaveToFile(MetaPath);
        LO.WriteLn(_Fmt(MSG_PKG_CREATED_JSON, [MetaPath]));
      finally
        SL.Free;
      end;
    finally
      O.Free;
    end;
  end
  else
  begin
    LO.WriteLn(_Fmt(MSG_PKG_JSON_EXISTS, [MetaPath]));
  end;

  LO.WriteLn(_Fmt(MSG_PKG_CREATE_SUCCESS, [APackageName]));
  LO.WriteLn('');
  LO.WriteLn(_(MSG_PKG_NEXT_STEPS));
  LO.WriteLn(_(MSG_PKG_STEP_EDIT));
  LO.WriteLn(_(MSG_PKG_STEP_ADD_SOURCE));
  LO.WriteLn(_Fmt(MSG_PKG_STEP_PUBLISH, [APackageName]));

  Result := True;
end;

function TPackageManager.PublishPackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath, MetaPath, ArchivePath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  Version, ArchiveName: string;
  Archiver: TPackageArchiver;
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Check if package is installed/created
  if not IsPackageInstalled(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_FOUND, [APackageName]));
    Exit;
  end;

  InstallPath := GetPackageInstallPath(APackageName);
  MetaPath := IncludeTrailingPathDelimiter(InstallPath) + 'package.json';

  // Check if metadata exists
  if not FileExists(MetaPath) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_NOT_FOUND, ['Run "fpdev package create" first']));
    Exit;
  end;

  // Read version from metadata
  Version := '1.0.0';
  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetaPath);
    try
      J := GetJSON(SL.Text);
      if J.JSONType = jtObject then
      begin
        O := TJSONObject(J);
        Version := O.Get('version', '1.0.0');
      end;
      J.Free;
    except
      // Use default version
    end;
  finally
    SL.Free;
  end;

  // Create archive name
  ArchiveName := APackageName + '-' + Version + '.tar.gz';
  ArchivePath := IncludeTrailingPathDelimiter(FInstallRoot) + 'publish' + PathDelim + ArchiveName;

  // Ensure publish directory exists
  if not DirectoryExists(ExtractFileDir(ArchivePath)) then
    EnsureDir(ExtractFileDir(ArchivePath));

  LO.WriteLn(_Fmt(MSG_PKG_CREATING_ARCHIVE, [ArchiveName]));

  // Create tar.gz archive using TPackageArchiver
  Archiver := TPackageArchiver.Create(InstallPath);
  try
    if not Archiver.CreateArchive(ArchivePath) then
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_ARCHIVE_FAILED, [Archiver.GetLastError]));
      Exit;
    end;

    // Display archive info with SHA256 checksum
    LO.WriteLn(_Fmt(MSG_PKG_ARCHIVE_CREATED, [ArchivePath]));
    LO.WriteLn('SHA256: ' + Archiver.GetChecksum);
    LO.WriteLn('');
    LO.WriteLn(_Fmt(MSG_PKG_READY_PUBLISH, [APackageName, Version]));
    LO.WriteLn('');
    LO.WriteLn(_(MSG_PKG_TO_PUBLISH));
    LO.WriteLn(_(MSG_PKG_PUBLISH_STEP1));
    LO.WriteLn(_(MSG_PKG_PUBLISH_STEP2));

    Result := True;
  finally
    Archiver.Free;
  end;
end;


function TPackageManager.GetAvailablePackageList: TPackageArray;
begin
  Result := GetAvailablePackages;
end;

{ Semantic Version Functions Implementation }

function ParseSemanticVersion(const AVersion: string): TSemanticVersion;
var
  Parts: TStringArray;
  PreReleaseParts: TStringArray;
  VersionPart: string;
  Code: Integer;
  i, DotCount: Integer;
begin
  // Initialize result
  Result.Valid := False;
  Result.Major := 0;
  Result.Minor := 0;
  Result.Patch := 0;
  Result.PreRelease := '';

  if AVersion = '' then
    Exit;

  // Split by '-' to separate version from prerelease
  SetLength(PreReleaseParts, 0);
  if Pos('-', AVersion) > 0 then
  begin
    SetLength(PreReleaseParts, 2);
    PreReleaseParts[0] := Copy(AVersion, 1, Pos('-', AVersion) - 1);
    PreReleaseParts[1] := Copy(AVersion, Pos('-', AVersion) + 1, Length(AVersion));
    VersionPart := PreReleaseParts[0];
    Result.PreRelease := PreReleaseParts[1];
  end
  else
    VersionPart := AVersion;

  // Split version by '.'
  SetLength(Parts, 0);
  DotCount := 0;
  for i := 1 to Length(VersionPart) do
    if VersionPart[i] = '.' then
      Inc(DotCount);

  SetLength(Parts, DotCount + 1);
  if DotCount = 0 then
  begin
    Parts[0] := VersionPart;
  end
  else
  begin
    i := 0;
    while Pos('.', VersionPart) > 0 do
    begin
      Parts[i] := Copy(VersionPart, 1, Pos('.', VersionPart) - 1);
      Delete(VersionPart, 1, Pos('.', VersionPart));
      Inc(i);
    end;
    Parts[i] := VersionPart;
  end;

  // Parse major version
  if Length(Parts) >= 1 then
  begin
    Val(Parts[0], Result.Major, Code);
    if Code <> 0 then
      Exit;
  end;

  // Parse minor version
  if Length(Parts) >= 2 then
  begin
    Val(Parts[1], Result.Minor, Code);
    if Code <> 0 then
      Exit;
  end;

  // Parse patch version
  if Length(Parts) >= 3 then
  begin
    Val(Parts[2], Result.Patch, Code);
    if Code <> 0 then
      Exit;
  end;

  Result.Valid := True;
end;

function CompareVersions(const AVersion1, AVersion2: string): Integer;
var
  V1, V2: TSemanticVersion;
begin
  V1 := ParseSemanticVersion(AVersion1);
  V2 := ParseSemanticVersion(AVersion2);

  // Handle invalid versions
  if not V1.Valid and not V2.Valid then
    Exit(0);
  if not V1.Valid then
    Exit(-1);
  if not V2.Valid then
    Exit(1);

  // Compare major version
  if V1.Major < V2.Major then
    Exit(-1);
  if V1.Major > V2.Major then
    Exit(1);

  // Compare minor version
  if V1.Minor < V2.Minor then
    Exit(-1);
  if V1.Minor > V2.Minor then
    Exit(1);

  // Compare patch version
  if V1.Patch < V2.Patch then
    Exit(-1);
  if V1.Patch > V2.Patch then
    Exit(1);

  // Compare prerelease
  // Version without prerelease is higher than version with prerelease
  if (V1.PreRelease = '') and (V2.PreRelease <> '') then
    Exit(1);
  if (V1.PreRelease <> '') and (V2.PreRelease = '') then
    Exit(-1);

  // Both have prerelease, compare lexicographically
  if V1.PreRelease < V2.PreRelease then
    Exit(-1);
  if V1.PreRelease > V2.PreRelease then
    Exit(1);

  Result := 0;
end;

function VersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;
var
  V, ConstraintV: TSemanticVersion;
  Op: string;
  ConstraintVersion: string;
  Cmp: Integer;
begin
  Result := False;

  // Empty or wildcard constraint accepts any version
  if (AConstraint = '') or (AConstraint = '*') then
    Exit(True);

  V := ParseSemanticVersion(AVersion);
  if not V.Valid then
    Exit(False);

  // Extract operator and version
  if (Length(AConstraint) >= 2) and (AConstraint[1] in ['>', '<', '=', '^', '~']) then
  begin
    if (AConstraint[1] = '>') and (AConstraint[2] = '=') then
    begin
      Op := '>=';
      ConstraintVersion := Copy(AConstraint, 3, Length(AConstraint));
    end
    else if (AConstraint[1] = '<') and (AConstraint[2] = '=') then
    begin
      Op := '<=';
      ConstraintVersion := Copy(AConstraint, 3, Length(AConstraint));
    end
    else if AConstraint[1] = '>' then
    begin
      Op := '>';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '<' then
    begin
      Op := '<';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '=' then
    begin
      Op := '=';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '^' then
    begin
      Op := '^';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '~' then
    begin
      Op := '~';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else
    begin
      // No operator, exact match
      Op := '=';
      ConstraintVersion := AConstraint;
    end;
  end
  else
  begin
    // No operator, exact match
    Op := '=';
    ConstraintVersion := AConstraint;
  end;

  ConstraintV := ParseSemanticVersion(ConstraintVersion);
  if not ConstraintV.Valid then
    Exit(False);

  Cmp := CompareVersions(AVersion, ConstraintVersion);

  if Op = '=' then
    Result := Cmp = 0
  else if Op = '>' then
    Result := Cmp > 0
  else if Op = '<' then
    Result := Cmp < 0
  else if Op = '>=' then
    Result := Cmp >= 0
  else if Op = '<=' then
    Result := Cmp <= 0
  else if Op = '^' then
    // Compatible version (same major)
    Result := (V.Major = ConstraintV.Major) and (Cmp >= 0)
  else if Op = '~' then
    // Patch version (same major.minor)
    Result := (V.Major = ConstraintV.Major) and (V.Minor = ConstraintV.Minor) and (Cmp >= 0)
  else
    Result := False;
end;

{ Dependency Graph Functions }

function BuildDependencyGraph(const ARootPackage: string; const APackages: TPackageArray): TDependencyNodeArray;
var
  i, j, k, NodeIdx: Integer;
  DepName, DepVersion: string;
  DepParts: TStringArray;
  Visited: TStringList;

  procedure AddPackageAndDeps(const APkgName: string);
  var
    PkgIdx, DepIdx, m: Integer;
    DepNamePart, DepConstraint: string;
    Parts: TStringArray;
  begin
    // Check if already visited
    if Visited.IndexOf(APkgName) >= 0 then
      Exit;
    Visited.Add(APkgName);

    // Find package in available packages
    PkgIdx := -1;
    for m := 0 to High(APackages) do
    begin
      if SameText(APackages[m].Name, APkgName) then
      begin
        PkgIdx := m;
        Break;
      end;
    end;

    if PkgIdx < 0 then
      Exit;  // Package not found

    // Add node to graph
    NodeIdx := Length(Result);
    SetLength(Result, NodeIdx + 1);
    Result[NodeIdx].Name := APackages[PkgIdx].Name;
    Result[NodeIdx].Version := APackages[PkgIdx].Version;
    SetLength(Result[NodeIdx].Dependencies, Length(APackages[PkgIdx].Dependencies));

    // Copy dependencies
    for m := 0 to High(APackages[PkgIdx].Dependencies) do
      Result[NodeIdx].Dependencies[m] := APackages[PkgIdx].Dependencies[m];

    SetLength(Result[NodeIdx].Constraints, 0);
    Result[NodeIdx].Visited := False;
    Result[NodeIdx].InStack := False;

    // Recursively add dependencies
    for DepIdx := 0 to High(APackages[PkgIdx].Dependencies) do
    begin
      // Parse dependency (format: "pkgName:>=1.0.0" or "pkgName")
      Parts := APackages[PkgIdx].Dependencies[DepIdx].Split([':']);
      if Length(Parts) > 0 then
      begin
        DepNamePart := Trim(Parts[0]);
        AddPackageAndDeps(DepNamePart);
      end;
    end;
  end;

begin
  SetLength(Result, 0);
  Visited := TStringList.Create;
  try
    Visited.CaseSensitive := False;
    AddPackageAndDeps(ARootPackage);
  finally
    Visited.Free;
  end;
end;

function TopologicalSortDependencies(const AGraph: TDependencyNodeArray): TStringArray;
var
  InDegree: array of Integer;
  Queue: TStringArray;
  QueueHead, QueueTail: Integer;
  i, j, k, Idx, ProcessedCount: Integer;
  DepName: string;
  DepParts: TStringArray;
begin
  Result := nil;

  if Length(AGraph) = 0 then
    Exit;

  // Calculate in-degree for each node (how many nodes depend on it)
  SetLength(InDegree, Length(AGraph));
  for i := 0 to High(AGraph) do
    InDegree[i] := 0;

  // Count dependencies
  for i := 0 to High(AGraph) do
  begin
    for j := 0 to High(AGraph[i].Dependencies) do
    begin
      // Parse dependency name
      DepParts := AGraph[i].Dependencies[j].Split([':']);
      if Length(DepParts) > 0 then
      begin
        DepName := Trim(DepParts[0]);

        // Find the dependency node and increment its in-degree
        for k := 0 to High(AGraph) do
        begin
          if SameText(AGraph[k].Name, DepName) then
          begin
            Inc(InDegree[k]);
            Break;
          end;
        end;
      end;
    end;
  end;

  // Initialize queue with nodes that have no incoming edges (dependencies)
  SetLength(Queue, Length(AGraph));
  QueueHead := 0;
  QueueTail := 0;

  for i := 0 to High(AGraph) do
  begin
    if InDegree[i] = 0 then
    begin
      Queue[QueueTail] := AGraph[i].Name;
      Inc(QueueTail);
    end;
  end;

  // Process queue (Kahn's algorithm)
  SetLength(Result, Length(AGraph));
  ProcessedCount := 0;

  while QueueHead < QueueTail do
  begin
    // Dequeue
    Result[ProcessedCount] := Queue[QueueHead];
    Idx := -1;
    for i := 0 to High(AGraph) do
    begin
      if SameText(AGraph[i].Name, Queue[QueueHead]) then
      begin
        Idx := i;
        Break;
      end;
    end;
    Inc(QueueHead);
    Inc(ProcessedCount);

    if Idx < 0 then
      Continue;

    // For each node that this node depends on, decrease their in-degree
    for i := 0 to High(AGraph[Idx].Dependencies) do
    begin
      DepParts := AGraph[Idx].Dependencies[i].Split([':']);
      if Length(DepParts) > 0 then
      begin
        DepName := Trim(DepParts[0]);

        // Find the dependency node
        for j := 0 to High(AGraph) do
        begin
          if SameText(AGraph[j].Name, DepName) then
          begin
            Dec(InDegree[j]);
            if InDegree[j] = 0 then
            begin
              Queue[QueueTail] := AGraph[j].Name;
              Inc(QueueTail);
            end;
            Break;
          end;
        end;
      end;
    end;
  end;

  // Trim result to actual count
  SetLength(Result, ProcessedCount);
end;

{ Package Verification Functions Implementation }

function VerifyInstalledPackage(const TestDir: string): TPackageVerificationResult;
var
  MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  FilesArray: TJSONArray;
  i: Integer;
  FilePath: string;
begin
  // Initialize result
  Result.Status := vsInvalid;
  Result.PackageName := '';
  Result.Version := '';
  SetLength(Result.MissingFiles, 0);

  // Check if package.json exists
  MetaPath := IncludeTrailingPathDelimiter(TestDir) + 'package.json';
  if not FileExists(MetaPath) then
  begin
    Result.Status := vsMetadataError;
    Exit;
  end;

  // Read and parse package.json
  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetaPath);
    try
      J := GetJSON(SL.Text);
      if J.JSONType = jtObject then
      begin
        O := TJSONObject(J);
        Result.PackageName := O.Get('name', '');
        Result.Version := O.Get('version', '');

        // Check if all declared files exist
        if O.Find('files') <> nil then
        begin
          FilesArray := O.Arrays['files'];
          for i := 0 to FilesArray.Count - 1 do
          begin
            FilePath := IncludeTrailingPathDelimiter(TestDir) + FilesArray.Strings[i];
            if not FileExists(FilePath) then
            begin
              SetLength(Result.MissingFiles, Length(Result.MissingFiles) + 1);
              Result.MissingFiles[High(Result.MissingFiles)] := FilesArray.Strings[i];
            end;
          end;
        end;

        // Determine status based on validation results
        if (Result.PackageName = '') or (Result.Version = '') then
          Result.Status := vsMetadataError
        else if Length(Result.MissingFiles) > 0 then
          Result.Status := vsMissingFiles
        else
          Result.Status := vsValid;
      end
      else
        Result.Status := vsMetadataError;
      J.Free;
    except
      // JSON parsing error
      Result.Status := vsMetadataError;
    end;
  finally
    SL.Free;
  end;
end;

function VerifyPackageChecksum(const FilePath, Hash: string): Boolean;
var
  ActualHash: string;
begin
  Result := False;
  if not FileExists(FilePath) then
    Exit;

  ActualHash := SHA256FileHex(FilePath);
  Result := SameText(ActualHash, Hash);
end;

{ Package Creation Functions Implementation }

function IsBuildArtifact(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := (Ext = '.o') or (Ext = '.ppu') or (Ext = '.a') or
            (Ext = '.exe') or (Ext = '.dll') or (Ext = '.so') or
            (Ext = '.dylib') or (Ext = '.compiled') or (Ext = '.res') or
            (Ext = '.or') or (Ext = '.dcu') or (Ext = '.bpl') or (Ext = '.dcp');
end;

function CollectPackageSourceFiles(const SourceDir: string; const ExcludePatterns: TStringArray): TStringArray;
var
  Files: TStringList;
  i: Integer;
  Excluded: Boolean;
  j: Integer;
  RelPath: string;

  procedure ScanDirectory(const Dir: string);
  var
    SearchRec: TSearchRec;
    FullPath: string;
    Ext: string;
  begin
    if FindFirst(Dir + PathDelim + '*', faAnyFile, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
          Continue;

        FullPath := Dir + PathDelim + SearchRec.Name;

        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          // Recursively scan subdirectories
          ScanDirectory(FullPath);
        end
        else
        begin
          // Check if it's a source file or documentation
          Ext := LowerCase(ExtractFileExt(SearchRec.Name));
          if (Ext = '.pas') or (Ext = '.pp') or (Ext = '.inc') or (Ext = '.lpr') or (Ext = '.lpi') or (Ext = '.lpk') or
             (Ext = '.md') or (Ext = '.txt') or (Ext = '.rst') or (Ext = '.json') then
          begin
            // Skip build artifacts
            if not IsBuildArtifact(SearchRec.Name) then
              Files.Add(FullPath);
          end;
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;
  end;

begin
  Files := TStringList.Create;
  try
    // Scan directory recursively
    ScanDirectory(SourceDir);

    // Filter out excluded patterns
    SetLength(Result, 0);
    for i := 0 to Files.Count - 1 do
    begin
      RelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(SourceDir), Files[i]);
      Excluded := False;

      // Check against exclude patterns
      for j := 0 to High(ExcludePatterns) do
      begin
        if Pos(ExcludePatterns[j], RelPath) > 0 then
        begin
          Excluded := True;
          Break;
        end;
      end;

      if not Excluded then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Files[i];
      end;
    end;
  finally
    Files.Free;
  end;
end;

function GeneratePackageMetadataJson(const Options: TPackageCreationOptions): string;
begin
  // Manually construct JSON to ensure compact format without spaces
  Result := '{"name":"' + Options.Name + '",' +
            '"version":"' + Options.Version + '",' +
            '"description":"A FreePascal package",' +
            '"author":"",' +
            '"license":"MIT",' +
            '"dependencies":[]}';
end;

function CreatePackageZipArchive(const SourceDir: string; const Files: TStringArray; const OutputPath: string; var Err: string): Boolean;
var
  Archiver: TPackageArchiver;
  i: Integer;
  RelPath: string;
begin
  Result := False;
  Err := '';

  // Ensure output directory exists
  if not DirectoryExists(ExtractFileDir(OutputPath)) then
    EnsureDir(ExtractFileDir(OutputPath));

  // Use TPackageArchiver to create archive
  Archiver := TPackageArchiver.Create(SourceDir);
  try
    if not Archiver.CreateArchive(OutputPath) then
    begin
      Err := Archiver.GetLastError;
      Exit;
    end;
    Result := True;
  finally
    Archiver.Free;
  end;
end;

{ Package Validation Functions Implementation }

function ValidatePackageSourcePath(const SourcePath: string): Boolean;
var
  SearchRec: TSearchRec;
  HasLpk, HasMakefile: Boolean;
begin
  Result := False;

  // Check if directory exists
  if not DirectoryExists(SourcePath) then
    Exit;

  // Check for .lpk or Makefile
  HasLpk := False;
  HasMakefile := False;

  if FindFirst(IncludeTrailingPathDelimiter(SourcePath) + '*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        if LowerCase(ExtractFileExt(SearchRec.Name)) = '.lpk' then
          HasLpk := True;
        if LowerCase(SearchRec.Name) = 'makefile' then
          HasMakefile := True;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  Result := HasLpk or HasMakefile;
end;

function ValidatePackageMetadata(const MetadataPath: string): Boolean;
var
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  Name, Version: string;
begin
  Result := False;

  // Check if file exists
  if not FileExists(MetadataPath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetadataPath);

    // Check if file is empty
    if SL.Text = '' then
      Exit;

    try
      J := GetJSON(SL.Text);
      try
        if J.JSONType = jtObject then
        begin
          O := TJSONObject(J);
          Name := O.Get('name', '');
          Version := O.Get('version', '');

          // Valid if both name and version are non-empty
          Result := (Name <> '') and (Version <> '');
        end;
      finally
        J.Free;
      end;
    except
      // JSON parsing error
      Result := False;
    end;
  finally
    SL.Free;
  end;
end;

function CheckPackageRequiredFiles(const PackageDir: string): TStringArray;
var
  HasPackageJson, HasLpk, HasMakefile: Boolean;
  SearchRec: TSearchRec;
  MissingCount: Integer;
begin
  SetLength(Result, 0);
  MissingCount := 0;

  // Check for package.json
  HasPackageJson := FileExists(IncludeTrailingPathDelimiter(PackageDir) + 'package.json');

  // Check for .lpk or Makefile
  HasLpk := False;
  HasMakefile := False;

  if FindFirst(IncludeTrailingPathDelimiter(PackageDir) + '*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        if LowerCase(ExtractFileExt(SearchRec.Name)) = '.lpk' then
          HasLpk := True;
        if LowerCase(SearchRec.Name) = 'makefile' then
          HasMakefile := True;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  // Add missing files to result
  if not HasPackageJson then
  begin
    SetLength(Result, MissingCount + 1);
    Result[MissingCount] := 'package.json';
    Inc(MissingCount);
  end;

  if not (HasLpk or HasMakefile) then
  begin
    SetLength(Result, MissingCount + 1);
    Result[MissingCount] := '.lpk or Makefile';
    Inc(MissingCount);
  end;
end;

end.
