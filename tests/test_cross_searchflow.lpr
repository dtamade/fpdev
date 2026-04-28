program test_cross_searchflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.cross.searchflow;

type
  TSearchFlowProbe = class
  private
    FEvents: array of string;
    procedure AddEvent(const AEvent: string);
  public
    CheckToolResult: Boolean;
    ClearLogCalls: Integer;
    CheckToolCalls: Integer;
    Layer1Result: TCrossSearchResult;
    Layer2Result: TCrossSearchResult;
    Layer3Result: TCrossSearchResult;
    Layer4Result: TCrossSearchResult;
    Layer5Result: TCrossSearchResult;
    Layer6Result: TCrossSearchResult;
    LastCfgPath: string;
    LastLogLayer: Integer;
    LastLogFound: Boolean;
    LastLogPath: string;
    LastLogPrefix: string;
    procedure ClearLog;
    function CheckTool(const ADir, APrefix, ATool: string): Boolean;
    procedure AddLog(ALayer: Integer; const ALayerName, APath, APrefix: string; AFound: Boolean);
    function SearchLayer1(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer2(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer3(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer4(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer5(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer6(const ATarget: TCrossTarget; const AFpcCfgPath: string): TCrossSearchResult;
    function EventText: string;
    function LayerCallCount: Integer;
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

function MakeTarget(const ACPU, AOS, ABinutilsPath, ABinutilsPrefix: string): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := True;
  Result.CPU := ACPU;
  Result.OS := AOS;
  Result.BinutilsPath := ABinutilsPath;
  Result.BinutilsPrefix := ABinutilsPrefix;
end;

function MakeResult(const AFound: Boolean; const APath, APrefix: string;
  const ALayer: Integer; const ALayerName: string): TCrossSearchResult;
begin
  Result := Default(TCrossSearchResult);
  Result.Found := AFound;
  Result.BinutilsPath := APath;
  Result.BinutilsPrefix := APrefix;
  Result.Layer := ALayer;
  Result.LayerName := ALayerName;
end;

procedure TSearchFlowProbe.AddEvent(const AEvent: string);
var
  Index: Integer;
begin
  Index := Length(FEvents);
  SetLength(FEvents, Index + 1);
  FEvents[Index] := AEvent;
end;

procedure TSearchFlowProbe.ClearLog;
begin
  Inc(ClearLogCalls);
  AddEvent('clear');
end;

function TSearchFlowProbe.CheckTool(const ADir, APrefix, ATool: string): Boolean;
begin
  Inc(CheckToolCalls);
  AddEvent('check');
  if ADir = '' then;
  if APrefix = '' then;
  if ATool = '' then;
  Result := CheckToolResult;
end;

procedure TSearchFlowProbe.AddLog(ALayer: Integer; const ALayerName, APath,
  APrefix: string; AFound: Boolean);
begin
  LastLogLayer := ALayer;
  LastLogFound := AFound;
  LastLogPath := APath;
  LastLogPrefix := APrefix;
  AddEvent('log');
  if ALayerName = '' then;
end;

function TSearchFlowProbe.SearchLayer1(const ATarget: TCrossTarget): TCrossSearchResult;
begin
  AddEvent('l1');
  if ATarget.CPU = '' then;
  Result := Layer1Result;
end;

function TSearchFlowProbe.SearchLayer2(const ATarget: TCrossTarget): TCrossSearchResult;
begin
  AddEvent('l2');
  if ATarget.OS = '' then;
  Result := Layer2Result;
end;

function TSearchFlowProbe.SearchLayer3(const ATarget: TCrossTarget): TCrossSearchResult;
begin
  AddEvent('l3');
  if ATarget.ABI = '' then;
  Result := Layer3Result;
end;

function TSearchFlowProbe.SearchLayer4(const ATarget: TCrossTarget): TCrossSearchResult;
begin
  AddEvent('l4');
  if ATarget.SubArch = '' then;
  Result := Layer4Result;
end;

function TSearchFlowProbe.SearchLayer5(const ATarget: TCrossTarget): TCrossSearchResult;
begin
  AddEvent('l5');
  if ATarget.CrossOpt = '' then;
  Result := Layer5Result;
end;

function TSearchFlowProbe.SearchLayer6(const ATarget: TCrossTarget;
  const AFpcCfgPath: string): TCrossSearchResult;
begin
  AddEvent('l6');
  LastCfgPath := AFpcCfgPath;
  if ATarget.BinutilsPrefix = '' then;
  Result := Layer6Result;
end;

function TSearchFlowProbe.EventText: string;
var
  Index: Integer;
begin
  Result := '';
  for Index := 0 to High(FEvents) do
  begin
    if Result <> '' then
      Result := Result + '>';
    Result := Result + FEvents[Index];
  end;
end;

function TSearchFlowProbe.LayerCallCount: Integer;
var
  Index: Integer;
begin
  Result := 0;
  for Index := 0 to High(FEvents) do
    if (Length(FEvents[Index]) = 2) and (FEvents[Index][1] = 'l') then
      Inc(Result);
end;

procedure TestConfiguredPathHitShortCircuitsLayers;
var
  Probe: TSearchFlowProbe;
  Callbacks: TCrossSearchCallbacks;
  Target: TCrossTarget;
  Res: TCrossSearchResult;
begin
  Probe := TSearchFlowProbe.Create;
  try
    Probe.CheckToolResult := True;
    Target := MakeTarget('arm', 'linux', '/configured/bin', 'arm-linux-gnueabihf-');

    Callbacks.ClearLog := @Probe.ClearLog;
    Callbacks.CheckTool := @Probe.CheckTool;
    Callbacks.AddLog := @Probe.AddLog;
    Callbacks.SearchLayer1 := @Probe.SearchLayer1;
    Callbacks.SearchLayer2 := @Probe.SearchLayer2;
    Callbacks.SearchLayer3 := @Probe.SearchLayer3;
    Callbacks.SearchLayer4 := @Probe.SearchLayer4;
    Callbacks.SearchLayer5 := @Probe.SearchLayer5;
    Callbacks.SearchLayer6 := @Probe.SearchLayer6;

    Res := ExecuteCrossBinutilsSearchCore(Target, '', 'as', Callbacks);

    Check('configured hit returns found result', Res.Found, 'configured result should be found');
    Check('configured hit keeps layer 0', Res.Layer = 0, 'layer=' + IntToStr(Res.Layer));
    Check('configured hit keeps path', Res.BinutilsPath = '/configured/bin', 'path=' + Res.BinutilsPath);
    Check('configured hit resets log once', Probe.ClearLogCalls = 1, 'clear=' + IntToStr(Probe.ClearLogCalls));
    Check('configured hit checks tool once', Probe.CheckToolCalls = 1, 'checks=' + IntToStr(Probe.CheckToolCalls));
    Check('configured hit does not call layers', Probe.LayerCallCount = 0, Probe.EventText);
    Check('configured hit logs success', Probe.LastLogFound and (Probe.LastLogLayer = 0),
      'layer=' + IntToStr(Probe.LastLogLayer));
  finally
    Probe.Free;
  end;
end;

procedure TestConfiguredMissStopsAtFirstFoundLayer;
var
  Probe: TSearchFlowProbe;
  Callbacks: TCrossSearchCallbacks;
  Target: TCrossTarget;
  Res: TCrossSearchResult;
begin
  Probe := TSearchFlowProbe.Create;
  try
    Probe.CheckToolResult := False;
    Probe.Layer1Result := MakeResult(False, '', '', 1, 'fpdev-managed');
    Probe.Layer2Result := MakeResult(True, '/usr/bin', 'arm-linux-gnueabihf-', 2, 'system-paths');
    Target := MakeTarget('arm', 'linux', '/configured/bin', 'arm-linux-gnueabihf-');

    Callbacks.ClearLog := @Probe.ClearLog;
    Callbacks.CheckTool := @Probe.CheckTool;
    Callbacks.AddLog := @Probe.AddLog;
    Callbacks.SearchLayer1 := @Probe.SearchLayer1;
    Callbacks.SearchLayer2 := @Probe.SearchLayer2;
    Callbacks.SearchLayer3 := @Probe.SearchLayer3;
    Callbacks.SearchLayer4 := @Probe.SearchLayer4;
    Callbacks.SearchLayer5 := @Probe.SearchLayer5;
    Callbacks.SearchLayer6 := @Probe.SearchLayer6;

    Res := ExecuteCrossBinutilsSearchCore(Target, '/tmp/fpc.cfg', 'as', Callbacks);

    Check('configured miss returns first found layer', Res.Found and (Res.Layer = 2),
      'layer=' + IntToStr(Res.Layer));
    Check('configured miss preserves layer path', Res.BinutilsPath = '/usr/bin', 'path=' + Res.BinutilsPath);
    Check('configured miss records order', Probe.EventText = 'clear>check>log>l1>l2', Probe.EventText);
    Check('configured miss stops before layer 3', Pos('l3', Probe.EventText) = 0, Probe.EventText);
  finally
    Probe.Free;
  end;
end;

procedure TestAllMissFallsBackToLayer6;
var
  Probe: TSearchFlowProbe;
  Callbacks: TCrossSearchCallbacks;
  Target: TCrossTarget;
  Res: TCrossSearchResult;
begin
  Probe := TSearchFlowProbe.Create;
  try
    Probe.Layer6Result := MakeResult(True, '/cfg/bin', 'sparc-solaris-', 6, 'config-hints');
    Target := MakeTarget('sparc', 'solaris', '', '');

    Callbacks.ClearLog := @Probe.ClearLog;
    Callbacks.CheckTool := @Probe.CheckTool;
    Callbacks.AddLog := @Probe.AddLog;
    Callbacks.SearchLayer1 := @Probe.SearchLayer1;
    Callbacks.SearchLayer2 := @Probe.SearchLayer2;
    Callbacks.SearchLayer3 := @Probe.SearchLayer3;
    Callbacks.SearchLayer4 := @Probe.SearchLayer4;
    Callbacks.SearchLayer5 := @Probe.SearchLayer5;
    Callbacks.SearchLayer6 := @Probe.SearchLayer6;

    Res := ExecuteCrossBinutilsSearchCore(Target, '/tmp/cross.cfg', 'as', Callbacks);

    Check('all miss reaches layer 6', Res.Found and (Res.Layer = 6), 'layer=' + IntToStr(Res.Layer));
    Check('all miss passes cfg path to layer 6', Probe.LastCfgPath = '/tmp/cross.cfg', 'cfg=' + Probe.LastCfgPath);
    Check('all miss keeps layer order', Probe.EventText = 'clear>l1>l2>l3>l4>l5>l6', Probe.EventText);
    Check('all miss resets log once', Probe.ClearLogCalls = 1, 'clear=' + IntToStr(Probe.ClearLogCalls));
    Check('all miss skips configured tool check when no configured path', Probe.CheckToolCalls = 0,
      'checks=' + IntToStr(Probe.CheckToolCalls));
  finally
    Probe.Free;
  end;
end;

begin
  TestConfiguredPathHitShortCircuitsLayers;
  TestConfiguredMissStopsAtFirstFoundLayer;
  TestAllMissFallsBackToLayer6;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
