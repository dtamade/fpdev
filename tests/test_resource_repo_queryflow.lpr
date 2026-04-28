program test_resource_repo_queryflow;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson,
  fpdev.resource.repo.types,
  fpdev.resource.repo.queryflow;

type
  TQueryFlowProbe = class
  public
    EnsureResult: Boolean;
    EnsureCalls: Integer;
    LogCalls: Integer;
    LastLog: string;
    function EnsureManifestLoaded: Boolean;
    procedure LogFmt(const AFormat: string; const AArgs: array of const);
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  BoolQueryCalls: Integer = 0;
  ArrayQueryCalls: Integer = 0;

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

function TQueryFlowProbe.EnsureManifestLoaded: Boolean;
begin
  Inc(EnsureCalls);
  Result := EnsureResult;
end;

procedure TQueryFlowProbe.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  Inc(LogCalls);
  LastLog := Format(AFormat, AArgs);
end;

function DummyBooleanQuery(const AManifest: TJSONObject;
  const AArg1, AArg2: string): Boolean;
begin
  Inc(BoolQueryCalls);
  if AArg2 = '' then;
  Result := Assigned(AManifest) and (AArg1 = '3.2.2');
end;

function RaisingPlatformInfoQuery(const AManifest: TJSONObject;
  const AArg1, AArg2: string; out AInfo: TPlatformInfo): Boolean;
begin
  if Assigned(AManifest) then;
  if AArg1 = '' then;
  if AArg2 = '' then;
  Result := False;
  AInfo := EmptyPlatformInfo;
  raise Exception.Create('platform boom');
end;

function DummyCrossInfoQuery(const AManifest: TJSONObject;
  const AArg1, AArg2: string; out AInfo: TCrossToolchainInfo): Boolean;
begin
  if not Assigned(AManifest) then;
  AInfo := EmptyCrossToolchainInfo;
  AInfo.TargetName := AArg1;
  AInfo.DisplayName := 'Cross ' + AArg1;
  AInfo.CPU := 'arm';
  AInfo.OS := 'linux';
  AInfo.BinutilsPrefix := AArg2;
  Result := True;
end;

function DummyStringQuery(const AManifest: TJSONObject; const AArg: string): string;
begin
  if Assigned(AManifest) then;
  Result := 'manifest:' + AArg;
end;

function DummyFallbackStringQuery(const AManifest: TJSONObject; const AArg: string): string;
begin
  if Assigned(AManifest) then;
  Result := 'fallback:' + AArg;
end;

function RaisingStringArrayQuery(const AManifest: TJSONObject): TStringArray;
begin
  if Assigned(AManifest) then;
  Inc(ArrayQueryCalls);
  Result := nil;
  raise Exception.Create('array boom');
end;

procedure TestBooleanQueryReturnsFalseWhenManifestUnavailable;
var
  Probe: TQueryFlowProbe;
begin
  Probe := TQueryFlowProbe.Create;
  try
    Probe.EnsureResult := False;
    BoolQueryCalls := 0;

    Check('bool query returns false when manifest unavailable',
      not ExecuteResourceRepoBooleanQueryCore(nil, @Probe.EnsureManifestLoaded,
        @Probe.LogFmt, 'Error checking bootstrap compiler: %s',
        '3.2.2', 'linux-x86_64', @DummyBooleanQuery),
      'expected false');
    Check('bool query still calls ensure once',
      Probe.EnsureCalls = 1,
      'ensure=' + IntToStr(Probe.EnsureCalls));
    Check('bool query skips low-level query when manifest unavailable',
      BoolQueryCalls = 0,
      'calls=' + IntToStr(BoolQueryCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestPlatformInfoQueryLogsExceptionAndClearsResult;
var
  Probe: TQueryFlowProbe;
  Manifest: TJSONObject;
  Info: TPlatformInfo;
begin
  Probe := TQueryFlowProbe.Create;
  Manifest := TJSONObject.Create;
  try
    Probe.EnsureResult := True;

    Check('platform info query returns false on exception',
      not ExecuteResourceRepoPlatformInfoQueryCore(Manifest, @Probe.EnsureManifestLoaded,
        @Probe.LogFmt, 'Error getting bootstrap info: %s',
        '3.2.2', 'linux-x86_64', Info, @RaisingPlatformInfoQuery),
      'expected false');
    Check('platform info query logs exception text',
      Pos('platform boom', Probe.LastLog) > 0,
      Probe.LastLog);
    Check('platform info query clears output info on failure',
      (Info.URL = '') and (Info.Path = '') and (Info.Executable = ''),
      'info should be empty');
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

procedure TestStringQueryFallsBackWhenManifestMissing;
var
  Probe: TQueryFlowProbe;
  Value: string;
begin
  Probe := TQueryFlowProbe.Create;
  try
    Probe.EnsureResult := False;

    Value := ExecuteResourceRepoStringQueryCore(nil, @Probe.EnsureManifestLoaded,
      @Probe.LogFmt, 'Error getting bootstrap version from manifest: %s',
      '3.3.1', @DummyStringQuery, @DummyFallbackStringQuery);

    Check('string query falls back when manifest missing',
      Value = 'fallback:3.3.1',
      'value=' + Value);
    Check('string query does not log on manifest miss fallback',
      Probe.LogCalls = 0,
      'log calls=' + IntToStr(Probe.LogCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestStringArrayQueryLogsExceptionAndReturnsEmpty;
var
  Probe: TQueryFlowProbe;
  Manifest: TJSONObject;
  Values: TStringArray;
begin
  Probe := TQueryFlowProbe.Create;
  Manifest := TJSONObject.Create;
  try
    Probe.EnsureResult := True;
    ArrayQueryCalls := 0;

    Values := ExecuteResourceRepoStringArrayQueryCore(Manifest, @Probe.EnsureManifestLoaded,
      @Probe.LogFmt, 'Error listing cross targets: %s', @RaisingStringArrayQuery);

    Check('string-array query calls low-level helper once',
      ArrayQueryCalls = 1,
      'calls=' + IntToStr(ArrayQueryCalls));
    Check('string-array query logs exception',
      Pos('array boom', Probe.LastLog) > 0,
      Probe.LastLog);
    Check('string-array query returns empty array on exception',
      Length(Values) = 0,
      'length=' + IntToStr(Length(Values)));
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

procedure TestCrossInfoQueryReturnsSuccessPath;
var
  Probe: TQueryFlowProbe;
  Manifest: TJSONObject;
  Info: TCrossToolchainInfo;
begin
  Probe := TQueryFlowProbe.Create;
  Manifest := TJSONObject.Create;
  try
    Probe.EnsureResult := True;

    Check('cross-info query returns success',
      ExecuteResourceRepoCrossInfoQueryCore(Manifest, @Probe.EnsureManifestLoaded,
        @Probe.LogFmt, 'Error getting cross toolchain info: %s',
        'arm-linux', 'arm-linux-gnueabihf-', Info, @DummyCrossInfoQuery),
      'expected success');
    Check('cross-info query keeps target name',
      Info.TargetName = 'arm-linux',
      'target=' + Info.TargetName);
    Check('cross-info query keeps prefix',
      Info.BinutilsPrefix = 'arm-linux-gnueabihf-',
      'prefix=' + Info.BinutilsPrefix);
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

begin
  TestBooleanQueryReturnsFalseWhenManifestUnavailable;
  TestPlatformInfoQueryLogsExceptionAndClearsResult;
  TestStringQueryFallsBackWhenManifestMissing;
  TestStringArrayQueryLogsExceptionAndReturnsEmpty;
  TestCrossInfoQueryReturnsSuccessPath;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
