unit fpdev.fpc.builder;

{
================================================================================
  fpdev.fpc.builder - FPC Source Builder Service
================================================================================

  Provides FPC source code download and compilation capabilities:
  - Download FPC source from GitLab
  - Manage bootstrap compilers
  - Build FPC from source
  - Handle build dependencies

  This service is extracted from TFPCManager as part of the Facade pattern
  refactoring to reduce god class complexity.

  Usage:
    Builder := TFPCSourceBuilder.Create(ConfigManager);
    try
      if Builder.EnsureBootstrapCompiler('3.2.2') then
        if Builder.DownloadSource('3.2.2', SourceDir) then
          if Builder.BuildFromSource(SourceDir, InstallDir) then
            WriteLn('Build complete');
    finally
      Builder.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs,
  fpdev.utils.process, fpdev.utils.git, fpdev.git.runtime, fpdev.resource.repo, fpdev.constants,
  fpdev.build.toolchain,
  fpdev.fpc.types, fpdev.config, fpdev.paths;

type
  TFPCSourceBuildArgs = array of string;

  TFPCSourceBuildPlan = record
    MakeCommand: string;
    Params: TFPCSourceBuildArgs;
  end;

  { Bootstrap compiler requirements }
  TBootstrapRequirement = record
    TargetVersion: string;
    RequiredVersion: string;
  end;

  { TFPCBuilder is now in fpdev.fpc.builder.di unit for testability }
  { Re-exported for backward compatibility }

  { TFPCSourceBuilder - FPC source compilation service }
  TFPCSourceBuilder = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;
    FOut: IOutput;
    FErr: IOutput;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;
    function GetCompilerVersion(const AExecutable: string): string;
    function TryResolveInstalledBootstrapCompiler(
      const ATargetVersion, ARequiredVersion: string;
      out AResolvedVersion, AResolvedCompiler: string
    ): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager;
      AOut: IOutput = nil; AErr: IOutput = nil);
    destructor Destroy; override;

    { Gets the current FPC version from system PATH. }
    function GetCurrentFPCVersion: string;

    { Gets path to bootstrap compiler for a version. }
    function GetBootstrapCompilerPath(const AVersion: string): string;

    { Checks if bootstrap compiler is locally available. }
    function IsBootstrapAvailable(const AVersion: string): Boolean;

    { Gets the required bootstrap compiler version for building a target version.
      ATargetVersion: FPC version to build
      Returns: Required bootstrap version or empty string if none required }
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;

    { Ensures a bootstrap compiler is available for building the target version.
      Downloads from fpdev-repo if needed.
      ATargetVersion: FPC version to build
      Returns: True if bootstrap compiler is available }
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

    { Downloads FPC source code from GitLab.
      AVersion: FPC version to download
      ATargetDir: Directory to clone to
      Returns: True if download succeeded }
    function DownloadSource(const AVersion, ATargetDir: string): Boolean;

    { Builds FPC from source code.
      ASourceDir: Directory containing FPC source
      AInstallDir: Installation destination
      Returns: True if build succeeded }
    function BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;

    { Resource repository accessor for external coordination. }
    property ResourceRepo: TResourceRepository read FResourceRepo;
  end;

function FPCBuilderCanUseSystemCompilerAsBootstrapCore(
  const ATargetVersion, ACurrentVersion, ARequiredVersion: string
): Boolean;
function CreateFPCSourceBuildPlanCore(
  const AInstallDir, ABootstrapFPC: string;
  const AParallelJobs: Integer;
  const AMakeCommand: string;
  const AIsWindows: Boolean
): TFPCSourceBuildPlan;
procedure FPCBuilderInvalidateCompilerMessageIncludesCore(const ASourceDir: string);
procedure FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(const ASourceDir: string);

const
  { Bootstrap compiler requirements for building from source }
  DEFAULT_BOOTSTRAP_VERSION = '3.2.2';
  FPC_BOOTSTRAP_REQUIREMENTS: array[0..2] of TBootstrapRequirement = (
    (TargetVersion: '3.2.2'; RequiredVersion: '3.2.0'),
    (TargetVersion: '3.2.0'; RequiredVersion: '3.0.4'),
    (TargetVersion: '3.0.4'; RequiredVersion: '3.0.2')
  );

implementation

uses
  fpdev.i18n, fpdev.i18n.strings, fpdev.output.console,
  fpdev.version.registry, fpdev.fpc.installversionflow, fpdev.resource.repo.bootstrap;

{ TFPCSourceBuilder }

constructor TFPCSourceBuilder.Create(AConfigManager: IConfigManager;
  AOut: IOutput; AErr: IOutput);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := nil;

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
    FInstallRoot := GetDataRoot;
end;

destructor TFPCSourceBuilder.Destroy;
begin
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function LooksLikeSemVer(const AVersion: string): Boolean;
var
  DotCount: Integer;
begin
  DotCount := Length(AVersion) - Length(StringReplace(AVersion, '.', '', [rfReplaceAll]));
  Result := DotCount >= 1;
end;

function ResolveFPCSourceBuildTargetVersion(const ASourceDir, AInstallDir: string): string;
var
  SourceLeaf: string;
  InstallLeaf: string;
begin
  SourceLeaf := ExtractFileName(ExcludeTrailingPathDelimiter(Trim(ASourceDir)));
  if Pos('fpc-', LowerCase(SourceLeaf)) = 1 then
    Exit(Copy(SourceLeaf, 5, MaxInt));

  InstallLeaf := ExtractFileName(ExcludeTrailingPathDelimiter(Trim(AInstallDir)));
  if Pos('fpc-', LowerCase(InstallLeaf)) = 1 then
    Exit(Copy(InstallLeaf, 5, MaxInt));

  Result := InstallLeaf;
end;

function FPCBuilderCanUseSystemCompilerAsBootstrapCore(
  const ATargetVersion, ACurrentVersion, ARequiredVersion: string
): Boolean;
begin
  Result := False;

  if Trim(ACurrentVersion) = '' then
    Exit;

  if LooksLikeSemVer(ATargetVersion) and SameMajorMinor(ACurrentVersion, ATargetVersion) then
    Exit(True);

  if (Trim(ARequiredVersion) <> '') and
     SameMajorMinor(ACurrentVersion, ARequiredVersion) and
     (CompareSemVer(ACurrentVersion, ARequiredVersion) >= 0) then
    Exit(True);
end;

function CreateFPCSourceBuildPlanCore(
  const AInstallDir, ABootstrapFPC: string;
  const AParallelJobs: Integer;
  const AMakeCommand: string;
  const AIsWindows: Boolean
): TFPCSourceBuildPlan;
var
  EffectiveJobs: Integer;
  ParamIndex: Integer;
begin
  Result := Default(TFPCSourceBuildPlan);
  if Trim(AMakeCommand) <> '' then
    Result.MakeCommand := AMakeCommand
  else
    Result.MakeCommand := 'make';

  EffectiveJobs := AParallelJobs;
  if EffectiveJobs <= 0 then
    EffectiveJobs := 1;

  SetLength(Result.Params, 5);
  if Trim(ABootstrapFPC) <> '' then
    SetLength(Result.Params, Length(Result.Params) + 1);
  if not AIsWindows then
    SetLength(Result.Params, Length(Result.Params) + 1);

  ParamIndex := 0;
  Result.Params[ParamIndex] := 'all';
  Inc(ParamIndex);
  Result.Params[ParamIndex] := 'install';
  Inc(ParamIndex);
  Result.Params[ParamIndex] := 'PREFIX=' + AInstallDir;
  Inc(ParamIndex);
  if Trim(ABootstrapFPC) <> '' then
  begin
    Result.Params[ParamIndex] := 'PP=' + ABootstrapFPC;
    Inc(ParamIndex);
  end;
  Result.Params[ParamIndex] := 'OVERRIDEVERSIONCHECK=1';
  Inc(ParamIndex);
  if not AIsWindows then
  begin
    Result.Params[ParamIndex] := 'GINSTALL=/usr/bin/install';
    Inc(ParamIndex);
  end;
  Result.Params[ParamIndex] := '-j' + IntToStr(EffectiveJobs);
end;

procedure FPCBuilderInvalidateCompilerMessageIncludesCore(const ASourceDir: string);
var
  CompilerDir: string;
  MsgDir: string;
  MsgIdxPath: string;
  MsgTxtPath: string;
begin
  CompilerDir := IncludeTrailingPathDelimiter(ASourceDir) + 'compiler';
  MsgDir := CompilerDir + PathDelim + 'msg';
  if not DirectoryExists(MsgDir) then
    Exit;

  MsgIdxPath := CompilerDir + PathDelim + 'msgidx.inc';
  MsgTxtPath := CompilerDir + PathDelim + 'msgtxt.inc';

  if FileExists(MsgIdxPath) then
    DeleteFile(MsgIdxPath);
  if FileExists(MsgTxtPath) then
    DeleteFile(MsgTxtPath);
end;

procedure FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(const ASourceDir: string);
var
  FPMakePath: string;
  JWTSourceDir: string;
  JWTUnitPath: string;
  BaseJWTUnitPath: string;
  UnitsRoot: string;
  FPMakeLines: TStringList;
  Search: TSearchRec;
  UnitsSearch: TSearchRec;
  BaseIndex: Integer;
  JwtIndex: Integer;
  TargetIndex: Integer;
  BaseLine: string;
  JwtLine: string;
  UnitsDir: string;
begin
  JWTSourceDir := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'src' + PathDelim + 'jwt';
  if not DirectoryExists(JWTSourceDir) then
    Exit;
  JWTUnitPath := JWTSourceDir + PathDelim + 'fpjwt.pp';
  BaseJWTUnitPath := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'src' + PathDelim + 'base' + PathDelim + 'fpjwt.pp';

  FPMakePath := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'fpmake.pp';
  if FileExists(FPMakePath) then
  begin
    FPMakeLines := TStringList.Create;
    try
      FPMakeLines.LoadFromFile(FPMakePath);
      BaseIndex := FPMakeLines.IndexOf('    P.SourcePath.Add(''src/base'');');
      JwtIndex := FPMakeLines.IndexOf('    P.SourcePath.Add(''src/jwt'');');
      TargetIndex := FPMakeLines.IndexOf('    T:=P.Targets.AddUnit(''fpjwt.pp'');');
      if (BaseIndex >= 0) and (JwtIndex < 0) then
      begin
        FPMakeLines.Insert(BaseIndex, '    P.SourcePath.Add(''src/jwt'');');
        JwtIndex := BaseIndex;
        Inc(BaseIndex);
      end;
      if (BaseIndex >= 0) and (JwtIndex >= 0) and (BaseIndex < JwtIndex) then
      begin
        BaseLine := FPMakeLines[BaseIndex];
        JwtLine := FPMakeLines[JwtIndex];
        FPMakeLines[BaseIndex] := JwtLine;
        FPMakeLines[JwtIndex] := BaseLine;
      end;
      if TargetIndex >= 0 then
        FPMakeLines[TargetIndex] := '    T:=P.Targets.AddUnit(''src/jwt/fpjwt.pp'');';
      FPMakeLines.SaveToFile(FPMakePath);
    finally
      FPMakeLines.Free;
    end;
  end;

  if FileExists(JWTUnitPath) and FileExists(BaseJWTUnitPath) then
    CopyFileSafe(JWTUnitPath, BaseJWTUnitPath);

  UnitsRoot := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'units';
  if FindFirst(UnitsRoot + PathDelim + '*', faDirectory, Search) = 0 then
  begin
    repeat
      if (Search.Name <> '.') and (Search.Name <> '..') and
         ((Search.Attr and faDirectory) <> 0) then
      begin
        UnitsDir := UnitsRoot + PathDelim + Search.Name;
        if FindFirst(UnitsDir + PathDelim + 'fpjwt.*', faAnyFile, UnitsSearch) = 0 then
        begin
          repeat
            if (UnitsSearch.Name <> '.') and (UnitsSearch.Name <> '..') and
               ((UnitsSearch.Attr and faDirectory) = 0) then
              DeleteFile(UnitsDir + PathDelim + UnitsSearch.Name);
          until FindNext(UnitsSearch) <> 0;
          FindClose(UnitsSearch);
        end;
        if FileExists(UnitsDir + PathDelim + 'BuildUnit_fcl_web.pp') then
          DeleteFile(UnitsDir + PathDelim + 'BuildUnit_fcl_web.pp');
      end;
    until FindNext(Search) <> 0;
    FindClose(Search);
  end;
end;

function TFPCSourceBuilder.GetVersionInstallPath(const AVersion: string): string;
begin
  Result := BuildFPCInstallDirFromInstallRoot(FInstallRoot, AVersion);
end;

function TFPCSourceBuilder.GetCompilerVersion(const AExecutable: string): string;
var
  LResult: fpdev.utils.process.TProcessResult;
begin
  Result := '';
  if Trim(AExecutable) = '' then
    Exit;

  try
    LResult := TProcessExecutor.Execute(AExecutable, ['-iV'], '');
    if LResult.Success then
      Result := Trim(LResult.StdOut);
  except
    Result := '';
  end;
end;

function TFPCSourceBuilder.TryResolveInstalledBootstrapCompiler(
  const ATargetVersion, ARequiredVersion: string;
  out AResolvedVersion, AResolvedCompiler: string
): Boolean;
var
  CandidateVersion: string;
  CandidateCompiler: string;
  ReportedVersion: string;
begin
  Result := False;
  AResolvedVersion := '';
  AResolvedCompiler := '';

  if Trim(ATargetVersion) <> '' then
  begin
    CandidateVersion := ATargetVersion;
    CandidateCompiler := BuildFPCInstalledExecutablePathCore(GetVersionInstallPath(CandidateVersion));
    if FileExists(CandidateCompiler) then
    begin
      ReportedVersion := GetCompilerVersion(CandidateCompiler);
      if FPCBuilderCanUseSystemCompilerAsBootstrapCore(ATargetVersion,
        ReportedVersion, ARequiredVersion) then
      begin
        AResolvedVersion := ReportedVersion;
        AResolvedCompiler := CandidateCompiler;
        Exit(True);
      end;
    end;
  end;

  if (Trim(ARequiredVersion) <> '') and
     (not SameText(ARequiredVersion, ATargetVersion)) then
  begin
    CandidateVersion := ARequiredVersion;
    CandidateCompiler := BuildFPCInstalledExecutablePathCore(GetVersionInstallPath(CandidateVersion));
    if FileExists(CandidateCompiler) then
    begin
      ReportedVersion := GetCompilerVersion(CandidateCompiler);
      if FPCBuilderCanUseSystemCompilerAsBootstrapCore(ATargetVersion,
        ReportedVersion, ARequiredVersion) then
      begin
        AResolvedVersion := ReportedVersion;
        AResolvedCompiler := CandidateCompiler;
        Exit(True);
      end;
    end;
  end;
end;

function TFPCSourceBuilder.GetCurrentFPCVersion: string;
begin
  Result := GetCompilerVersion('fpc');
end;

function TFPCSourceBuilder.GetBootstrapCompilerPath(const AVersion: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataRoot) + 'bootstrap' +
    PathDelim + 'fpc-' + AVersion + PathDelim + 'bin' + PathDelim;
  {$IFDEF MSWINDOWS}
  Result := Result + 'fpc.exe';
  {$ELSE}
  Result := Result + 'fpc';
  {$ENDIF}
end;

function TFPCSourceBuilder.IsBootstrapAvailable(const AVersion: string): Boolean;
var
  BootstrapPath: string;
begin
  BootstrapPath := GetBootstrapCompilerPath(AVersion);
  Result := FileExists(BootstrapPath);
end;

function TFPCSourceBuilder.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
var
  DownloadedSourceDir: string;
  MakefileRequiredVersion: string;
  i: Integer;
begin
  Result := '';

  DownloadedSourceDir := BuildFPCSourceInstallPathCore(FInstallRoot, ATargetVersion);
  if DirectoryExists(DownloadedSourceDir) then
  begin
    MakefileRequiredVersion := ResourceRepoGetBootstrapVersionFromMakefile(DownloadedSourceDir);
    if MakefileRequiredVersion <> '' then
    begin
      Result := MakefileRequiredVersion;
      Exit;
    end;
  end;

  // First try to use resource repository
  if not Assigned(FResourceRepo) then
  begin
    FResourceRepo := TResourceRepository.Create(CreateDefaultConfig);
    if DirectoryExists(CreateDefaultConfig.LocalPath) then
      FResourceRepo.LoadManifest;
  end;

  if Assigned(FResourceRepo) then
  begin
    Result := FResourceRepo.GetRequiredBootstrapVersion(ATargetVersion);
    if Result <> '' then
      Exit;
  end;

  // Fallback to hardcoded requirements
  for i := 0 to High(FPC_BOOTSTRAP_REQUIREMENTS) do
  begin
    if SameText(FPC_BOOTSTRAP_REQUIREMENTS[i].TargetVersion, ATargetVersion) then
    begin
      Result := FPC_BOOTSTRAP_REQUIREMENTS[i].RequiredVersion;
      Break;
    end;
  end;
end;

function TFPCSourceBuilder.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
var
  RequiredVersion: string;
  BestVersion: string;
  CurrentVersion: string;
  BootstrapPath: string;
  InstalledBootstrapVersion: string;
  InstalledBootstrapExe: string;
  Platform: string;
begin
  Result := False;
  Platform := GetCurrentPlatform;

  RequiredVersion := GetRequiredBootstrapVersion(ATargetVersion);
  if RequiredVersion = '' then
  begin
    FOut.WriteLn('Note: No specific bootstrap compiler required for ' + ATargetVersion);
    Result := True;
    Exit;
  end;

  FOut.WriteLn('Target FPC version ' + ATargetVersion + ' requires bootstrap compiler ' + RequiredVersion);

  // Check if current system FPC is available and sufficient
  CurrentVersion := GetCurrentFPCVersion;
  if CurrentVersion <> '' then
  begin
    FOut.WriteLn('Current system FPC version: ' + CurrentVersion);

    if FPCBuilderCanUseSystemCompilerAsBootstrapCore(ATargetVersion, CurrentVersion, RequiredVersion) then
    begin
      FOut.WriteLn('OK: System FPC version ' + CurrentVersion + ' is bootstrap-compatible');
      Result := True;
      Exit;
    end
    else
      FOut.WriteLn(
        'System FPC version ' + CurrentVersion +
        ' is not bootstrap-compatible with target ' + ATargetVersion
      );
  end
  else
    FOut.WriteLn('No system FPC compiler found');

  if TryResolveInstalledBootstrapCompiler(ATargetVersion, RequiredVersion,
    InstalledBootstrapVersion, InstalledBootstrapExe) then
  begin
    FOut.WriteLn('OK: Installed bootstrap compiler available at: ' + InstalledBootstrapExe);
    Result := True;
    Exit;
  end;

  // Check if we have the bootstrap compiler downloaded
  if IsBootstrapAvailable(RequiredVersion) then
  begin
    BootstrapPath := GetBootstrapCompilerPath(RequiredVersion);
    FOut.WriteLn('OK: Bootstrap compiler available at: ' + BootstrapPath);
    Result := True;
    Exit;
  end;

  // Try to download from resource repository
  FOut.WriteLn('Bootstrap compiler ' + RequiredVersion + ' not found locally');
  FOut.WriteLn('Attempting to download from resource repository...');
  FOut.WriteLn;

  if not Assigned(FResourceRepo) then
  begin
    FResourceRepo := TResourceRepository.Create(CreateDefaultConfig);
    if not FResourceRepo.Initialize then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_REPO_INIT_FAILED));
      FResourceRepo.Free;
      FResourceRepo := nil;
    end;
  end;

  if Assigned(FResourceRepo) then
  begin
    if FResourceRepo.HasBootstrapCompiler(RequiredVersion, Platform) then
    begin
      FOut.WriteLn('OK: Bootstrap compiler ' + RequiredVersion + ' found in resource repository');
      BootstrapPath := GetBootstrapCompilerPath(RequiredVersion);

      if FResourceRepo.InstallBootstrap(RequiredVersion, Platform, ExtractFileDir(BootstrapPath)) then
      begin
        FOut.WriteLn('OK: Bootstrap compiler downloaded and installed successfully');
        FOut.WriteLn('  Location: ' + BootstrapPath);
        Result := True;
        Exit;
      end
      else
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BOOTSTRAP_INSTALL_FAILED, ['from repository']));
    end
    else
    begin
      FOut.WriteLn('Exact version ' + RequiredVersion + ' not available, searching for alternatives...');
      BestVersion := FResourceRepo.FindBestBootstrapVersion(ATargetVersion, Platform);

      if BestVersion <> '' then
      begin
        FOut.WriteLn('OK: Found alternative bootstrap compiler: ' + BestVersion);
        BootstrapPath := GetBootstrapCompilerPath(BestVersion);

        if FResourceRepo.InstallBootstrap(BestVersion, Platform, ExtractFileDir(BootstrapPath)) then
        begin
          FOut.WriteLn('OK: Bootstrap compiler ' + BestVersion + ' installed successfully');
          FOut.WriteLn('  Location: ' + BootstrapPath);
          Result := True;
          Exit;
        end
        else
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BOOTSTRAP_INSTALL_FAILED, [BestVersion]));
      end
      else
        FErr.WriteLn('No bootstrap compiler available for platform ' + Platform);
    end;
  end;

  // All methods failed - show manual instructions
  FErr.WriteLn;
  FErr.WriteLn('Unable to automatically download bootstrap compiler.');
  FErr.WriteLn('To build FPC ' + ATargetVersion + ' from source, you need FPC ' + RequiredVersion);
  FErr.WriteLn;
  FErr.WriteLn('Options:');
  FErr.WriteLn('  1. Install FPC ' + RequiredVersion + ' system-wide');
  FErr.WriteLn('  2. Contact maintainer to add bootstrap compiler to resource repository');
  FErr.WriteLn('  3. Use binary installation instead of source build');
  FErr.WriteLn;

  Result := False;
end;

function TFPCSourceBuilder.DownloadSource(const AVersion, ATargetDir: string): Boolean;
var
  Git: IGitRuntime;
  GitTag: string;
begin
  Result := False;

  // Find Git tag for version using registry
  GitTag := TVersionRegistry.Instance.GetFPCGitTag(AVersion);

  if GitTag = '' then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_UNKNOWN_VERSION, [AVersion]));
    Exit;
  end;

  try
    FOut.WriteLn(_Fmt(CMD_FPC_INSTALL_DOWNLOADING, [AVersion]) + ' (tag: ' + GitTag + ')...');

    // Ensure parent directory exists
    if not DirectoryExists(ExtractFileDir(ATargetDir)) then
      EnsureDir(ExtractFileDir(ATargetDir));

    Git := TGitRuntime.Create;
    try
      if Git.Backend = gbNone then
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_NO_GIT_BACKEND));
        Exit;
      end;

      FOut.WriteLn('Using backend: ' + GitBackendToString(Git.Backend));

      // Check if directory already exists
      if DirectoryExists(ATargetDir) then
      begin
        // Directory exists - check if it's a git repo and update it
        if DirectoryExists(ATargetDir + PathDelim + '.git') then
        begin
          FOut.WriteLn('Source directory exists, updating to tag: ' + GitTag);

          // Fetch updates and checkout the requested tag (libgit2-first, CLI fallback inside TGitOperations)
          if not Git.Fetch(ATargetDir, 'origin') then
          begin
            FErr.WriteLn(_(MSG_ERROR) + ': Git fetch failed: ' + Git.LastError);
            Exit;
          end;

          if not Git.Checkout(ATargetDir, GitTag, True) then
          begin
            FErr.WriteLn(_(MSG_ERROR) + ': Git checkout failed for tag: ' + GitTag);
            FErr.WriteLn('  ' + Git.LastError);
            Exit;
          end;

          FOut.WriteLn('Git checkout completed successfully');
          Result := True;
        end
        else
        begin
          // Directory exists but is not a git repo - remove and clone fresh
          FOut.WriteLn('Directory exists but is not a git repo, removing...');
          DeleteDirRecursive(ATargetDir);
          FOut.WriteLn('Cloning: ' + FPC_OFFICIAL_REPO + ' -> ' + ATargetDir);
          Result := Git.Clone(FPC_OFFICIAL_REPO, ATargetDir, GitTag);
          if not Result then
            FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_CLONE_FAILED, [Git.LastError]))
          else
            FOut.WriteLn('Git clone completed successfully');
        end;
      end
      else
      begin
        // Directory doesn't exist - clone fresh
        FOut.WriteLn('Cloning: ' + FPC_OFFICIAL_REPO + ' -> ' + ATargetDir);
        Result := Git.Clone(FPC_OFFICIAL_REPO, ATargetDir, GitTag);
        if not Result then
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_CLONE_FAILED, [Git.LastError]))
        else
          FOut.WriteLn('Git clone completed successfully');
      end;

    finally
      Git := nil;
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': DownloadSource failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCSourceBuilder.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
var
  LResult: fpdev.utils.process.TProcessResult;
  Settings: TFPDevSettings;
  BootstrapFPC: string;
  CurrentFPC: string;
  InstalledBootstrapVersion: string;
  RequiredBootstrapVersion: string;
  TargetVersion: string;
  BuildPlan: TFPCSourceBuildPlan;
  ToolchainChecker: TBuildToolchainChecker;
  ParamIndex: Integer;
begin
  Result := False;

  if not DirectoryExists(ASourceDir) then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [ASourceDir]));
    Exit;
  end;

  try
    FOut.WriteLn('Building FPC from source...');
    FOut.WriteLn('Source directory: ' + ASourceDir);
    FOut.WriteLn('Install directory: ' + AInstallDir);

    // `msgtxt.inc` / `msgidx.inc` are generated files and can be stale in
    // source checkouts; force make to regenerate them for the current tree.
    FPCBuilderInvalidateCompilerMessageIncludesCore(ASourceDir);
    // `fcl-web` in stable branches can pick up a stale/wrong `fpjwt.ppu`.
    // Keep the JWT source path first and drop the cached unit before rebuilding.
    FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(ASourceDir);

    if not DirectoryExists(AInstallDir) then
      EnsureDir(AInstallDir);

    Settings := FConfigManager.GetSettingsManager.GetSettings;
    TargetVersion := ResolveFPCSourceBuildTargetVersion(ASourceDir, AInstallDir);

    RequiredBootstrapVersion := GetRequiredBootstrapVersion(TargetVersion);
    BootstrapFPC := '';
    InstalledBootstrapVersion := '';
    if TryResolveInstalledBootstrapCompiler(TargetVersion, RequiredBootstrapVersion,
      InstalledBootstrapVersion, BootstrapFPC) then
    begin
      FOut.WriteLn('Using installed FPC ' + InstalledBootstrapVersion + ' as bootstrap compiler');
      FOut.WriteLn('Bootstrap compiler: ' + BootstrapFPC);
    end
    else
    begin
      CurrentFPC := GetCurrentFPCVersion;
      if FPCBuilderCanUseSystemCompilerAsBootstrapCore(TargetVersion, CurrentFPC, RequiredBootstrapVersion) then
      begin
        FOut.WriteLn('Using system FPC ' + CurrentFPC + ' as bootstrap compiler');
        BootstrapFPC := 'fpc';
      end
      else if CurrentFPC <> '' then
      begin
        FErr.WriteLn('Warning: System FPC ' + CurrentFPC + ' is not bootstrap-compatible with target ' + TargetVersion);
        FErr.WriteLn('Build will likely fail without a compatible bootstrap compiler');
        BootstrapFPC := '';
      end
      else
      begin
        FErr.WriteLn('Warning: No FPC compiler found');
        FErr.WriteLn('Build will likely fail without a bootstrap compiler');
        BootstrapFPC := '';
      end;
    end;

    ToolchainChecker := TBuildToolchainChecker.Create(False);
    try
      BuildPlan := CreateFPCSourceBuildPlanCore(
        AInstallDir,
        BootstrapFPC,
        Settings.ParallelJobs,
        ToolchainChecker.ResolveMakeCmd,
        {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
      );
    finally
      ToolchainChecker.Free;
    end;

    FOut.Write('Executing: ' + BuildPlan.MakeCommand);
    for ParamIndex := 0 to High(BuildPlan.Params) do
      FOut.Write(' ' + BuildPlan.Params[ParamIndex]);
    FOut.WriteLn;

    LResult := TProcessExecutor.RunDirect(BuildPlan.MakeCommand, BuildPlan.Params, ASourceDir);

    Result := LResult.Success;
    if not Result then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BUILD_FAILED, [LResult.ExitCode]));
      FErr.WriteLn;
      FErr.WriteLn('Common causes:');
      FErr.WriteLn('  1. Wrong bootstrap compiler version (FPC builds require specific FPC versions)');
      FErr.WriteLn('  2. Missing build dependencies (make, binutils, etc.)');
      FErr.WriteLn;
      FErr.WriteLn('To diagnose the issue, try running manually:');
      FErr.WriteLn('  cd ' + ASourceDir);
      FErr.WriteLn('  make all');
      FErr.WriteLn;
      FErr.WriteLn('Note: Building from source requires a compatible bootstrap FPC compiler.');
      FErr.WriteLn('      Consider using binary installation if available.');
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': BuildFromSource failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

{ TFPCBuilder has been moved to fpdev.fpc.builder.di unit }

end.
