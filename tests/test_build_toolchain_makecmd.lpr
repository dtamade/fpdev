program test_build_toolchain_makecmd;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.toolchain;

type
  TToolProbe = class
  private
    FMingw: Boolean;
    FMake: Boolean;
    FGMake: Boolean;
  public
    constructor Create(AMingw, AMake, AGMake: Boolean);
    function HasTool(const AExe: string; const AArgs: array of string): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TToolProbe.Create(AMingw, AMake, AGMake: Boolean);
begin
  inherited Create;
  FMingw := AMingw;
  FMake := AMake;
  FGMake := AGMake;
end;

function TToolProbe.HasTool(const AExe: string; const AArgs: array of string): Boolean;
begin
  if Length(AArgs) >= 0 then;
  if SameText(AExe, 'mingw32-make') then
    Exit(FMingw);
  if SameText(AExe, 'gmake') then
    Exit(FGMake);
  if SameText(AExe, 'make') then
    Exit(FMake);
  Result := False;
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

procedure TestResolveWindowsPrefersMingw32Make;
var
  Probe: TToolProbe;
  Cmd: string;
begin
  Probe := TToolProbe.Create(True, True, True);
  try
    Cmd := BuildToolchainResolveMakeCommandCore(True, @Probe.HasTool);
    Check('windows prefers mingw32-make', Cmd = 'mingw32-make', 'cmd=' + Cmd);
  finally
    Probe.Free;
  end;
end;

procedure TestResolveWindowsFallsBackToMake;
var
  Probe: TToolProbe;
  Cmd: string;
begin
  Probe := TToolProbe.Create(False, True, True);
  try
    Cmd := BuildToolchainResolveMakeCommandCore(True, @Probe.HasTool);
    Check('windows falls back to make', Cmd = 'make', 'cmd=' + Cmd);
  finally
    Probe.Free;
  end;
end;

procedure TestResolveUnixPrefersGMake;
var
  Probe: TToolProbe;
  Cmd: string;
begin
  Probe := TToolProbe.Create(True, True, True);
  try
    Cmd := BuildToolchainResolveMakeCommandCore(False, @Probe.HasTool);
    Check('unix prefers gmake', Cmd = 'gmake', 'cmd=' + Cmd);
  finally
    Probe.Free;
  end;
end;

procedure TestResolveUnixFallsBackToMake;
var
  Probe: TToolProbe;
  Cmd: string;
begin
  Probe := TToolProbe.Create(False, True, False);
  try
    Cmd := BuildToolchainResolveMakeCommandCore(False, @Probe.HasTool);
    Check('unix falls back to make', Cmd = 'make', 'cmd=' + Cmd);
  finally
    Probe.Free;
  end;
end;

procedure TestMakeAvailableChecksWindowsFamily;
var
  Probe: TToolProbe;
begin
  Probe := TToolProbe.Create(True, False, False);
  try
    Check('make available on windows via mingw32-make',
      BuildToolchainMakeAvailableCore(True, @Probe.HasTool));
  finally
    Probe.Free;
  end;
end;

procedure TestMakeAvailableChecksUnixFamily;
var
  Probe: TToolProbe;
begin
  Probe := TToolProbe.Create(False, False, True);
  try
    Check('make available on unix via gmake',
      BuildToolchainMakeAvailableCore(False, @Probe.HasTool));
  finally
    Probe.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Build Toolchain Make Command Tests');
  WriteLn('========================================');

  TestResolveWindowsPrefersMingw32Make;
  TestResolveWindowsFallsBackToMake;
  TestResolveUnixPrefersGMake;
  TestResolveUnixFallsBackToMake;
  TestMakeAvailableChecksWindowsFamily;
  TestMakeAvailableChecksUnixFamily;

  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
