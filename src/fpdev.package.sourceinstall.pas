unit fpdev.package.sourceinstall;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types;

type
  TPackageSourceInfoProvider = function(const APackageName: string): TPackageInfo of object;
  TPackageSourceBuildAction = function(const ASourcePath: string): Boolean of object;
  TPackageSourceMetadataWriter = function(
    const AInstallPath: string;
    const AInfo: TPackageInfo
  ): Boolean of object;

function InstallPreparedPackageSourceCore(
  const APackageName, AInstallPath: string;
  AInfoProvider: TPackageSourceInfoProvider;
  ABuildAction: TPackageSourceBuildAction;
  AMetadataWriter: TPackageSourceMetadataWriter
): Boolean;

implementation

uses
  fpdev.package.metadataio;

function InstallPreparedPackageSourceCore(
  const APackageName, AInstallPath: string;
  AInfoProvider: TPackageSourceInfoProvider;
  ABuildAction: TPackageSourceBuildAction;
  AMetadataWriter: TPackageSourceMetadataWriter
): Boolean;
var
  Info: TPackageInfo;
  SourceMetaPath: string;
begin
  Result := False;

  if (not Assigned(AInfoProvider)) or
     (not Assigned(ABuildAction)) or
     (not Assigned(AMetadataWriter)) then
    Exit;

  Info := AInfoProvider(APackageName);
  if Info.Name = '' then
    Info.Name := APackageName;

  Info.SourcePath := '';
  SourceMetaPath := IncludeTrailingPathDelimiter(AInstallPath) + 'package.json';
  ApplyPackageMetadataToInfoCore(SourceMetaPath, Info);

  if not ABuildAction(AInstallPath) then
    Exit;

  Result := AMetadataWriter(AInstallPath, Info);
end;

end.
