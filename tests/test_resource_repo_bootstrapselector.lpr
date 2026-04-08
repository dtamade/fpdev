program test_resource_repo_bootstrapselector;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.resource.repo.bootstrap;

type
  TBootstrapProbe = class
  public
    Available: array of string;
    Platform: string;
    Calls: Integer;
    function HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

function TBootstrapProbe.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
var
  I: Integer;
begin
  Inc(Calls);
  Result := False;
  if APlatform <> Platform then
    Exit(False);
  for I := 0 to High(Available) do
    if Available[I] = AVersion then
      Exit(True);
end;

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

procedure TestExactRequiredVersionWins;
var
  Probe: TBootstrapProbe;
  Logs: TStringArray;
  Selected: string;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.Platform := 'linux-x86_64';
    SetLength(Probe.Available, 2);
    Probe.Available[0] := '3.2.2';
    Probe.Available[1] := '3.2.0';

    Selected := SelectBestBootstrapVersionCore('3.2.2', Probe.Platform,
      ['3.2.2', '3.2.0'], @Probe.HasBootstrapCompiler, Logs);

    Check('exact required version selected', Selected = '3.2.2', 'selected=' + Selected);
    Check('exact required version emits no logs', Length(Logs) = 0,
      'logs=' + IntToStr(Length(Logs)));
  finally
    Probe.Free;
  end;
end;

procedure TestMissingRequiredDefaultsAndWarns;
var
  Probe: TBootstrapProbe;
  Logs: TStringArray;
  Selected: string;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.Platform := 'linux-x86_64';
    SetLength(Probe.Available, 1);
    Probe.Available[0] := '3.2.2';

    Selected := SelectBestBootstrapVersionCore('', Probe.Platform,
      ['3.2.2'], @Probe.HasBootstrapCompiler, Logs);

    Check('missing required version defaults to 3.2.2', Selected = '3.2.2', 'selected=' + Selected);
    Check('missing required version logs warning',
      (Length(Logs) >= 1) and (Pos('No bootstrap version mapping found', Logs[0]) > 0),
      'warning missing');
  finally
    Probe.Free;
  end;
end;

procedure TestFallbackChainChoosesOlderSupportedVersion;
var
  Probe: TBootstrapProbe;
  Logs: TStringArray;
  Selected: string;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.Platform := 'linux-x86_64';
    SetLength(Probe.Available, 1);
    Probe.Available[0] := '3.0.4';

    Selected := SelectBestBootstrapVersionCore('3.2.0', Probe.Platform,
      ['3.0.4'], @Probe.HasBootstrapCompiler, Logs);

    Check('fallback chain selects older supported version', Selected = '3.0.4', 'selected=' + Selected);
    Check('fallback chain logs note',
      (Length(Logs) >= 1) and (Pos('fallback due to availability', Logs[High(Logs)]) > 0),
      'fallback note missing');
  finally
    Probe.Free;
  end;
end;

procedure TestCompatibleSameSeriesAlternativeWins;
var
  Probe: TBootstrapProbe;
  Logs: TStringArray;
  Selected: string;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.Platform := 'linux-x86_64';
    SetLength(Probe.Available, 1);
    Probe.Available[0] := '3.2.2';

    Selected := SelectBestBootstrapVersionCore('3.2.0', Probe.Platform,
      ['3.2.2'], @Probe.HasBootstrapCompiler, Logs);

    Check('same-series alternative selects newer patch', Selected = '3.2.2', 'selected=' + Selected);
    Check('same-series alternative logs note',
      (Length(Logs) >= 1) and (Pos('same-series alternative', Logs[High(Logs)]) > 0),
      'same-series note missing');
  finally
    Probe.Free;
  end;
end;

procedure TestRejectsIncompatibleOnlyAvailableVersion;
var
  Probe: TBootstrapProbe;
  Logs: TStringArray;
  Selected: string;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.Platform := 'linux-x86_64';
    SetLength(Probe.Available, 1);
    Probe.Available[0] := '3.3.1';

    Selected := SelectBestBootstrapVersionCore('3.2.0', Probe.Platform,
      ['3.3.1'], @Probe.HasBootstrapCompiler, Logs);

    Check('incompatible only-available version returns empty', Selected = '', 'selected=' + Selected);
    Check('incompatible only-available version logs error',
      (Length(Logs) >= 1) and (Pos('No compatible bootstrap compiler available', Logs[High(Logs)]) > 0),
      'compatibility error missing');
  finally
    Probe.Free;
  end;
end;

procedure TestNoAvailableBootstrapLogsError;
var
  Probe: TBootstrapProbe;
  Logs: TStringArray;
  Selected: string;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.Platform := 'linux-x86_64';
    SetLength(Probe.Available, 0);

    Selected := SelectBestBootstrapVersionCore('3.2.0', Probe.Platform,
      ['1.0.0'], @Probe.HasBootstrapCompiler, Logs);

    Check('no available bootstrap returns empty', Selected = '', 'selected=' + Selected);
    Check('no available bootstrap logs error',
      (Length(Logs) >= 1) and (Pos('No compatible bootstrap compiler available', Logs[High(Logs)]) > 0),
      'error log missing');
  finally
    Probe.Free;
  end;
end;

begin
  TestExactRequiredVersionWins;
  TestMissingRequiredDefaultsAndWarns;
  TestFallbackChainChoosesOlderSupportedVersion;
  TestCompatibleSameSeriesAlternativeWins;
  TestRejectsIncompatibleOnlyAvailableVersion;
  TestNoAvailableBootstrapLogsError;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
