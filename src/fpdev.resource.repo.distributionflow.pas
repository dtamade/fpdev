unit fpdev.resource.repo.distributionflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson,
  fpdev.resource.repo.types,
  fpdev.resource.repo.binary,
  fpdev.resource.repo.cross;

type
  TRepoDistributionLogProc = procedure(const AMsg: string) of object;
  TRepoDistributionBinaryInfoGetter = function(const AVersion, APlatform: string;
    out AInfo: TPlatformInfo): Boolean of object;
  TRepoDistributionCrossInfoGetter = function(const ATarget, AHostPlatform: string;
    out AInfo: TCrossToolchainInfo): Boolean of object;
  TRepoDistributionPackageInfoGetter = function(const AName, AVersion: string;
    out AInfo: TRepoPackageInfo): Boolean of object;
  TRepoDistributionBinaryInstaller = function(const AInfo: TPlatformInfo;
    const AVersion, APlatform, ADestDir: string): Boolean of object;
  TRepoDistributionCrossInstaller = function(const AInfo: TCrossToolchainInfo;
    const ATarget, ADestDir: string): Boolean of object;
  TRepoDistributionPackageInstaller = function(const AInfo: TRepoPackageInfo;
    const AName, AVersion, ADestDir: string): Boolean of object;

function ResourceRepoMapBinaryReleaseInfo(
  const ASource: TBinaryReleaseInfo): TPlatformInfo;
function ResourceRepoMapCrossToolchainInfo(
  const ASource: TResourceRepoCrossInfo): TCrossToolchainInfo;
function ResourceRepoGetBinaryReleaseInfoCore(const AManifest: TJSONObject;
  const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
function ResourceRepoGetCrossToolchainInfoCore(const AManifest: TJSONObject;
  const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
function ResourceRepoHasPackageCore(const ALocalPath, AName, AVersion: string): Boolean;
function ResourceRepoGetPackageInfoCore(const ALocalPath, AName, AVersion: string;
  out AInfo: TRepoPackageInfo): Boolean;
function ExecuteResourceRepoInstallBinaryReleaseCore(const AVersion, APlatform,
  ADestDir: string; AGetInfo: TRepoDistributionBinaryInfoGetter;
  AInstall: TRepoDistributionBinaryInstaller;
  ALog: TRepoDistributionLogProc): Boolean;
function ExecuteResourceRepoInstallCrossToolchainCore(const ATarget,
  AHostPlatform, ADestDir: string; AGetInfo: TRepoDistributionCrossInfoGetter;
  AInstall: TRepoDistributionCrossInstaller;
  ALog: TRepoDistributionLogProc): Boolean;
function ExecuteResourceRepoInstallPackageCore(const AName, AVersion,
  ADestDir: string; AGetInfo: TRepoDistributionPackageInfoGetter;
  AInstall: TRepoDistributionPackageInstaller;
  ALog: TRepoDistributionLogProc): Boolean;

implementation

uses
  fpdev.resource.repo.package;

function ResourceRepoMapBinaryReleaseInfo(
  const ASource: TBinaryReleaseInfo): TPlatformInfo;
var
  Index: Integer;
begin
  Result := EmptyPlatformInfo;
  Result.Path := ASource.Path;
  Result.URL := ASource.URL;
  Result.SHA256 := ASource.SHA256;
  Result.Size := ASource.Size;
  Result.Tested := ASource.Tested;
  SetLength(Result.Mirrors, Length(ASource.Mirrors));
  for Index := 0 to High(ASource.Mirrors) do
    Result.Mirrors[Index] := ASource.Mirrors[Index];
end;

function ResourceRepoMapCrossToolchainInfo(
  const ASource: TResourceRepoCrossInfo): TCrossToolchainInfo;
begin
  Result := EmptyCrossToolchainInfo;
  Result.TargetName := ASource.TargetName;
  Result.DisplayName := ASource.DisplayName;
  Result.CPU := ASource.CPU;
  Result.OS := ASource.OS;
  Result.BinutilsPrefix := ASource.BinutilsPrefix;
  Result.BinutilsArchive := ASource.BinutilsArchive;
  Result.LibsArchive := ASource.LibsArchive;
  Result.BinutilsSHA256 := ASource.BinutilsSHA256;
  Result.LibsSHA256 := ASource.LibsSHA256;
end;

function ResourceRepoGetBinaryReleaseInfoCore(const AManifest: TJSONObject;
  const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
var
  BinaryInfo: TBinaryReleaseInfo;
begin
  Result := False;
  AInfo := EmptyPlatformInfo;

  if not ResourceRepoGetBinaryReleaseInfo(AManifest, AVersion, APlatform,
    BinaryInfo) then
    Exit;

  AInfo := ResourceRepoMapBinaryReleaseInfo(BinaryInfo);
  Result := True;
end;

function ResourceRepoGetCrossToolchainInfoCore(const AManifest: TJSONObject;
  const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
var
  CrossInfo: TResourceRepoCrossInfo;
begin
  Result := False;
  AInfo := EmptyCrossToolchainInfo;

  if not ResourceRepoGetCrossToolchainInfo(AManifest, ATarget, AHostPlatform,
    CrossInfo) then
    Exit;

  AInfo := ResourceRepoMapCrossToolchainInfo(CrossInfo);
  Result := True;
end;

function ResourceRepoHasPackageCore(const ALocalPath, AName, AVersion: string): Boolean;
begin
  if AVersion = '' then;
  Result := ResourceRepoResolvePackageMetaPath(ALocalPath, AName) <> '';
end;

function ResourceRepoGetPackageInfoCore(const ALocalPath, AName, AVersion: string;
  out AInfo: TRepoPackageInfo): Boolean;
var
  PackageMetaPath: string;
begin
  Result := False;
  AInfo := EmptyRepoPackageInfo;
  if AVersion = '' then;

  PackageMetaPath := ResourceRepoResolvePackageMetaPath(ALocalPath, AName);
  if PackageMetaPath = '' then
    Exit;

  Result := ResourceRepoLoadPackageInfoFromFile(PackageMetaPath, AName, AInfo);
end;

function ExecuteResourceRepoInstallBinaryReleaseCore(const AVersion, APlatform,
  ADestDir: string; AGetInfo: TRepoDistributionBinaryInfoGetter;
  AInstall: TRepoDistributionBinaryInstaller;
  ALog: TRepoDistributionLogProc): Boolean;
var
  Info: TPlatformInfo;
begin
  Result := False;
  if (not Assigned(AGetInfo)) or (not Assigned(AInstall)) then
    Exit;

  if not AGetInfo(AVersion, APlatform, Info) then
  begin
    if Assigned(ALog) then
      ALog('Error: Binary release info not found');
    Exit;
  end;

  Result := AInstall(Info, AVersion, APlatform, ADestDir);
end;

function ExecuteResourceRepoInstallCrossToolchainCore(const ATarget,
  AHostPlatform, ADestDir: string; AGetInfo: TRepoDistributionCrossInfoGetter;
  AInstall: TRepoDistributionCrossInstaller;
  ALog: TRepoDistributionLogProc): Boolean;
var
  Info: TCrossToolchainInfo;
begin
  Result := False;
  if (not Assigned(AGetInfo)) or (not Assigned(AInstall)) then
    Exit;

  if not AGetInfo(ATarget, AHostPlatform, Info) then
  begin
    if Assigned(ALog) then
      ALog('Error: Cross toolchain info not found');
    Exit;
  end;

  Result := AInstall(Info, ATarget, ADestDir);
end;

function ExecuteResourceRepoInstallPackageCore(const AName, AVersion,
  ADestDir: string; AGetInfo: TRepoDistributionPackageInfoGetter;
  AInstall: TRepoDistributionPackageInstaller;
  ALog: TRepoDistributionLogProc): Boolean;
var
  Info: TRepoPackageInfo;
begin
  Result := False;
  if (not Assigned(AGetInfo)) or (not Assigned(AInstall)) then
    Exit;

  if not AGetInfo(AName, AVersion, Info) then
  begin
    if Assigned(ALog) then
      ALog(Format('Error: Package info not found for %s', [AName]));
    Exit;
  end;

  Result := AInstall(Info, AName, AVersion, ADestDir);
end;

end.
