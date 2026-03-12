unit fpdev.cmd.package;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.package.manager, fpdev.package.types, fpdev.pkg.deps;

type
  TDependencyGraph = TDependencyNodeArray;
  TPackageManager = fpdev.package.manager.TPackageManager;

function ParseSemanticVersion(const AVersion: string): TSemanticVersion;
function CompareVersions(const AVersion1, AVersion2: string): Integer;
function VersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;

function BuildDependencyGraph(
  const ARootPackage: string;
  const APackages: TPackageArray
): TDependencyNodeArray;
function TopologicalSortDependencies(const AGraph: TDependencyNodeArray): TStringArray;

function VerifyInstalledPackage(const TestDir: string): TPackageVerificationResult;
function VerifyPackageChecksum(const FilePath, Hash: string): Boolean;

function CollectPackageSourceFiles(
  const SourceDir: string;
  const ExcludePatterns: TStringArray
): TStringArray;
function IsBuildArtifact(const FileName: string): Boolean;
function GeneratePackageMetadataJson(const Options: TPackageCreationOptions): string;
function CreatePackageZipArchive(
  const SourceDir: string;
  const Files: TStringArray;
  const OutputPath: string;
  var Err: string
): Boolean;

function ValidatePackageSourcePath(const SourcePath: string): Boolean;
function ValidatePackageMetadata(const MetadataPath: string): Boolean;
function CheckPackageRequiredFiles(const PackageDir: string): TStringArray;

implementation

uses
  fpdev.package.semver,
  fpdev.package.depgraph,
  fpdev.package.verification,
  fpdev.package.creation,
  fpdev.package.sourcevalidation;

function ParseSemanticVersion(const AVersion: string): TSemanticVersion;
var
  Parsed: TPackageSemanticVersion;
begin
  Parsed := ParsePackageSemanticVersion(AVersion);
  Result.Valid := Parsed.Valid;
  Result.Major := Parsed.Major;
  Result.Minor := Parsed.Minor;
  Result.Patch := Parsed.Patch;
  Result.PreRelease := Parsed.PreRelease;
end;

function CompareVersions(const AVersion1, AVersion2: string): Integer;
begin
  Result := ComparePackageVersions(AVersion1, AVersion2);
end;

function VersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;
begin
  Result := PackageVersionSatisfiesConstraint(AVersion, AConstraint);
end;

function BuildDependencyGraph(
  const ARootPackage: string;
  const APackages: TPackageArray
): TDependencyNodeArray;
begin
  Result := fpdev.package.depgraph.BuildPackageDependencyGraph(
    ARootPackage,
    PackageArrayToDepDescriptorsCore(APackages)
  );
end;

function TopologicalSortDependencies(const AGraph: TDependencyNodeArray): TStringArray;
begin
  Result := fpdev.package.depgraph.TopologicalSortPackageDependencies(AGraph);
end;

function VerifyInstalledPackage(const TestDir: string): TPackageVerificationResult;
var
  VerifyResult: TPackageVerifyResult;
  i: Integer;
begin
  VerifyResult := VerifyInstalledPackageCore(TestDir);

  case VerifyResult.Status of
    pvsValid:
      Result.Status := vsValid;
    pvsMissingFiles:
      Result.Status := vsMissingFiles;
    pvsMetadataError:
      Result.Status := vsMetadataError;
  else
    Result.Status := vsInvalid;
  end;

  Result.PackageName := VerifyResult.PackageName;
  Result.Version := VerifyResult.Version;
  SetLength(Result.MissingFiles, Length(VerifyResult.MissingFiles));
  for i := 0 to High(VerifyResult.MissingFiles) do
    Result.MissingFiles[i] := VerifyResult.MissingFiles[i];
end;

function VerifyPackageChecksum(const FilePath, Hash: string): Boolean;
begin
  Result := VerifyPackageChecksumCore(FilePath, Hash);
end;

function IsBuildArtifact(const FileName: string): Boolean;
begin
  Result := IsBuildArtifactCore(FileName);
end;

function CollectPackageSourceFiles(
  const SourceDir: string;
  const ExcludePatterns: TStringArray
): TStringArray;
begin
  Result := CollectPackageSourceFilesCore(SourceDir, ExcludePatterns);
end;

function GeneratePackageMetadataJson(const Options: TPackageCreationOptions): string;
var
  CreateOptions: TPackageCreateOptions;
  i: Integer;
begin
  CreateOptions.Name := Options.Name;
  CreateOptions.Version := Options.Version;
  CreateOptions.SourcePath := Options.SourcePath;
  SetLength(CreateOptions.ExcludePatterns, Length(Options.ExcludePatterns));
  for i := 0 to High(Options.ExcludePatterns) do
    CreateOptions.ExcludePatterns[i] := Options.ExcludePatterns[i];

  Result := GeneratePackageMetadataJsonCore(CreateOptions);
end;

function CreatePackageZipArchive(
  const SourceDir: string;
  const Files: TStringArray;
  const OutputPath: string;
  var Err: string
): Boolean;
begin
  Result := CreatePackageZipArchiveCore(SourceDir, Files, OutputPath, Err);
end;

function ValidatePackageSourcePath(const SourcePath: string): Boolean;
begin
  Result := fpdev.package.sourcevalidation.ValidatePackageSourcePath(SourcePath);
end;

function ValidatePackageMetadata(const MetadataPath: string): Boolean;
begin
  Result := ValidatePackageMetadataFile(MetadataPath);
end;

function CheckPackageRequiredFiles(const PackageDir: string): TStringArray;
begin
  Result := FindMissingRequiredPackageFiles(PackageDir);
end;

end.
