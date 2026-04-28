unit fpdev.resource.repo.mirrorflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson,
  fpdev.resource.repo.types,
  fpdev.resource.repo.mirror;

type
  TResourceRepoMirrorRegionDetector = function: string of object;
  TResourceRepoMirrorEnsureManifestLoaded = function: Boolean of object;
  TResourceRepoMirrorLogFmtProc = procedure(const AFormat: string;
    const AArgs: array of const) of object;
  TResourceRepoMirrorParseMirrorsFunc = function(
    const AManifestData: TJSONObject
  ): TResourceRepoMirrorInfoArray of object;

  TResourceRepoMirrorLatencyState = record
    URL: string;
    Latency: Integer;
  end;

  TResourceRepoMirrorLatencyStateArray = array of TResourceRepoMirrorLatencyState;

  TResourceRepoMirrorSelection = record
    SelectedMirror: string;
    CandidateMirrors: TStringArray;
    CandidateLatencies: TResourceRepoMirrorLatencyArray;
    UsedRegion: string;
    UsedCache: Boolean;
  end;

function SelectResourceRepoBestMirrorCore(
  const AManifestData: TJSONObject;
  const AConfiguredRegion, APrimaryURL: string;
  const AConfigMirrors: array of string;
  const ACachedBestMirror: string;
  AMirrorCacheTime: TDateTime;
  ACacheTTlHours: Integer;
  ACurrentTime: TDateTime;
  ADetectRegion: TResourceRepoMirrorRegionDetector;
  ATestLatency: TResourceRepoMirrorLatencyTestFunc
): TResourceRepoMirrorSelection;

function ConvertResourceRepoMirrorsCore(
  const AParsedMirrors: TResourceRepoMirrorInfoArray
): TMirrorArray;

function ExecuteResourceRepoSelectBestMirrorSurfaceCore(
  const AManifestData: TJSONObject;
  const AConfiguredRegion, APrimaryURL: string;
  const AConfigMirrors: array of string;
  var ACachedBestMirror: string;
  var AMirrorCacheTime: TDateTime;
  var AMirrorLatencies: TResourceRepoMirrorLatencyStateArray;
  ACacheTTlHours: Integer;
  ACurrentTime: TDateTime;
  AEnsureManifestLoaded: TResourceRepoMirrorEnsureManifestLoaded;
  ADetectRegion: TResourceRepoMirrorRegionDetector;
  ATestLatency: TResourceRepoMirrorLatencyTestFunc;
  ALogFmt: TResourceRepoMirrorLogFmtProc
): string;

function ExecuteResourceRepoGetMirrorsSurfaceCore(
  const AManifestData: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoMirrorEnsureManifestLoaded;
  AParseMirrors: TResourceRepoMirrorParseMirrorsFunc;
  ALogFmt: TResourceRepoMirrorLogFmtProc
): TMirrorArray;

implementation

function SelectResourceRepoBestMirrorCore(
  const AManifestData: TJSONObject;
  const AConfiguredRegion, APrimaryURL: string;
  const AConfigMirrors: array of string;
  const ACachedBestMirror: string;
  AMirrorCacheTime: TDateTime;
  ACacheTTlHours: Integer;
  ACurrentTime: TDateTime;
  ADetectRegion: TResourceRepoMirrorRegionDetector;
  ATestLatency: TResourceRepoMirrorLatencyTestFunc
): TResourceRepoMirrorSelection;
var
  CachedMirror: string;
  BestMirror: string;
begin
  Result := Default(TResourceRepoMirrorSelection);
  Result.SelectedMirror := APrimaryURL;
  SetLength(Result.CandidateMirrors, 0);
  SetLength(Result.CandidateLatencies, 0);

  if ResourceRepoTryGetCachedMirror(
    ACachedBestMirror,
    AMirrorCacheTime,
    ACacheTTlHours,
    ACurrentTime,
    CachedMirror
  ) then
  begin
    Result.SelectedMirror := CachedMirror;
    Result.UsedCache := True;
    Exit;
  end;

  if not Assigned(AManifestData) then
    Exit;

  if AConfiguredRegion <> '' then
    Result.UsedRegion := AConfiguredRegion
  else if Assigned(ADetectRegion) then
    Result.UsedRegion := ADetectRegion();

  Result.CandidateMirrors := ResourceRepoBuildCandidateMirrors(
    AManifestData,
    Result.UsedRegion,
    APrimaryURL,
    AConfigMirrors
  );

  BestMirror := ResourceRepoSelectBestMirrorFromCandidates(
    Result.CandidateMirrors,
    ATestLatency,
    3000,
    Result.CandidateLatencies
  );

  if BestMirror <> '' then
    Result.SelectedMirror := BestMirror;
end;

function ConvertResourceRepoMirrorsCore(
  const AParsedMirrors: TResourceRepoMirrorInfoArray
): TMirrorArray;
var
  Index: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AParsedMirrors));
  for Index := 0 to High(AParsedMirrors) do
  begin
    Result[Index].Name := AParsedMirrors[Index].Name;
    Result[Index].URL := AParsedMirrors[Index].URL;
    Result[Index].Region := AParsedMirrors[Index].Region;
    Result[Index].Priority := AParsedMirrors[Index].Priority;
  end;
end;

function ExecuteResourceRepoSelectBestMirrorSurfaceCore(
  const AManifestData: TJSONObject;
  const AConfiguredRegion, APrimaryURL: string;
  const AConfigMirrors: array of string;
  var ACachedBestMirror: string;
  var AMirrorCacheTime: TDateTime;
  var AMirrorLatencies: TResourceRepoMirrorLatencyStateArray;
  ACacheTTlHours: Integer;
  ACurrentTime: TDateTime;
  AEnsureManifestLoaded: TResourceRepoMirrorEnsureManifestLoaded;
  ADetectRegion: TResourceRepoMirrorRegionDetector;
  ATestLatency: TResourceRepoMirrorLatencyTestFunc;
  ALogFmt: TResourceRepoMirrorLogFmtProc
): string;
var
  Selection: TResourceRepoMirrorSelection;
  Index: Integer;
begin
  Result := APrimaryURL;

  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
    Exit;

  try
    Selection := SelectResourceRepoBestMirrorCore(
      AManifestData,
      AConfiguredRegion,
      APrimaryURL,
      AConfigMirrors,
      ACachedBestMirror,
      AMirrorCacheTime,
      ACacheTTlHours,
      ACurrentTime,
      ADetectRegion,
      ATestLatency
    );

    Result := Selection.SelectedMirror;

    SetLength(AMirrorLatencies, Length(Selection.CandidateMirrors));
    for Index := 0 to High(Selection.CandidateMirrors) do
    begin
      AMirrorLatencies[Index].URL := Selection.CandidateMirrors[Index];
      if Index <= High(Selection.CandidateLatencies) then
        AMirrorLatencies[Index].Latency := Selection.CandidateLatencies[Index]
      else
        AMirrorLatencies[Index].Latency := -1;
    end;

    if not Selection.UsedCache then
      ResourceRepoSetCachedMirror(Result, ACurrentTime, ACachedBestMirror, AMirrorCacheTime);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt('Error selecting best mirror: %s', [E.Message]);
      Result := APrimaryURL;
    end;
  end;
end;

function ExecuteResourceRepoGetMirrorsSurfaceCore(
  const AManifestData: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoMirrorEnsureManifestLoaded;
  AParseMirrors: TResourceRepoMirrorParseMirrorsFunc;
  ALogFmt: TResourceRepoMirrorLogFmtProc
): TMirrorArray;
var
  ParsedMirrors: TResourceRepoMirrorInfoArray;
begin
  Result := nil;

  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
    Exit;

  try
    if Assigned(AParseMirrors) then
      ParsedMirrors := AParseMirrors(AManifestData)
    else
      ParsedMirrors := ResourceRepoGetMirrorsFromManifest(AManifestData);
    Result := ConvertResourceRepoMirrorsCore(ParsedMirrors);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt('Error getting mirrors: %s', [E.Message]);
      SetLength(Result, 0);
    end;
  end;
end;

end.
