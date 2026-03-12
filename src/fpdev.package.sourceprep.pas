unit fpdev.package.sourceprep;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TPackageSourcePrepDirAction = function(const APath: string): Boolean;
  TPackageSourcePrepCopyAction = function(const ASrc, ADest: string): Boolean;

function PreparePackageInstallSourceTreeCore(
  const ASourcePath, AInstallPath: string;
  ADeleteDirRecursive: TPackageSourcePrepDirAction;
  ACopyDirRecursive: TPackageSourcePrepCopyAction;
  AEnsureDir: TPackageSourcePrepDirAction
): Boolean;

implementation

function NormalizePackageSourcePrepPath(const APath: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
end;

function PreparePackageInstallSourceTreeCore(
  const ASourcePath, AInstallPath: string;
  ADeleteDirRecursive: TPackageSourcePrepDirAction;
  ACopyDirRecursive: TPackageSourcePrepCopyAction;
  AEnsureDir: TPackageSourcePrepDirAction
): Boolean;
var
  ResolvedSourcePath: string;
  ResolvedInstallPath: string;
begin
  Result := False;

  if (not Assigned(ADeleteDirRecursive)) or
     (not Assigned(ACopyDirRecursive)) or
     (not Assigned(AEnsureDir)) then
    Exit;

  ResolvedSourcePath := NormalizePackageSourcePrepPath(ASourcePath);
  ResolvedInstallPath := NormalizePackageSourcePrepPath(AInstallPath);

  if not SameText(ResolvedSourcePath, ResolvedInstallPath) then
  begin
    if DirectoryExists(ResolvedInstallPath) then
      if not ADeleteDirRecursive(ResolvedInstallPath) then
        Exit;

    Result := ACopyDirRecursive(ResolvedSourcePath, ResolvedInstallPath);
    Exit;
  end;

  if DirectoryExists(ResolvedInstallPath) then
    Exit(True);

  Result := AEnsureDir(ResolvedInstallPath);
end;

end.
