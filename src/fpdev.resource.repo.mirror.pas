unit fpdev.resource.repo.mirror;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson;

type
  TResourceRepoMirrorLogProc = procedure(const AMsg: string) of object;

  TResourceRepoMirrorInfo = record
    Name: string;
    URL: string;
    Region: string;
    Priority: Integer;
  end;

  TResourceRepoMirrorInfoArray = array of TResourceRepoMirrorInfo;
  TResourceRepoMirrorLatencyArray = array of Integer;
  TResourceRepoMirrorLatencyTestFunc = function(const AURL: string;
    ATimeoutMS: Integer): Integer of object;

function ResourceRepoDetectUserRegion(const ALog: TResourceRepoMirrorLogProc): string;
function ResourceRepoTestMirrorLatency(const AURL: string; ATimeoutMS: Integer;
  const ALog: TResourceRepoMirrorLogProc): Integer;
function ResourceRepoBuildCandidateMirrors(const AManifestData: TJSONObject;
  const ARegion, APrimaryURL: string; const AConfigMirrors: array of string): SysUtils.TStringArray;
function ResourceRepoGetMirrorsFromManifest(const AManifestData: TJSONObject): TResourceRepoMirrorInfoArray;
function ResourceRepoSelectBestMirrorFromCandidates(const ACandidateMirrors: array of string;
  const ATestLatency: TResourceRepoMirrorLatencyTestFunc; ATimeoutMS: Integer;
  out ALatencies: TResourceRepoMirrorLatencyArray): string;
function ResourceRepoTryGetCachedMirror(const ACachedBestMirror: string; AMirrorCacheTime: TDateTime;
  ACacheTTlHours: Integer; ACurrentTime: TDateTime; out ACachedMirror: string): Boolean;
procedure ResourceRepoSetCachedMirror(const ASelectedMirror: string; ACurrentTime: TDateTime;
  var ACachedBestMirror: string; var AMirrorCacheTime: TDateTime);

implementation

uses
  Classes, DateUtils, fpdev.utils.process;

function ResourceRepoDetectUserRegion(const ALog: TResourceRepoMirrorLogProc): string;
var
  TZ: string;
begin
  Result := 'us';

  {$IFDEF MSWINDOWS}
  TZ := GetEnvironmentVariable('TZ');
  if TZ = '' then
    TZ := GetEnvironmentVariable('LANG');
  {$ELSE}
  TZ := GetEnvironmentVariable('TZ');
  if TZ = '' then
  begin
    if FileExists('/etc/timezone') then
    begin
      try
        with TStringList.Create do
        try
          LoadFromFile('/etc/timezone');
          if Count > 0 then
            TZ := Strings[0];
        finally
          Free;
        end;
      except
        on E: Exception do
        begin
          if Assigned(ALog) then
            ALog('Error detecting timezone: ' + E.Message);
          TZ := '';
        end;
      end;
    end;
  end;
  {$ENDIF}

  if (Pos('Asia/Shanghai', TZ) > 0) or
     (Pos('Asia/Beijing', TZ) > 0) or
     (Pos('Asia/Chongqing', TZ) > 0) or
     (Pos('Asia/Hong_Kong', TZ) > 0) or
     (Pos('zh_CN', GetEnvironmentVariable('LANG')) > 0) or
     (Pos('zh_TW', GetEnvironmentVariable('LANG')) > 0) then
  begin
    Result := 'china';
    Exit;
  end;

  if Pos('Europe/', TZ) > 0 then
  begin
    Result := 'europe';
    Exit;
  end;
end;

function ResourceRepoTestMirrorLatency(const AURL: string; ATimeoutMS: Integer;
  const ALog: TResourceRepoMirrorLogProc): Integer;
var
  LResult: TProcessResult;
  TestURL: string;
begin
  Result := -1;

  TestURL := AURL;
  if Pos('.git', TestURL) > 0 then
    TestURL := Copy(TestURL, 1, Pos('.git', TestURL) - 1);

  try
    LResult := TProcessExecutor.Execute('curl',
      ['-s', '-o', '/dev/null', '-w', '%{time_total}',
       '--connect-timeout', IntToStr(ATimeoutMS div 1000),
       '--max-time', IntToStr(ATimeoutMS div 1000),
       '-I', TestURL], '');

    if LResult.Success then
      Result := Round(StrToFloatDef(Trim(LResult.StdOut), 999) * 1000);
  except
    on E: Exception do
    begin
      if Assigned(ALog) then
        ALog('Error testing mirror latency: ' + E.Message);
      Result := -1;
    end;
  end;
end;

function ResourceRepoBuildCandidateMirrors(const AManifestData: TJSONObject;
  const ARegion, APrimaryURL: string; const AConfigMirrors: array of string): SysUtils.TStringArray;
var
  RepositoryObj: TJSONObject;
  Mirrors: TJSONArray;
  Mirror: TJSONObject;
  MirrorRegion: string;
  MirrorURL: string;
  i: Integer;
  CandidateCount: Integer;
begin
  Result := nil;
  CandidateCount := 0;

  RepositoryObj := nil;
  Mirrors := nil;

  if Assigned(AManifestData) and (AManifestData.Find('repository') <> nil) then
    RepositoryObj := TJSONObject(AManifestData.Find('repository'));

  if Assigned(RepositoryObj) and (RepositoryObj.Find('mirrors') <> nil) then
    Mirrors := RepositoryObj.Arrays['mirrors'];

  if Assigned(Mirrors) then
  begin
    for i := 0 to Mirrors.Count - 1 do
    begin
      Mirror := Mirrors.Objects[i];
      MirrorRegion := Mirror.Get('region', '');
      MirrorURL := Mirror.Get('url', '');

      if (MirrorRegion = ARegion) or (ARegion = '') then
      begin
        SetLength(Result, CandidateCount + 1);
        Result[CandidateCount] := MirrorURL;
        Inc(CandidateCount);
      end;
    end;

    if CandidateCount = 0 then
    begin
      for i := 0 to Mirrors.Count - 1 do
      begin
        Mirror := Mirrors.Objects[i];
        MirrorURL := Mirror.Get('url', '');
        SetLength(Result, CandidateCount + 1);
        Result[CandidateCount] := MirrorURL;
        Inc(CandidateCount);
      end;
    end;
  end;

  SetLength(Result, CandidateCount + 1);
  Result[CandidateCount] := APrimaryURL;
  Inc(CandidateCount);

  for i := Low(AConfigMirrors) to High(AConfigMirrors) do
  begin
    SetLength(Result, CandidateCount + 1);
    Result[CandidateCount] := AConfigMirrors[i];
    Inc(CandidateCount);
  end;
end;

function ResourceRepoGetMirrorsFromManifest(const AManifestData: TJSONObject): TResourceRepoMirrorInfoArray;
var
  RepositoryObj: TJSONObject;
  Mirrors: TJSONArray;
  Mirror: TJSONObject;
  i: Integer;
begin
  Result := nil;

  if not Assigned(AManifestData) then
    Exit;

  RepositoryObj := nil;
  Mirrors := nil;

  if AManifestData.Find('repository') <> nil then
    RepositoryObj := TJSONObject(AManifestData.Find('repository'));

  if Assigned(RepositoryObj) and (RepositoryObj.Find('mirrors') <> nil) then
    Mirrors := RepositoryObj.Arrays['mirrors'];

  if not Assigned(Mirrors) then
    Exit;

  SetLength(Result, Mirrors.Count);
  for i := 0 to Mirrors.Count - 1 do
  begin
    Mirror := Mirrors.Objects[i];
    Result[i].Name := Mirror.Get('name', '');
    Result[i].URL := Mirror.Get('url', '');
    Result[i].Region := Mirror.Get('region', '');
    Result[i].Priority := Mirror.Get('priority', 100);
  end;
end;

function ResourceRepoSelectBestMirrorFromCandidates(const ACandidateMirrors: array of string;
  const ATestLatency: TResourceRepoMirrorLatencyTestFunc; ATimeoutMS: Integer;
  out ALatencies: TResourceRepoMirrorLatencyArray): string;
var
  i: Integer;
  Latency: Integer;
  BestLatency: Integer;
begin
  ALatencies := nil;
  Result := '';
  SetLength(ALatencies, Length(ACandidateMirrors));
  BestLatency := MaxInt;

  for i := Low(ACandidateMirrors) to High(ACandidateMirrors) do
  begin
    Latency := -1;
    if Assigned(ATestLatency) then
      Latency := ATestLatency(ACandidateMirrors[i], ATimeoutMS);
    ALatencies[i] := Latency;

    if (Latency > 0) and (Latency < BestLatency) then
    begin
      BestLatency := Latency;
      Result := ACandidateMirrors[i];
    end;
  end;
end;

function ResourceRepoTryGetCachedMirror(const ACachedBestMirror: string; AMirrorCacheTime: TDateTime;
  ACacheTTlHours: Integer; ACurrentTime: TDateTime; out ACachedMirror: string): Boolean;
begin
  ACachedMirror := '';
  Result := False;

  if (ACachedBestMirror = '') or (AMirrorCacheTime <= 0) then
    Exit;

  if HoursBetween(ACurrentTime, AMirrorCacheTime) >= ACacheTTlHours then
    Exit;

  ACachedMirror := ACachedBestMirror;
  Result := True;
end;

procedure ResourceRepoSetCachedMirror(const ASelectedMirror: string; ACurrentTime: TDateTime;
  var ACachedBestMirror: string; var AMirrorCacheTime: TDateTime);
begin
  ACachedBestMirror := ASelectedMirror;
  AMirrorCacheTime := ACurrentTime;
end;

end.
