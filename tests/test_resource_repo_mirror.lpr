program test_resource_repo_mirror;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, fpjson, fpdev.resource.repo.mirror;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

{ --- TryGetCachedMirror tests --- }

procedure TestCachedMirrorValid;
var
  Cached: string;
  CacheTime, Now: TDateTime;
begin
  Now := EncodeDate(2026, 2, 9) + EncodeTime(14, 0, 0, 0);
  CacheTime := IncHour(Now, -1); // 1 hour ago

  Check(ResourceRepoTryGetCachedMirror('https://mirror1.com', CacheTime, 24, Now, Cached) = True,
        'CachedMirror: valid cache returns True');
  Check(Cached = 'https://mirror1.com',
        'CachedMirror: returns cached URL');
end;

procedure TestCachedMirrorExpired;
var
  Cached: string;
  CacheTime, Now: TDateTime;
begin
  Now := EncodeDate(2026, 2, 9) + EncodeTime(14, 0, 0, 0);
  CacheTime := IncHour(Now, -25); // 25 hours ago, TTL is 24

  Check(ResourceRepoTryGetCachedMirror('https://mirror1.com', CacheTime, 24, Now, Cached) = False,
        'CachedMirror: expired cache returns False');
  Check(Cached = '',
        'CachedMirror: expired returns empty');
end;

procedure TestCachedMirrorEmpty;
var
  Cached: string;
  Now: TDateTime;
begin
  Now := EncodeDate(2026, 2, 9);
  Check(ResourceRepoTryGetCachedMirror('', 0, 24, Now, Cached) = False,
        'CachedMirror: empty URL returns False');
end;

procedure TestCachedMirrorZeroCacheTime;
var
  Cached: string;
  Now: TDateTime;
begin
  Now := EncodeDate(2026, 2, 9);
  Check(ResourceRepoTryGetCachedMirror('https://mirror1.com', 0, 24, Now, Cached) = False,
        'CachedMirror: zero cache time returns False');
end;

{ --- SetCachedMirror tests --- }

procedure TestSetCachedMirror;
var
  CachedURL: string;
  CacheTime, Now: TDateTime;
begin
  CachedURL := '';
  CacheTime := 0;
  Now := EncodeDate(2026, 2, 9) + EncodeTime(15, 0, 0, 0);

  ResourceRepoSetCachedMirror('https://new-mirror.com', Now, CachedURL, CacheTime);

  Check(CachedURL = 'https://new-mirror.com',
        'SetCachedMirror: URL updated');
  Check(CacheTime = Now,
        'SetCachedMirror: cache time updated');
end;

{ --- GetMirrorsFromManifest tests --- }

procedure TestGetMirrorsFromManifestNil;
var
  Mirrors: TResourceRepoMirrorInfoArray;
begin
  Mirrors := ResourceRepoGetMirrorsFromManifest(nil);
  Check(Length(Mirrors) = 0, 'GetMirrors: nil manifest -> empty');
end;

procedure TestGetMirrorsFromManifestNoRepository;
var
  Manifest: TJSONObject;
  Mirrors: TResourceRepoMirrorInfoArray;
begin
  Manifest := TJSONObject.Create;
  try
    Manifest.Add('other', 'value');
    Mirrors := ResourceRepoGetMirrorsFromManifest(Manifest);
    Check(Length(Mirrors) = 0, 'GetMirrors: no repository key -> empty');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetMirrorsFromManifestWithData;
var
  Manifest, Repo, Mirror1, Mirror2: TJSONObject;
  MirrorsArr: TJSONArray;
  Mirrors: TResourceRepoMirrorInfoArray;
begin
  Manifest := TJSONObject.Create;
  try
    Repo := TJSONObject.Create;
    MirrorsArr := TJSONArray.Create;

    Mirror1 := TJSONObject.Create;
    Mirror1.Add('name', 'Mirror CN');
    Mirror1.Add('url', 'https://cn.mirror.com');
    Mirror1.Add('region', 'china');
    Mirror1.Add('priority', 10);
    MirrorsArr.Add(Mirror1);

    Mirror2 := TJSONObject.Create;
    Mirror2.Add('name', 'Mirror EU');
    Mirror2.Add('url', 'https://eu.mirror.com');
    Mirror2.Add('region', 'europe');
    Mirror2.Add('priority', 20);
    MirrorsArr.Add(Mirror2);

    Repo.Add('mirrors', MirrorsArr);
    Manifest.Add('repository', Repo);

    Mirrors := ResourceRepoGetMirrorsFromManifest(Manifest);
    Check(Length(Mirrors) = 2, 'GetMirrors: returns 2 mirrors');
    Check(Mirrors[0].Name = 'Mirror CN', 'GetMirrors: first name correct');
    Check(Mirrors[0].URL = 'https://cn.mirror.com', 'GetMirrors: first URL correct');
    Check(Mirrors[0].Region = 'china', 'GetMirrors: first region correct');
    Check(Mirrors[0].Priority = 10, 'GetMirrors: first priority correct');
    Check(Mirrors[1].Name = 'Mirror EU', 'GetMirrors: second name correct');
    Check(Mirrors[1].Region = 'europe', 'GetMirrors: second region correct');
  finally
    Manifest.Free;
  end;
end;

{ --- BuildCandidateMirrors tests --- }

procedure TestBuildCandidatesNilManifest;
var
  Candidates: TStringArray;
begin
  Candidates := ResourceRepoBuildCandidateMirrors(nil, 'us', 'https://primary.com', []);
  // Should still include primary URL
  Check(Length(Candidates) >= 1, 'BuildCandidates: nil manifest includes primary');
  Check(Candidates[0] = 'https://primary.com', 'BuildCandidates: primary URL present');
end;

procedure TestBuildCandidatesWithRegionMatch;
var
  Manifest, Repo, Mirror1, Mirror2: TJSONObject;
  MirrorsArr: TJSONArray;
  Candidates: TStringArray;
  i: Integer;
  HasCN: Boolean;
begin
  Manifest := TJSONObject.Create;
  try
    Repo := TJSONObject.Create;
    MirrorsArr := TJSONArray.Create;

    Mirror1 := TJSONObject.Create;
    Mirror1.Add('url', 'https://cn.mirror.com');
    Mirror1.Add('region', 'china');
    MirrorsArr.Add(Mirror1);

    Mirror2 := TJSONObject.Create;
    Mirror2.Add('url', 'https://eu.mirror.com');
    Mirror2.Add('region', 'europe');
    MirrorsArr.Add(Mirror2);

    Repo.Add('mirrors', MirrorsArr);
    Manifest.Add('repository', Repo);

    Candidates := ResourceRepoBuildCandidateMirrors(Manifest, 'china', 'https://primary.com', []);

    // Should include china mirror + primary
    HasCN := False;
    for i := 0 to High(Candidates) do
      if Candidates[i] = 'https://cn.mirror.com' then
        HasCN := True;

    Check(HasCN, 'BuildCandidates: includes region-matched mirror');
    Check(Candidates[High(Candidates) - 0] = 'https://primary.com',
          'BuildCandidates: primary URL at end');
  finally
    Manifest.Free;
  end;
end;

procedure TestBuildCandidatesWithConfigMirrors;
var
  Candidates: TStringArray;
begin
  Candidates := ResourceRepoBuildCandidateMirrors(nil, 'us', 'https://primary.com',
    ['https://custom1.com', 'https://custom2.com']);

  Check(Length(Candidates) = 3, 'BuildCandidates: primary + 2 config mirrors');
end;

{ --- SelectBestMirrorFromCandidates tests --- }

type
  TMockHelper = class
    function TestLatency(const AURL: string; {%H-}ATimeoutMS: Integer): Integer;
  end;

function TMockHelper.TestLatency(const AURL: string; {%H-}ATimeoutMS: Integer): Integer;
begin
  if Pos('fast', AURL) > 0 then
    Result := 50
  else if Pos('medium', AURL) > 0 then
    Result := 200
  else if Pos('slow', AURL) > 0 then
    Result := 500
  else
    Result := -1; // unreachable
end;

procedure TestSelectBestMirror;
var
  Candidates: array[0..2] of string;
  Latencies: TResourceRepoMirrorLatencyArray;
  Best: string;
  Helper: TMockHelper;
begin
  Candidates[0] := 'https://slow.mirror.com';
  Candidates[1] := 'https://fast.mirror.com';
  Candidates[2] := 'https://medium.mirror.com';

  Helper := TMockHelper.Create;
  try
    Best := ResourceRepoSelectBestMirrorFromCandidates(Candidates,
      @Helper.TestLatency, 5000, Latencies);

    Check(Best = 'https://fast.mirror.com', 'SelectBest: picks lowest latency');
    Check(Length(Latencies) = 3, 'SelectBest: returns all latencies');
    Check(Latencies[0] = 500, 'SelectBest: slow latency = 500');
    Check(Latencies[1] = 50, 'SelectBest: fast latency = 50');
    Check(Latencies[2] = 200, 'SelectBest: medium latency = 200');
  finally
    Helper.Free;
  end;
end;

procedure TestSelectBestMirrorAllFail;
var
  Candidates: array[0..1] of string;
  Latencies: TResourceRepoMirrorLatencyArray;
  Best: string;
  Helper: TMockHelper;
begin
  Candidates[0] := 'https://unreachable1.com';
  Candidates[1] := 'https://unreachable2.com';

  Helper := TMockHelper.Create;
  try
    Best := ResourceRepoSelectBestMirrorFromCandidates(Candidates,
      @Helper.TestLatency, 5000, Latencies);

    Check(Best = '', 'SelectBest: all fail -> empty');
    Check(Latencies[0] = -1, 'SelectBest: first latency = -1');
    Check(Latencies[1] = -1, 'SelectBest: second latency = -1');
  finally
    Helper.Free;
  end;
end;

procedure TestSelectBestMirrorNilCallback;
var
  Candidates: array[0..0] of string;
  Latencies: TResourceRepoMirrorLatencyArray;
  Best: string;
begin
  Candidates[0] := 'https://example.com';

  Best := ResourceRepoSelectBestMirrorFromCandidates(Candidates,
    nil, 5000, Latencies);

  Check(Best = '', 'SelectBest: nil callback -> empty');
  Check(Latencies[0] = -1, 'SelectBest: nil callback latency = -1');
end;

begin
  WriteLn('=== Resource Repo Mirror Unit Tests ===');
  WriteLn;

  TestCachedMirrorValid;
  TestCachedMirrorExpired;
  TestCachedMirrorEmpty;
  TestCachedMirrorZeroCacheTime;
  TestSetCachedMirror;
  TestGetMirrorsFromManifestNil;
  TestGetMirrorsFromManifestNoRepository;
  TestGetMirrorsFromManifestWithData;
  TestBuildCandidatesNilManifest;
  TestBuildCandidatesWithRegionMatch;
  TestBuildCandidatesWithConfigMirrors;
  TestSelectBestMirror;
  TestSelectBestMirrorAllFail;
  TestSelectBestMirrorNilCallback;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
