unit fpdev.fpc.builder.bootstrapresolveflow;

{
================================================================================
  fpdev.fpc.builder.bootstrapresolveflow - Bootstrap compiler resolution flow
================================================================================

  Standalone flow for resolving and validating bootstrap compiler
  requirements when building FPC from source.

  Extracted from TFPCSourceBuilder as part of the facade/flow refactoring.

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.fpc.types, fpdev.resource.repo;

type
  { Callback bundle for bootstrap resolution against a live manager }
  TFPCBuilderBootstrapResolveCallbacks = record
    GetVersionInstallPath: function(const AVersion: string): string of object;
    GetCompilerVersion: function(const AExecutable: string): string of object;
    GetResourceRepoRequiredBootstrapVersion: function(const AFPCVersion: string): string of object;
  end;

{ Checks if the system/compiler version can serve as bootstrap for the target.
  ATargetVersion: FPC version being built
  ACurrentVersion: Currently installed compiler version
  ARequiredVersion: Minimum bootstrap version required }
function FPCBuilderCanUseSystemCompilerAsBootstrapCore(
  const ATargetVersion, ACurrentVersion, ARequiredVersion: string
): Boolean;

{ Resolves an installed bootstrap compiler matching the target/required version.
  Callbacks provide path resolution and compiler version querying. }
function TryResolveInstalledBootstrapCompilerCore(
  const ATargetVersion, ARequiredVersion: string;
  const ACallbacks: TFPCBuilderBootstrapResolveCallbacks;
  out AResolvedVersion, AResolvedCompiler: string
): Boolean;

{ Determines the required bootstrap version for building the target FPC version.
  Checks Makefile first, then resource repository, then hardcoded fallback table.
  AInstallRoot: Installation root for finding source directories
  AResourceRepo: Optional pre-existing resource repository (may be nil)
  ACallbacks: Callback bundle for path resolution }
function GetRequiredBootstrapVersionCore(
  const ATargetVersion, AInstallRoot: string;
  var AResourceRepo: TResourceRepository;
  const ACallbacks: TFPCBuilderBootstrapResolveCallbacks
): string;

implementation

uses
  fpdev.fpc.installversionflow, fpdev.resource.repo.bootstrap,
  fpdev.resource.repo.config;

type
  { Local copy of bootstrap requirements for standalone flow }
  TLocalBootstrapRequirement = record
    TargetVersion: string;
    RequiredVersion: string;
  end;

const
  LOCAL_FPC_BOOTSTRAP_REQUIREMENTS: array[0..2] of TLocalBootstrapRequirement = (
    (TargetVersion: '3.2.2'; RequiredVersion: '3.2.0'),
    (TargetVersion: '3.2.0'; RequiredVersion: '3.0.4'),
    (TargetVersion: '3.0.4'; RequiredVersion: '3.0.2')
  );

function LooksLikeSemVer(const AVersion: string): Boolean;
var
  DotCount: Integer;
begin
  DotCount := Length(AVersion) - Length(StringReplace(AVersion, '.', '', [rfReplaceAll]));
  Result := DotCount >= 1;
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

function TryResolveInstalledBootstrapCompilerCore(
  const ATargetVersion, ARequiredVersion: string;
  const ACallbacks: TFPCBuilderBootstrapResolveCallbacks;
  out AResolvedVersion, AResolvedCompiler: string
): Boolean;
var
  CandidateVersion: string;
  CandidateCompiler: string;
  ReportedVersion: string;
  InstallPath: string;
begin
  Result := False;
  AResolvedVersion := '';
  AResolvedCompiler := '';

  if Trim(ATargetVersion) <> '' then
  begin
    CandidateVersion := ATargetVersion;
    if Assigned(ACallbacks.GetVersionInstallPath) then
      InstallPath := ACallbacks.GetVersionInstallPath(CandidateVersion)
    else
      InstallPath := '';
    CandidateCompiler := BuildFPCInstalledExecutablePathCore(InstallPath);
    if FileExists(CandidateCompiler) then
    begin
      if Assigned(ACallbacks.GetCompilerVersion) then
        ReportedVersion := ACallbacks.GetCompilerVersion(CandidateCompiler)
      else
        ReportedVersion := '';
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
    if Assigned(ACallbacks.GetVersionInstallPath) then
      InstallPath := ACallbacks.GetVersionInstallPath(CandidateVersion)
    else
      InstallPath := '';
    CandidateCompiler := BuildFPCInstalledExecutablePathCore(InstallPath);
    if FileExists(CandidateCompiler) then
    begin
      if Assigned(ACallbacks.GetCompilerVersion) then
        ReportedVersion := ACallbacks.GetCompilerVersion(CandidateCompiler)
      else
        ReportedVersion := '';
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

function GetRequiredBootstrapVersionCore(
  const ATargetVersion, AInstallRoot: string;
  var AResourceRepo: TResourceRepository;
  const ACallbacks: TFPCBuilderBootstrapResolveCallbacks
): string;
var
  DownloadedSourceDir: string;
  MakefileRequiredVersion: string;
  i: Integer;
begin
  Result := '';

  DownloadedSourceDir := BuildFPCSourceInstallPathCore(AInstallRoot, ATargetVersion);
  if DirectoryExists(DownloadedSourceDir) then
  begin
    MakefileRequiredVersion := ResourceRepoGetBootstrapVersionFromMakefile(DownloadedSourceDir);
    if MakefileRequiredVersion <> '' then
    begin
      Result := MakefileRequiredVersion;
      Exit;
    end;
  end;

  if not Assigned(AResourceRepo) then
  begin
    AResourceRepo := TResourceRepository.Create(CreateDefaultConfig);
    if DirectoryExists(CreateDefaultConfig.LocalPath) then
      AResourceRepo.LoadManifest;
  end;

  if Assigned(AResourceRepo) then
  begin
    if Assigned(ACallbacks.GetResourceRepoRequiredBootstrapVersion) then
      Result := ACallbacks.GetResourceRepoRequiredBootstrapVersion(ATargetVersion)
    else if Assigned(AResourceRepo) then
      Result := AResourceRepo.GetRequiredBootstrapVersion(ATargetVersion);
    if Result <> '' then
      Exit;
  end;

  for i := 0 to High(LOCAL_FPC_BOOTSTRAP_REQUIREMENTS) do
  begin
    if SameText(LOCAL_FPC_BOOTSTRAP_REQUIREMENTS[i].TargetVersion, ATargetVersion) then
    begin
      Result := LOCAL_FPC_BOOTSTRAP_REQUIREMENTS[i].RequiredVersion;
      Break;
    end;
  end;
end;

end.
