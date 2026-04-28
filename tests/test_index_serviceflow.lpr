program test_index_serviceflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpjson, jsonparser,
  fpdev.index.serviceflow,
  fpdev.utils,
  test_temp_paths;

type
  TIndexFetchProbe = class
  public
    FailPrimary: Boolean;
    FailFallback: Boolean;
    Logs: TStringList;
    constructor Create;
    destructor Destroy; override;
    function Fetch(const AURL: string): TJSONObject;
    procedure Log(const AMsg: string);
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function ParseJSONObject(const AJSON: string): TJSONObject;
var
  Parser: TJSONParser;
begin
  Parser := TJSONParser.Create(AJSON, []);
  try
    Result := Parser.Parse as TJSONObject;
  finally
    Parser.Free;
  end;
end;

constructor TIndexFetchProbe.Create;
begin
  inherited Create;
  Logs := TStringList.Create;
end;

destructor TIndexFetchProbe.Destroy;
begin
  Logs.Free;
  inherited Destroy;
end;

function TIndexFetchProbe.Fetch(const AURL: string): TJSONObject;
begin
  if Pos('primary', AURL) > 0 then
  begin
    if FailPrimary then
      Exit(nil);
    Exit(ParseJSONObject(
      '{"repositories":{"bootstrap":{"name":"fpdev-bootstrap"}}}'
    ));
  end;

  if FailFallback then
    Exit(nil);

  Result := ParseJSONObject(
    '{"releases":{"3.2.2":{"platforms":{"linux-x86_64":{"url":"https://example.invalid/fpc.tar.xz","mirrors":["https://mirror.invalid/fpc.tar.xz"],"format":"tar.xz","sha256":"abc123","size":42,"layout":{"executable":"bin/fpc"}}}},"main":{"platforms":{"linux-x86_64":{"url":"https://example.invalid/main.tar.xz"}}}}}'
  );
end;

procedure TIndexFetchProbe.Log(const AMsg: string);
begin
  Logs.Add(AMsg);
end;

procedure TestRemoteSuccessWritesIndexCache;
var
  Probe: TIndexFetchProbe;
  CacheRoot: string;
  CachePath: string;
  UsedCache: Boolean;
  RemoteSucceeded: Boolean;
  Data: TJSONObject;
  Content: string;
begin
  Probe := TIndexFetchProbe.Create;
  CacheRoot := CreateUniqueTempDir('test_index_serviceflow_remote') + PathDelim + 'cache';
  CachePath := BuildIndexCachePathCore(CacheRoot);
  try
    Data := LoadRemoteJSONWithCacheCore(
      'index',
      'https://primary.example/index.json',
      'https://fallback.example/index.json',
      CachePath,
      @Probe.Fetch,
      @Probe.Log,
      UsedCache,
      RemoteSucceeded
    );
    try
      Content := ReadAllTextIfExists(CachePath);
      Check('remote success returns JSON object', Assigned(Data), 'expected JSON payload');
      Check('remote success does not use cache', not UsedCache, 'used cache unexpectedly');
      Check('remote success marks remote loaded', RemoteSucceeded, 'remote not marked');
      Check('remote success writes cache file', FileExists(CachePath), CachePath);
      Check('remote success cache contains bootstrap repo',
        Pos('fpdev-bootstrap', Content) > 0, Content);
    finally
      Data.Free;
    end;
  finally
    CleanupTempDir(ExtractFileDir(CacheRoot));
    Probe.Free;
  end;
end;

procedure TestRemoteFailureUsesCachedIndex;
var
  Probe: TIndexFetchProbe;
  TempRoot: string;
  CachePath: string;
  UsedCache: Boolean;
  RemoteSucceeded: Boolean;
  Data: TJSONObject;
begin
  Probe := TIndexFetchProbe.Create;
  try
    Probe.FailPrimary := True;
    Probe.FailFallback := True;
    TempRoot := CreateUniqueTempDir('test_index_serviceflow_cache');
    CachePath := BuildIndexCachePathCore(TempRoot + PathDelim + 'cache');
    ForceDirectories(ExtractFileDir(CachePath));
    SafeWriteAllText(CachePath,
      '{"repositories":{"bootstrap":{"name":"cached-bootstrap"}}}');

    Data := LoadRemoteJSONWithCacheCore(
      'index',
      'https://primary.example/index.json',
      'https://fallback.example/index.json',
      CachePath,
      @Probe.Fetch,
      @Probe.Log,
      UsedCache,
      RemoteSucceeded
    );
    try
      Check('cache fallback returns JSON object', Assigned(Data), 'expected cached payload');
      Check('cache fallback marks used cache', UsedCache, 'cache flag missing');
      Check('cache fallback keeps remote flag false', not RemoteSucceeded, 'remote flag incorrect');
      Check('cache fallback loads cached bootstrap name',
        Assigned(Data) and
        (Data.Objects['repositories'].Objects['bootstrap'].Get('name', '') = 'cached-bootstrap'),
        Data.AsJSON);
      Check('cache fallback logs warning',
        Pos('Warning:', Probe.Logs.Text) > 0, Probe.Logs.Text);
      Check('cache fallback mentions cached index path',
        Pos('using cached index', LowerCase(Probe.Logs.Text)) > 0, Probe.Logs.Text);
    finally
      Data.Free;
      CleanupTempDir(TempRoot);
    end;
  finally
    Probe.Free;
  end;
end;

procedure TestRemoteFailureWithoutCacheReturnsNil;
var
  Probe: TIndexFetchProbe;
  TempRoot: string;
  CachePath: string;
  UsedCache: Boolean;
  RemoteSucceeded: Boolean;
  Data: TJSONObject;
begin
  Probe := TIndexFetchProbe.Create;
  try
    Probe.FailPrimary := True;
    Probe.FailFallback := True;
    TempRoot := CreateUniqueTempDir('test_index_serviceflow_miss');
    CachePath := BuildIndexCachePathCore(TempRoot + PathDelim + 'cache');

    Data := LoadRemoteJSONWithCacheCore(
      'index',
      'https://primary.example/index.json',
      'https://fallback.example/index.json',
      CachePath,
      @Probe.Fetch,
      @Probe.Log,
      UsedCache,
      RemoteSucceeded
    );
    try
      Check('remote and cache miss returns nil', not Assigned(Data), 'expected nil payload');
      Check('remote and cache miss keeps used cache false', not UsedCache, 'cache flag incorrect');
      Check('remote and cache miss keeps remote flag false', not RemoteSucceeded, 'remote flag incorrect');
      Check('remote and cache miss logs missing cache warning',
        Pos('no cached index is available', LowerCase(Probe.Logs.Text)) > 0,
        Probe.Logs.Text);
    finally
      CleanupTempDir(TempRoot);
    end;
  finally
    Probe.Free;
  end;
end;

procedure TestManifestHelpers;
var
  Probe: TIndexFetchProbe;
  Manifest: TJSONObject;
  Versions: TStringArray;
  Mirrors: TStringArray;
  URL: string;
  Format: string;
  SHA256: string;
  Executable: string;
  Size: Int64;
  OK: Boolean;
begin
  Probe := TIndexFetchProbe.Create;
  try
    Manifest := Probe.Fetch('https://fallback.example/manifest.json');
    try
      Versions := BuildManifestVersionsCore(Manifest);
      Check('manifest versions helper returns 2 versions',
        Length(Versions) = 2, IntToStr(Length(Versions)));
      Check('manifest versions helper keeps stable version',
        (Length(Versions) >= 1) and (Pos('3.2.2', Versions[0]) > 0),
        IntToStr(Length(Versions)));

      OK := ResolveManifestDownloadCore(
        Manifest,
        '3.2.2',
        'linux-x86_64',
        URL,
        Mirrors,
        Format,
        SHA256,
        Executable,
        Size
      );

      Check('manifest download helper resolves known platform', OK, 'expected known platform');
      Check('manifest download helper returns URL',
        URL = 'https://example.invalid/fpc.tar.xz', URL);
      Check('manifest download helper returns mirror list',
        (Length(Mirrors) = 1) and (Mirrors[0] = 'https://mirror.invalid/fpc.tar.xz'),
        IntToStr(Length(Mirrors)));
      Check('manifest download helper returns format', Format = 'tar.xz', Format);
      Check('manifest download helper returns sha256', SHA256 = 'abc123', SHA256);
      Check('manifest download helper returns executable layout',
        Executable = 'bin/fpc', Executable);
      Check('manifest download helper returns size', Size = 42, IntToStr(Size));
    finally
      Manifest.Free;
    end;
  finally
    Probe.Free;
  end;
end;

begin
  WriteLn('=== Index Serviceflow Tests ===');

  TestRemoteSuccessWritesIndexCache;
  TestRemoteFailureUsesCachedIndex;
  TestRemoteFailureWithoutCacheReturnsNil;
  TestManifestHelpers;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
