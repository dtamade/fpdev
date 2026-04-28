unit fpdev.resource.repo.packageflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.resource.repo.types,
  fpdev.resource.repo.search;

type
  TResourceRepoPackageLogFmtProc = procedure(const AFormat: string;
    const AArgs: array of const) of object;
  TResourceRepoPackageInfoQueryFunc = function(const ALocalPath, AName,
    AVersion: string; out AInfo: TRepoPackageInfo): Boolean;
  TResourceRepoPackageInfoQueryMethod = function(const ALocalPath, AName,
    AVersion: string; out AInfo: TRepoPackageInfo): Boolean of object;
  TResourceRepoPackageListQueryFunc = function(const ALocalPath,
    ACategory: string): SysUtils.TStringArray;
  TResourceRepoPackageListQueryMethod = function(const ALocalPath,
    ACategory: string): SysUtils.TStringArray of object;
  TResourceRepoPackageListGetter = function(
    const ACategory: string): SysUtils.TStringArray of object;
  TResourceRepoPackageInfoGetter = fpdev.resource.repo.search.TResourceRepoPackageInfoGetter;
  TResourceRepoPackageSearchFunc = function(const AAllPackages: SysUtils.TStringArray;
    const AKeyword: string; AInfoGetter: TResourceRepoPackageInfoGetter): SysUtils.TStringArray;

function ExecuteResourceRepoPackageInfoSurfaceCore(const ALocalPath, AName,
  AVersion: string; out AInfo: TRepoPackageInfo;
  ALogFmt: TResourceRepoPackageLogFmtProc;
  AGetPackageInfo: TResourceRepoPackageInfoQueryFunc): Boolean; overload;
function ExecuteResourceRepoPackageInfoSurfaceCore(const ALocalPath, AName,
  AVersion: string; out AInfo: TRepoPackageInfo;
  ALogFmt: TResourceRepoPackageLogFmtProc;
  AGetPackageInfo: TResourceRepoPackageInfoQueryMethod): Boolean; overload;
function ExecuteResourceRepoPackageListSurfaceCore(const ALocalPath,
  ACategory: string;
  AListPackages: TResourceRepoPackageListQueryFunc): SysUtils.TStringArray; overload;
function ExecuteResourceRepoPackageListSurfaceCore(const ALocalPath,
  ACategory: string;
  AListPackages: TResourceRepoPackageListQueryMethod): SysUtils.TStringArray; overload;
function ExecuteResourceRepoPackageSearchSurfaceCore(const AKeyword: string;
  AListPackages: TResourceRepoPackageListGetter;
  AGetPackageInfo: TResourceRepoPackageInfoGetter;
  ASearchPackages: TResourceRepoPackageSearchFunc): SysUtils.TStringArray;

implementation

function ExecuteResourceRepoPackageInfoSurfaceCoreImpl(const ALocalPath, AName,
  AVersion: string; out AInfo: TRepoPackageInfo;
  ALogFmt: TResourceRepoPackageLogFmtProc;
  AGetPackageInfo: TResourceRepoPackageInfoQueryFunc): Boolean;
begin
  Result := False;
  AInfo := EmptyRepoPackageInfo;

  try
    if Assigned(AGetPackageInfo) then
      Result := AGetPackageInfo(ALocalPath, AName, AVersion, AInfo);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt('Error checking package availability: %s', [E.Message]);
      AInfo := EmptyRepoPackageInfo;
      Result := False;
    end;
  end;
end;

function ExecuteResourceRepoPackageInfoSurfaceCore(const ALocalPath, AName,
  AVersion: string; out AInfo: TRepoPackageInfo;
  ALogFmt: TResourceRepoPackageLogFmtProc;
  AGetPackageInfo: TResourceRepoPackageInfoQueryFunc): Boolean;
begin
  Result := ExecuteResourceRepoPackageInfoSurfaceCoreImpl(
    ALocalPath, AName, AVersion, AInfo, ALogFmt, AGetPackageInfo
  );
end;

function ExecuteResourceRepoPackageInfoSurfaceCore(const ALocalPath, AName,
  AVersion: string; out AInfo: TRepoPackageInfo;
  ALogFmt: TResourceRepoPackageLogFmtProc;
  AGetPackageInfo: TResourceRepoPackageInfoQueryMethod): Boolean;
begin
  Result := False;
  AInfo := EmptyRepoPackageInfo;

  try
    if Assigned(AGetPackageInfo) then
      Result := AGetPackageInfo(ALocalPath, AName, AVersion, AInfo);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt('Error checking package availability: %s', [E.Message]);
      AInfo := EmptyRepoPackageInfo;
      Result := False;
    end;
  end;
end;

function ExecuteResourceRepoPackageListSurfaceCore(const ALocalPath,
  ACategory: string;
  AListPackages: TResourceRepoPackageListQueryFunc): SysUtils.TStringArray;
begin
  Result := nil;
  if Assigned(AListPackages) then
    Result := AListPackages(ALocalPath, ACategory);
end;

function ExecuteResourceRepoPackageListSurfaceCore(const ALocalPath,
  ACategory: string;
  AListPackages: TResourceRepoPackageListQueryMethod): SysUtils.TStringArray;
begin
  Result := nil;
  if Assigned(AListPackages) then
    Result := AListPackages(ALocalPath, ACategory);
end;

function ExecuteResourceRepoPackageSearchSurfaceCore(const AKeyword: string;
  AListPackages: TResourceRepoPackageListGetter;
  AGetPackageInfo: TResourceRepoPackageInfoGetter;
  ASearchPackages: TResourceRepoPackageSearchFunc): SysUtils.TStringArray;
var
  AllPackages: SysUtils.TStringArray;
begin
  AllPackages := nil;
  Result := nil;

  if Assigned(AListPackages) then
    AllPackages := AListPackages('');

  if Assigned(ASearchPackages) then
    Result := ASearchPackages(AllPackages, AKeyword, AGetPackageInfo);
end;

end.
