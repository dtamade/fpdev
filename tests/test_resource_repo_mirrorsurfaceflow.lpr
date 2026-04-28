program test_resource_repo_mirrorsurfaceflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils, fpjson,
  fpdev.resource.repo.types,
  fpdev.resource.repo.mirror,
  fpdev.resource.repo.mirrorflow;

type
  TMirrorSurfaceProbe = class
  private
    FLog: TStringList;
  public
    EnsureResult: Boolean;
    DetectRegionValue: string;
    RaiseInDetect: Boolean;
    RaiseInParse: Boolean;
    EnsureCalls: Integer;
    DetectCalls: Integer;
    ParseCalls: Integer;
    constructor Create;
    destructor Destroy; override;
    function EnsureManifestLoaded: Boolean;
    function DetectRegion: string;
    function TestLatency(const AURL: string; ATimeoutMS: Integer): Integer;
    function ParseMirrors(const AManifestData: TJSONObject): TResourceRepoMirrorInfoArray;
    procedure LogFmt(const AFormat: string; const AArgs: array of const);
    function LoggedContains(const AText: string): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TMirrorSurfaceProbe.Create;
begin
  inherited Create;
  FLog := TStringList.Create;
  EnsureResult := True;
  DetectRegionValue := 'china';
end;

destructor TMirrorSurfaceProbe.Destroy;
begin
  FLog.Free;
  inherited Destroy;
end;

function TMirrorSurfaceProbe.EnsureManifestLoaded: Boolean;
begin
  Inc(EnsureCalls);
  Result := EnsureResult;
end;

function TMirrorSurfaceProbe.DetectRegion: string;
begin
  Inc(DetectCalls);
  if RaiseInDetect then
    raise Exception.Create('detect failed');
  Result := DetectRegionValue;
end;

function TMirrorSurfaceProbe.TestLatency(const AURL: string; ATimeoutMS: Integer): Integer;
begin
  if ATimeoutMS < 0 then;
  if Pos('cn.mirror', AURL) > 0 then
    Result := 20
  else if Pos('eu.mirror', AURL) > 0 then
    Result := 80
  else if Pos('primary', AURL) > 0 then
    Result := 200
  else
    Result := 120;
end;

function TMirrorSurfaceProbe.ParseMirrors(const AManifestData: TJSONObject): TResourceRepoMirrorInfoArray;
begin
  Inc(ParseCalls);
  if RaiseInParse then
    raise Exception.Create('parse failed');
  Result := ResourceRepoGetMirrorsFromManifest(AManifestData);
end;

procedure TMirrorSurfaceProbe.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  FLog.Add(Format(AFormat, AArgs));
end;

function TMirrorSurfaceProbe.LoggedContains(const AText: string): Boolean;
begin
  Result := Pos(AText, FLog.Text) > 0;
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', AName);
    Inc(PassCount);
  end
  else
  begin
    WriteLn('[FAIL] ', AName, ': ', AReason);
    Inc(FailCount);
  end;
end;

function BuildManifest: TJSONObject;
var
  RepoObj, Mirror1, Mirror2: TJSONObject;
  Mirrors: TJSONArray;
begin
  Result := TJSONObject.Create;
  RepoObj := TJSONObject.Create;
  Mirrors := TJSONArray.Create;

  Mirror1 := TJSONObject.Create;
  Mirror1.Add('name', 'CN Mirror');
  Mirror1.Add('url', 'https://cn.mirror.example/repo.git');
  Mirror1.Add('region', 'china');
  Mirror1.Add('priority', 10);
  Mirrors.Add(Mirror1);

  Mirror2 := TJSONObject.Create;
  Mirror2.Add('name', 'EU Mirror');
  Mirror2.Add('url', 'https://eu.mirror.example/repo.git');
  Mirror2.Add('region', 'europe');
  Mirror2.Add('priority', 20);
  Mirrors.Add(Mirror2);

  RepoObj.Add('mirrors', Mirrors);
  Result.Add('repository', RepoObj);
end;

procedure TestSelectBestMirrorSurfaceCacheHit;
var
  Probe: TMirrorSurfaceProbe;
  Manifest: TJSONObject;
  CachedBestMirror: string;
  MirrorCacheTime: TDateTime;
  CurrentTime: TDateTime;
  MirrorStates: TResourceRepoMirrorLatencyStateArray;
  Selected: string;
begin
  Probe := TMirrorSurfaceProbe.Create;
  Manifest := BuildManifest;
  try
    CachedBestMirror := 'https://cached.example/repo.git';
    CurrentTime := EncodeDate(2026, 4, 14) + EncodeTime(10, 0, 0, 0);
    MirrorCacheTime := IncMinute(CurrentTime, -10);
    SetLength(MirrorStates, 1);
    MirrorStates[0].URL := 'keep://existing';
    MirrorStates[0].Latency := 999;

    Selected := ExecuteResourceRepoSelectBestMirrorSurfaceCore(
      Manifest,
      '',
      'https://primary.example/repo.git',
      [],
      CachedBestMirror,
      MirrorCacheTime,
      MirrorStates,
      1,
      CurrentTime,
      @Probe.EnsureManifestLoaded,
      @Probe.DetectRegion,
      @Probe.TestLatency,
      @Probe.LogFmt
    );

    Check('mirror surface cache hit returns cached mirror',
      Selected = 'https://cached.example/repo.git', Selected);
    Check('mirror surface cache hit still ensures manifest',
      Probe.EnsureCalls = 1, IntToStr(Probe.EnsureCalls));
    Check('mirror surface cache hit skips region detection',
      Probe.DetectCalls = 0, IntToStr(Probe.DetectCalls));
    Check('mirror surface cache hit clears stale latency state',
      Length(MirrorStates) = 0, IntToStr(Length(MirrorStates)));
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

procedure TestSelectBestMirrorSurfaceRefreshesLatencyState;
var
  Probe: TMirrorSurfaceProbe;
  Manifest: TJSONObject;
  CachedBestMirror: string;
  MirrorCacheTime: TDateTime;
  CurrentTime: TDateTime;
  MirrorStates: TResourceRepoMirrorLatencyStateArray;
  Selected: string;
begin
  Probe := TMirrorSurfaceProbe.Create;
  Manifest := BuildManifest;
  try
    CachedBestMirror := '';
    MirrorCacheTime := 0;
    CurrentTime := EncodeDate(2026, 4, 14) + EncodeTime(11, 30, 0, 0);

    Selected := ExecuteResourceRepoSelectBestMirrorSurfaceCore(
      Manifest,
      '',
      'https://primary.example/repo.git',
      [],
      CachedBestMirror,
      MirrorCacheTime,
      MirrorStates,
      1,
      CurrentTime,
      @Probe.EnsureManifestLoaded,
      @Probe.DetectRegion,
      @Probe.TestLatency,
      @Probe.LogFmt
    );

    Check('mirror surface fresh selection picks lowest latency mirror',
      Selected = 'https://cn.mirror.example/repo.git', Selected);
    Check('mirror surface fresh selection updates cache url',
      CachedBestMirror = Selected, CachedBestMirror);
    Check('mirror surface fresh selection updates cache time',
      MirrorCacheTime = CurrentTime, DateTimeToStr(MirrorCacheTime));
    Check('mirror surface fresh selection records all candidate states',
      Length(MirrorStates) = 2, IntToStr(Length(MirrorStates)));
    Check('mirror surface fresh selection records first candidate latency',
      (Length(MirrorStates) > 0) and
      (MirrorStates[0].URL = 'https://cn.mirror.example/repo.git') and
      (MirrorStates[0].Latency = 20),
      IntToStr(Length(MirrorStates)));
    Check('mirror surface fresh selection records second candidate fallback latency',
      (Length(MirrorStates) > 1) and
      (MirrorStates[1].URL = 'https://primary.example/repo.git') and
      (MirrorStates[1].Latency = 200),
      IntToStr(Length(MirrorStates)));
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

procedure TestGetMirrorsSurfaceHappyPath;
var
  Probe: TMirrorSurfaceProbe;
  Manifest: TJSONObject;
  Mirrors: TMirrorArray;
begin
  Probe := TMirrorSurfaceProbe.Create;
  Manifest := BuildManifest;
  try
    Mirrors := ExecuteResourceRepoGetMirrorsSurfaceCore(
      Manifest,
      @Probe.EnsureManifestLoaded,
      @Probe.ParseMirrors,
      @Probe.LogFmt
    );

    Check('get mirrors surface returns manifest mirrors', Length(Mirrors) = 2,
      IntToStr(Length(Mirrors)));
    Check('get mirrors surface maps mirror name', Mirrors[0].Name = 'CN Mirror',
      Mirrors[0].Name);
    Check('get mirrors surface maps mirror url', Mirrors[1].URL = 'https://eu.mirror.example/repo.git',
      Mirrors[1].URL);
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

procedure TestSelectBestMirrorSurfaceFallsBackOnException;
var
  Probe: TMirrorSurfaceProbe;
  Manifest: TJSONObject;
  CachedBestMirror: string;
  MirrorCacheTime: TDateTime;
  CurrentTime: TDateTime;
  MirrorStates: TResourceRepoMirrorLatencyStateArray;
  Selected: string;
begin
  Probe := TMirrorSurfaceProbe.Create;
  Manifest := BuildManifest;
  try
    Probe.RaiseInDetect := True;
    CachedBestMirror := '';
    MirrorCacheTime := 0;
    CurrentTime := EncodeDate(2026, 4, 14) + EncodeTime(12, 0, 0, 0);

    Selected := ExecuteResourceRepoSelectBestMirrorSurfaceCore(
      Manifest,
      '',
      'https://primary.example/repo.git',
      [],
      CachedBestMirror,
      MirrorCacheTime,
      MirrorStates,
      1,
      CurrentTime,
      @Probe.EnsureManifestLoaded,
      @Probe.DetectRegion,
      @Probe.TestLatency,
      @Probe.LogFmt
    );

    Check('mirror surface exception fallback returns primary url',
      Selected = 'https://primary.example/repo.git', Selected);
    Check('mirror surface exception fallback keeps cache empty',
      CachedBestMirror = '', CachedBestMirror);
    Check('mirror surface exception fallback logs error',
      Probe.LoggedContains('Error selecting best mirror: detect failed'), '');
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

begin
  TestSelectBestMirrorSurfaceCacheHit;
  TestSelectBestMirrorSurfaceRefreshesLatencyState;
  TestGetMirrorsSurfaceHappyPath;
  TestSelectBestMirrorSurfaceFallsBackOnException;

  WriteLn;
  WriteLn('Passed: ', PassCount, ', Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
