unit fpdev.resource.repo.queryflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson,
  fpdev.resource.repo.types;

type
  TResourceRepoEnsureManifestLoadedFunc = function: Boolean of object;
  TResourceRepoLogFmtProc = procedure(const AFormat: string; const AArgs: array of const) of object;
  TResourceRepoBoolQueryFunc = function(const AManifest: TJSONObject;
    const AArg1, AArg2: string): Boolean;
  TResourceRepoPlatformInfoQueryFunc = function(const AManifest: TJSONObject;
    const AArg1, AArg2: string; out AInfo: TPlatformInfo): Boolean;
  TResourceRepoCrossInfoQueryFunc = function(const AManifest: TJSONObject;
    const AArg1, AArg2: string; out AInfo: TCrossToolchainInfo): Boolean;
  TResourceRepoStringQueryFunc = function(const AManifest: TJSONObject;
    const AArg: string): string;
  TResourceRepoStringArrayQueryFunc = function(const AManifest: TJSONObject): SysUtils.TStringArray;

function ExecuteResourceRepoBooleanQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg1, AArg2: string;
  AQuery: TResourceRepoBoolQueryFunc
): Boolean;

function ExecuteResourceRepoPlatformInfoQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg1, AArg2: string;
  out AInfo: TPlatformInfo;
  AQuery: TResourceRepoPlatformInfoQueryFunc
): Boolean;

function ExecuteResourceRepoCrossInfoQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg1, AArg2: string;
  out AInfo: TCrossToolchainInfo;
  AQuery: TResourceRepoCrossInfoQueryFunc
): Boolean;

function ExecuteResourceRepoStringQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg: string;
  AQuery, AFallbackQuery: TResourceRepoStringQueryFunc
): string;

function ExecuteResourceRepoStringArrayQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat: string;
  AQuery: TResourceRepoStringArrayQueryFunc
): SysUtils.TStringArray;

implementation

function ExecuteResourceRepoBooleanQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg1, AArg2: string;
  AQuery: TResourceRepoBoolQueryFunc
): Boolean;
begin
  Result := False;

  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
    Exit;

  try
    if Assigned(AQuery) then
      Result := AQuery(AManifest, AArg1, AArg2);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt(AErrorFormat, [E.Message]);
      Result := False;
    end;
  end;
end;

function ExecuteResourceRepoPlatformInfoQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg1, AArg2: string;
  out AInfo: TPlatformInfo;
  AQuery: TResourceRepoPlatformInfoQueryFunc
): Boolean;
begin
  Result := False;
  AInfo := EmptyPlatformInfo;

  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
    Exit;

  try
    if Assigned(AQuery) then
      Result := AQuery(AManifest, AArg1, AArg2, AInfo);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt(AErrorFormat, [E.Message]);
      AInfo := EmptyPlatformInfo;
      Result := False;
    end;
  end;
end;

function ExecuteResourceRepoCrossInfoQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg1, AArg2: string;
  out AInfo: TCrossToolchainInfo;
  AQuery: TResourceRepoCrossInfoQueryFunc
): Boolean;
begin
  Result := False;
  AInfo := EmptyCrossToolchainInfo;

  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
    Exit;

  try
    if Assigned(AQuery) then
      Result := AQuery(AManifest, AArg1, AArg2, AInfo);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt(AErrorFormat, [E.Message]);
      AInfo := EmptyCrossToolchainInfo;
      Result := False;
    end;
  end;
end;

function ExecuteResourceRepoStringQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat, AArg: string;
  AQuery, AFallbackQuery: TResourceRepoStringQueryFunc
): string;
begin
  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
  begin
    if Assigned(AFallbackQuery) then
      Exit(AFallbackQuery(nil, AArg));
    Exit('');
  end;

  try
    if Assigned(AQuery) then
      Result := AQuery(AManifest, AArg)
    else
      Result := '';
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt(AErrorFormat, [E.Message]);
      if Assigned(AFallbackQuery) then
        Result := AFallbackQuery(nil, AArg)
      else
        Result := '';
    end;
  end;
end;

function ExecuteResourceRepoStringArrayQueryCore(
  AManifest: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc;
  ALogFmt: TResourceRepoLogFmtProc;
  const AErrorFormat: string;
  AQuery: TResourceRepoStringArrayQueryFunc
): SysUtils.TStringArray;
begin
  Result := nil;

  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
    Exit;

  try
    if Assigned(AQuery) then
      Result := AQuery(AManifest)
    else
      SetLength(Result, 0);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt(AErrorFormat, [E.Message]);
      SetLength(Result, 0);
    end;
  end;
end;

end.
