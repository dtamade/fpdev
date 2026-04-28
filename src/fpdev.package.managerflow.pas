unit fpdev.package.managerflow;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.package.types,
  fpdev.package.depgraph,
  fpdev.package.sourceprep,
  fpdev.package.sourceinstall;

type
  TPackageInstallSourceTreeAction = function(
    const ASourcePath, AInstallPath: string
  ): Boolean of object;

function ExecutePackageInstallFromSourceCore(
  const APackageName, ASourcePath, AInstallPath: string;
  APrepareTree: TPackageInstallSourceTreeAction;
  AInfoProvider: TPackageSourceInfoProvider;
  ABuildAction: TPackageSourceBuildAction;
  AMetadataWriter: TPackageSourceMetadataWriter
): Boolean; overload;

function ExecutePackageInstallFromSourceCore(
  const APackageName, ASourcePath, AInstallPath: string;
  ADeleteDirRecursive: TPackageSourcePrepDirAction;
  ACopyDirRecursive: TPackageSourcePrepCopyAction;
  AEnsureDir: TPackageSourcePrepDirAction;
  AInfoProvider: TPackageSourceInfoProvider;
  ABuildAction: TPackageSourceBuildAction;
  AMetadataWriter: TPackageSourceMetadataWriter
): Boolean; overload;

function ResolvePackageDependenciesCore(
  const APackageName: string;
  const AAvailablePackages, AInstalledPackages: TPackageArray;
  AExtractPackageName: TDependencyNameExtractor
): TStringArray;

function BuildPackageDependencyLinesCore(
  const APackageName: string;
  const ADependencies: TStringArray
): TStringArray;

function WritePackageDependencyLinesCore(
  const APackageName: string;
  const ADependencies: TStringArray;
  Outp: IOutput
): Boolean;

implementation

function ExecutePreparedPackageInstallCore(
  const APackageName, AInstallPath: string;
  AInfoProvider: TPackageSourceInfoProvider;
  ABuildAction: TPackageSourceBuildAction;
  AMetadataWriter: TPackageSourceMetadataWriter
): Boolean;
begin
  Result := InstallPreparedPackageSourceCore(
    APackageName,
    AInstallPath,
    AInfoProvider,
    ABuildAction,
    AMetadataWriter
  );
end;

function ExecutePackageInstallFromSourceCore(
  const APackageName, ASourcePath, AInstallPath: string;
  APrepareTree: TPackageInstallSourceTreeAction;
  AInfoProvider: TPackageSourceInfoProvider;
  ABuildAction: TPackageSourceBuildAction;
  AMetadataWriter: TPackageSourceMetadataWriter
): Boolean;
var
  ResolvedSourcePath: string;
  ResolvedInstallPath: string;
begin
  Result := False;

  if not Assigned(APrepareTree) then
    Exit;

  try
    ResolvedSourcePath := ExpandFileName(ASourcePath);
    ResolvedInstallPath := ExpandFileName(AInstallPath);

    if not APrepareTree(ResolvedSourcePath, ResolvedInstallPath) then
      Exit;

    Result := ExecutePreparedPackageInstallCore(
      APackageName,
      ResolvedInstallPath,
      AInfoProvider,
      ABuildAction,
      AMetadataWriter
    );
  except
    on E: Exception do
      Result := False;
  end;
end;

function ExecutePackageInstallFromSourceCore(
  const APackageName, ASourcePath, AInstallPath: string;
  ADeleteDirRecursive: TPackageSourcePrepDirAction;
  ACopyDirRecursive: TPackageSourcePrepCopyAction;
  AEnsureDir: TPackageSourcePrepDirAction;
  AInfoProvider: TPackageSourceInfoProvider;
  ABuildAction: TPackageSourceBuildAction;
  AMetadataWriter: TPackageSourceMetadataWriter
): Boolean;
var
  ResolvedSourcePath: string;
  ResolvedInstallPath: string;
begin
  Result := False;

  try
    ResolvedSourcePath := ExpandFileName(ASourcePath);
    ResolvedInstallPath := ExpandFileName(AInstallPath);

    if not PreparePackageInstallSourceTreeCore(
      ResolvedSourcePath,
      ResolvedInstallPath,
      ADeleteDirRecursive,
      ACopyDirRecursive,
      AEnsureDir
    ) then
      Exit;

    Result := ExecutePreparedPackageInstallCore(
      APackageName,
      ResolvedInstallPath,
      AInfoProvider,
      ABuildAction,
      AMetadataWriter
    );
  except
    on E: Exception do
      Result := False;
  end;
end;

function ResolvePackageDependenciesCore(
  const APackageName: string;
  const AAvailablePackages, AInstalledPackages: TPackageArray;
  AExtractPackageName: TDependencyNameExtractor
): TStringArray;
var
  AvailableDescriptors: TPackageDepDescriptorArray;
  InstalledDescriptors: TPackageDepDescriptorArray;
begin
  Initialize(Result);
  SetLength(Result, 0);

  if APackageName = '' then
    Exit;

  AvailableDescriptors := PackageArrayToDepDescriptorsCore(AAvailablePackages);
  InstalledDescriptors := PackageArrayToDepDescriptorsCore(AInstalledPackages);

  Result := ResolvePackageDependencyOrderCore(
    APackageName,
    AvailableDescriptors,
    InstalledDescriptors,
    AExtractPackageName
  );
end;

function BuildPackageDependencyLinesCore(
  const APackageName: string;
  const ADependencies: TStringArray
): TStringArray;
var
  Index: Integer;
  LineCount: Integer;
begin
  Result := nil;
  LineCount := 0;

  SetLength(Result, 1);
  Result[0] := 'Dependencies for ' + APackageName + ':';
  LineCount := 1;

  for Index := 0 to High(ADependencies) do
  begin
    if SameText(ADependencies[Index], APackageName) then
      Continue;
    SetLength(Result, LineCount + 1);
    Result[LineCount] := '- ' + ADependencies[Index];
    Inc(LineCount);
  end;

  if LineCount = 1 then
  begin
    SetLength(Result, 2);
    Result[1] := '(none)';
    LineCount := 2;
  end;

  SetLength(Result, LineCount);
end;

function WritePackageDependencyLinesCore(
  const APackageName: string;
  const ADependencies: TStringArray;
  Outp: IOutput
): Boolean;
var
  Lines: TStringArray;
  Line: string;
begin
  Result := Assigned(Outp);
  if not Result then
    Exit;

  Lines := BuildPackageDependencyLinesCore(APackageName, ADependencies);
  for Line in Lines do
    Outp.WriteLn(Line);
end;

end.
