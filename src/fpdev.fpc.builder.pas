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
  fpdev.utils.process, fpdev.git.types, fpdev.git.runtime, fpdev.resource.repo, fpdev.constants,
  fpdev.build.toolchain, fpdev.fpc.builderflow,
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
    function EnsureResourceRepository: Boolean;
    function HasResourceRepositoryBootstrapCompiler(
      const AVersion, APlatform: string
    ): Boolean;
    function FindBestResourceRepositoryBootstrapVersion(
      const AFPCVersion, APlatform: string
    ): string;
    function InstallBootstrapFromResourceRepository(
      const AVersion, APlatform, ADestDir: string
    ): Boolean;
    function SourceDirectoryExists(const APath: string): Boolean;
    procedure PrepareSourceTree(const ASourceDir: string);
    procedure EnsureInstallDirectoryExists(const APath: string);
    function ResolveBuildPlan(
      const AInstallDir, ABootstrapFPC: string;
      const AParallelJobs: Integer
    ): TFPCBuilderBuildPlan;
    function ExecuteBuildPlan(
      const ABuildPlan: TFPCBuilderBuildPlan;
      const ASourceDir: string
    ): TProcessResult;

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
  fpdev.version.registry, fpdev.fpc.installversionflow,
  fpdev.resource.repo.bootstrap;

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

function TFPCSourceBuilder.EnsureResourceRepository: Boolean;
begin
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

  Result := Assigned(FResourceRepo);
end;

function TFPCSourceBuilder.HasResourceRepositoryBootstrapCompiler(
  const AVersion, APlatform: string
): Boolean;
begin
  Result := Assigned(FResourceRepo) and
    FResourceRepo.HasBootstrapCompiler(AVersion, APlatform);
end;

function TFPCSourceBuilder.FindBestResourceRepositoryBootstrapVersion(
  const AFPCVersion, APlatform: string
): string;
begin
  if Assigned(FResourceRepo) then
    Result := FResourceRepo.FindBestBootstrapVersion(AFPCVersion, APlatform)
  else
    Result := '';
end;

function TFPCSourceBuilder.InstallBootstrapFromResourceRepository(
  const AVersion, APlatform, ADestDir: string
): Boolean;
begin
  Result := Assigned(FResourceRepo) and
    FResourceRepo.InstallBootstrap(AVersion, APlatform, ADestDir);
end;

function TFPCSourceBuilder.SourceDirectoryExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

procedure TFPCSourceBuilder.PrepareSourceTree(const ASourceDir: string);
begin
  FPCBuilderInvalidateCompilerMessageIncludesCore(ASourceDir);
  FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(ASourceDir);
end;

procedure TFPCSourceBuilder.EnsureInstallDirectoryExists(const APath: string);
begin
  if not DirectoryExists(APath) then
    EnsureDir(APath);
end;

function TFPCSourceBuilder.ResolveBuildPlan(
  const AInstallDir, ABootstrapFPC: string;
  const AParallelJobs: Integer
): TFPCBuilderBuildPlan;
var
  BuildPlan: TFPCSourceBuildPlan;
  ToolchainChecker: TBuildToolchainChecker;
  I: Integer;
begin
  ToolchainChecker := TBuildToolchainChecker.Create(False);
  try
    BuildPlan := CreateFPCSourceBuildPlanCore(
      AInstallDir,
      ABootstrapFPC,
      AParallelJobs,
      ToolchainChecker.ResolveMakeCmd,
      {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
    );
  finally
    ToolchainChecker.Free;
  end;

  Result.MakeCommand := BuildPlan.MakeCommand;
  SetLength(Result.Params, Length(BuildPlan.Params));
  for I := 0 to High(BuildPlan.Params) do
    Result.Params[I] := BuildPlan.Params[I];
end;

function TFPCSourceBuilder.ExecuteBuildPlan(
  const ABuildPlan: TFPCBuilderBuildPlan;
  const ASourceDir: string
): TProcessResult;
var
  BuildArgs: TFPCSourceBuildArgs;
  I: Integer;
begin
  BuildArgs := nil;
  SetLength(BuildArgs, Length(ABuildPlan.Params));
  for I := 0 to High(ABuildPlan.Params) do
    BuildArgs[I] := ABuildPlan.Params[I];

  Result := TProcessExecutor.RunDirect(
    ABuildPlan.MakeCommand,
    BuildArgs,
    ASourceDir
  );
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
  BootstrapState: TFPCBuilderBootstrapState;
  BootstrapCallbacks: TFPCBuilderBootstrapCallbacks;
begin
  BootstrapState := Default(TFPCBuilderBootstrapState);
  BootstrapCallbacks := Default(TFPCBuilderBootstrapCallbacks);
  BootstrapState.TargetVersion := ATargetVersion;
  BootstrapState.Platform := GetCurrentPlatform;

  BootstrapCallbacks.GetRequiredBootstrapVersion := @GetRequiredBootstrapVersion;
  BootstrapCallbacks.GetCurrentCompilerVersion := @GetCurrentFPCVersion;
  BootstrapCallbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
  BootstrapCallbacks.TryResolveInstalledBootstrapCompiler := @TryResolveInstalledBootstrapCompiler;
  BootstrapCallbacks.IsBootstrapAvailable := @IsBootstrapAvailable;
  BootstrapCallbacks.GetBootstrapCompilerPath := @GetBootstrapCompilerPath;
  BootstrapCallbacks.EnsureResourceRepository := @EnsureResourceRepository;
  BootstrapCallbacks.HasResourceRepositoryBootstrapCompiler := @HasResourceRepositoryBootstrapCompiler;
  BootstrapCallbacks.FindBestResourceRepositoryBootstrapVersion := @FindBestResourceRepositoryBootstrapVersion;
  BootstrapCallbacks.InstallBootstrapFromResourceRepository := @InstallBootstrapFromResourceRepository;

  Result := ExecuteFPCBuilderEnsureBootstrapCore(
    BootstrapState,
    FOut,
    FErr,
    BootstrapCallbacks
  );
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

    Git := NewGitRuntime;
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

          // Fetch updates and checkout the requested tag via the unified git runtime.
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
  BuildState: TFPCBuilderBuildState;
  BuildCallbacks: TFPCBuilderBuildCallbacks;
  Settings: TFPDevSettings;
begin
  Settings := FConfigManager.GetSettingsManager.GetSettings;
  BuildState := Default(TFPCBuilderBuildState);
  BuildCallbacks := Default(TFPCBuilderBuildCallbacks);
  BuildState.SourceDir := ASourceDir;
  BuildState.InstallDir := AInstallDir;
  BuildState.TargetVersion := ResolveFPCSourceBuildTargetVersion(ASourceDir, AInstallDir);
  BuildState.ParallelJobs := Settings.ParallelJobs;

  BuildCallbacks.SourceDirectoryExists := @SourceDirectoryExists;
  BuildCallbacks.PrepareSourceTree := @PrepareSourceTree;
  BuildCallbacks.EnsureInstallDirectory := @EnsureInstallDirectoryExists;
  BuildCallbacks.GetRequiredBootstrapVersion := @GetRequiredBootstrapVersion;
  BuildCallbacks.GetCurrentCompilerVersion := @GetCurrentFPCVersion;
  BuildCallbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
  BuildCallbacks.TryResolveInstalledBootstrapCompiler := @TryResolveInstalledBootstrapCompiler;
  BuildCallbacks.ResolveBuildPlan := @ResolveBuildPlan;
  BuildCallbacks.ExecuteBuildPlan := @ExecuteBuildPlan;

  try
    Result := ExecuteFPCBuilderBuildFromSourceCore(BuildState, FOut, FErr, BuildCallbacks);
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
