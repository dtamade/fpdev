unit fpdev.package.types;

{
================================================================================
  fpdev.package.types - Package Management Type Definitions
================================================================================

  Contains core type definitions for the package management system:
  - TPackageInfo: Package metadata record
  - TSemanticVersion: Semantic version parsing
  - TVerificationStatus/TPackageVerificationResult: Verification types
  - TPackageCreationOptions: Package creation options
  - TPackageErrorCode/TPackageOperationResult: Error handling types

  Extracted from fpdev.cmd.package.pas for better modularity and reuse.

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TPackageInfo - Package metadata }
  TPackageInfo = record
    Name: string;
    Version: string;
    Description: string;
    Author: string;
    License: string;
    Homepage: string;
    Repository: string;
    Dependencies: TStringArray;
    URLs: TStringArray;       // Download URLs (may be empty)
    Sha256: string;           // Expected checksum (may be empty)
    SourcePath: string;       // Local source/package path (may be empty)
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

  { Helper functions for semantic versioning }
  function ParseSemanticVersion(const AVersionStr: string): TSemanticVersion;
  function CompareSemanticVersions(const A, B: TSemanticVersion): Integer;
  function SemanticVersionToString(const AVersion: TSemanticVersion): string;
  function IsValidSemanticVersion(const AVersionStr: string): Boolean;

  { Helper functions for package info }
  function EmptyPackageInfo: TPackageInfo;
  function PackageInfoToString(const AInfo: TPackageInfo): string;

implementation

function ParseSemanticVersion(const AVersionStr: string): TSemanticVersion;
var
  Parts: TStringArray;
  MainParts: TStringArray;
  VersionPart: string;
  PreReleasePart: string;
  DashPos: Integer;
begin
  Result.Valid := False;
  Result.Major := 0;
  Result.Minor := 0;
  Result.Patch := 0;
  Result.PreRelease := '';

  if AVersionStr = '' then
    Exit;

  // Split on dash for pre-release
  DashPos := Pos('-', AVersionStr);
  if DashPos > 0 then
  begin
    VersionPart := Copy(AVersionStr, 1, DashPos - 1);
    PreReleasePart := Copy(AVersionStr, DashPos + 1, Length(AVersionStr));
    Result.PreRelease := PreReleasePart;
  end
  else
    VersionPart := AVersionStr;

  // Split version on dots
  SetLength(Parts, 0);
  SetLength(MainParts, 0);

  // Manual split on '.'
  MainParts := VersionPart.Split(['.']);

  if Length(MainParts) < 1 then
    Exit;

  // Parse major
  if not TryStrToInt(MainParts[0], Result.Major) then
    Exit;

  // Parse minor (optional)
  if Length(MainParts) >= 2 then
  begin
    if not TryStrToInt(MainParts[1], Result.Minor) then
      Exit;
  end;

  // Parse patch (optional)
  if Length(MainParts) >= 3 then
  begin
    if not TryStrToInt(MainParts[2], Result.Patch) then
      Exit;
  end;

  Result.Valid := True;
end;

function CompareSemanticVersions(const A, B: TSemanticVersion): Integer;
begin
  // Compare major
  if A.Major <> B.Major then
  begin
    Result := A.Major - B.Major;
    Exit;
  end;

  // Compare minor
  if A.Minor <> B.Minor then
  begin
    Result := A.Minor - B.Minor;
    Exit;
  end;

  // Compare patch
  if A.Patch <> B.Patch then
  begin
    Result := A.Patch - B.Patch;
    Exit;
  end;

  // Pre-release versions have lower precedence
  if (A.PreRelease = '') and (B.PreRelease <> '') then
    Result := 1
  else if (A.PreRelease <> '') and (B.PreRelease = '') then
    Result := -1
  else
    Result := CompareStr(A.PreRelease, B.PreRelease);
end;

function SemanticVersionToString(const AVersion: TSemanticVersion): string;
begin
  if not AVersion.Valid then
  begin
    Result := '(invalid)';
    Exit;
  end;

  Result := Format('%d.%d.%d', [AVersion.Major, AVersion.Minor, AVersion.Patch]);
  if AVersion.PreRelease <> '' then
    Result := Result + '-' + AVersion.PreRelease;
end;

function IsValidSemanticVersion(const AVersionStr: string): Boolean;
var
  Ver: TSemanticVersion;
begin
  Ver := ParseSemanticVersion(AVersionStr);
  Result := Ver.Valid;
end;

function EmptyPackageInfo: TPackageInfo;
begin
  Result.Name := '';
  Result.Version := '';
  Result.Description := '';
  Result.Author := '';
  Result.License := '';
  Result.Homepage := '';
  Result.Repository := '';
  SetLength(Result.Dependencies, 0);
  SetLength(Result.URLs, 0);
  Result.Sha256 := '';
  Result.SourcePath := '';
  Result.Installed := False;
  Result.InstallPath := '';
  Result.InstallDate := 0;
end;

function PackageInfoToString(const AInfo: TPackageInfo): string;
begin
  Result := Format('%s v%s', [AInfo.Name, AInfo.Version]);
  if AInfo.Installed then
    Result := Result + ' [installed]';
end;

end.
