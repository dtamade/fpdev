unit fpdev.package.installflow;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TPackageArchiveExtractor = function(const AArchive, ADestDir: string; out AErr: string): Boolean;
  TPackageSourceInstaller = function(const APackageName, ASourcePath: string): Boolean of object;

function InstallPackageArchiveCore(
  const APackageName, AVersion, AZipPath, ASandboxDir: string;
  AKeepArtifacts: Boolean;
  AExtractor: TPackageArchiveExtractor;
  AInstaller: TPackageSourceInstaller;
  out ACleanupWarningPath: string;
  out AErr: string
): Boolean;

implementation

uses
  fpdev.utils.fs;

function InstallPackageArchiveCore(
  const APackageName, AVersion, AZipPath, ASandboxDir: string;
  AKeepArtifacts: Boolean;
  AExtractor: TPackageArchiveExtractor;
  AInstaller: TPackageSourceInstaller;
  out ACleanupWarningPath: string;
  out AErr: string
): Boolean;
var
  TmpDir: string;
begin
  Result := False;
  ACleanupWarningPath := '';
  AErr := '';

  if not Assigned(AExtractor) or not Assigned(AInstaller) then
    Exit;

  TmpDir := IncludeTrailingPathDelimiter(ASandboxDir) + 'pkg-' + APackageName + '-' + AVersion;
  if DirectoryExists(TmpDir) then
    ;

  if not AExtractor(AZipPath, TmpDir, AErr) then
    Exit;

  if not AInstaller(APackageName, TmpDir) then
    Exit;

  if not AKeepArtifacts then
  begin
    if DirectoryExists(TmpDir) then
      if not DeleteDirRecursive(TmpDir) then
        ACleanupWarningPath := TmpDir;
  end;

  Result := True;
end;

end.
