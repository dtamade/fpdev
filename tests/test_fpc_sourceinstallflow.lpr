program test_fpc_sourceinstallflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.sourceinstallflow;

type
  TInstallProbe = class
  private
    FEvents: TStringList;
    FCurrentVersionRef: PString;
    procedure AddEvent(const AEvent: string);
  public
    InitializeResult: Boolean;
    EnsureBootstrapResult: Boolean;
    CloneResult: Boolean;
    CacheAvailableResult: Boolean;
    UseCachedBuildResult: Boolean;
    BuildCompilerResult: Boolean;
    BuildRTLResult: Boolean;
    BuildPackagesResult: Boolean;
    InstallBinariesResult: Boolean;
    ConfigureEnvironmentResult: Boolean;
    TestBuildResultsValue: Boolean;
    WriteCacheMarkerResult: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure BindCurrentVersion(var ACurrentVersion: string);
    procedure SetCurrentStep(AStep: Integer);
    function ReportStep(AStep: Integer; const AMessage: string): Boolean;
    function InitializeInstall(const AVersion: string): Boolean;
    function EnsureBootstrap(const AVersion: string): Boolean;
    function CloneSource(const AVersion: string): Boolean;
    function IsCacheAvailable(const AVersion: string): Boolean;
    function UseCachedBuild(const AVersion: string): Boolean;
    function BuildCompiler(const AVersion: string): Boolean;
    function BuildRTL(const AVersion: string): Boolean;
    function BuildPackages(const AVersion: string): Boolean;
    function InstallBinaries(const AVersion: string): Boolean;
    function ConfigureEnvironment(const AVersion: string): Boolean;
    function TestBuildResults(const AVersion: string): Boolean;
    function WriteCacheMarker(const AVersion: string): Boolean;
    function EventText: string;
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

constructor TInstallProbe.Create;
begin
  inherited Create;
  FEvents := TStringList.Create;
  InitializeResult := True;
  EnsureBootstrapResult := True;
  CloneResult := True;
  BuildCompilerResult := True;
  BuildRTLResult := True;
  BuildPackagesResult := True;
  InstallBinariesResult := True;
  ConfigureEnvironmentResult := True;
  TestBuildResultsValue := True;
  WriteCacheMarkerResult := True;
end;

destructor TInstallProbe.Destroy;
begin
  FEvents.Free;
  inherited Destroy;
end;

procedure TInstallProbe.AddEvent(const AEvent: string);
begin
  FEvents.Add(AEvent);
end;

procedure TInstallProbe.BindCurrentVersion(var ACurrentVersion: string);
begin
  FCurrentVersionRef := @ACurrentVersion;
end;

procedure TInstallProbe.SetCurrentStep(AStep: Integer);
begin
  AddEvent('step:' + IntToStr(AStep));
end;

function TInstallProbe.ReportStep(AStep: Integer; const AMessage: string): Boolean;
begin
  AddEvent('report:' + IntToStr(AStep) + ':' + AMessage);
  Result := True;
end;

function TInstallProbe.InitializeInstall(const AVersion: string): Boolean;
begin
  AddEvent('init:' + AVersion);
  Result := InitializeResult;
end;

function TInstallProbe.EnsureBootstrap(const AVersion: string): Boolean;
begin
  AddEvent('bootstrap:' + AVersion);
  Result := EnsureBootstrapResult;
end;

function TInstallProbe.CloneSource(const AVersion: string): Boolean;
begin
  AddEvent('clone:' + AVersion);
  Result := CloneResult;
  if Result and Assigned(FCurrentVersionRef) then
    FCurrentVersionRef^ := AVersion;
end;

function TInstallProbe.IsCacheAvailable(const AVersion: string): Boolean;
begin
  AddEvent('cache-check:' + AVersion);
  Result := CacheAvailableResult;
end;

function TInstallProbe.UseCachedBuild(const AVersion: string): Boolean;
begin
  AddEvent('cache-use:' + AVersion);
  Result := UseCachedBuildResult;
end;

function TInstallProbe.BuildCompiler(const AVersion: string): Boolean;
begin
  AddEvent('compiler:' + AVersion);
  Result := BuildCompilerResult;
end;

function TInstallProbe.BuildRTL(const AVersion: string): Boolean;
begin
  AddEvent('rtl:' + AVersion);
  Result := BuildRTLResult;
end;

function TInstallProbe.BuildPackages(const AVersion: string): Boolean;
begin
  AddEvent('packages:' + AVersion);
  Result := BuildPackagesResult;
end;

function TInstallProbe.InstallBinaries(const AVersion: string): Boolean;
begin
  AddEvent('install:' + AVersion);
  Result := InstallBinariesResult;
end;

function TInstallProbe.ConfigureEnvironment(const AVersion: string): Boolean;
begin
  AddEvent('config:' + AVersion);
  Result := ConfigureEnvironmentResult;
end;

function TInstallProbe.TestBuildResults(const AVersion: string): Boolean;
begin
  AddEvent('test:' + AVersion);
  Result := TestBuildResultsValue;
end;

function TInstallProbe.WriteCacheMarker(const AVersion: string): Boolean;
begin
  AddEvent('cache-write:' + AVersion);
  Result := WriteCacheMarkerResult;
end;

function TInstallProbe.EventText: string;
begin
  Result := FEvents.Text;
end;

function MakeState(const AVersion, APreviousVersion: string; AUseCache: Boolean): TFPCSourceInstallState;
begin
  Result := Default(TFPCSourceInstallState);
  Result.Version := AVersion;
  Result.PreviousVersion := APreviousVersion;
  Result.UseCache := AUseCache;
end;

function MakeCallbacks(AProbe: TInstallProbe): TFPCSourceInstallCallbacks;
begin
  Result := Default(TFPCSourceInstallCallbacks);
  Result.SetCurrentStep := @AProbe.SetCurrentStep;
  Result.ReportStep := @AProbe.ReportStep;
  Result.InitializeInstall := @AProbe.InitializeInstall;
  Result.EnsureBootstrap := @AProbe.EnsureBootstrap;
  Result.CloneSource := @AProbe.CloneSource;
  Result.IsCacheAvailable := @AProbe.IsCacheAvailable;
  Result.UseCachedBuild := @AProbe.UseCachedBuild;
  Result.BuildCompiler := @AProbe.BuildCompiler;
  Result.BuildRTL := @AProbe.BuildRTL;
  Result.BuildPackages := @AProbe.BuildPackages;
  Result.InstallBinaries := @AProbe.InstallBinaries;
  Result.ConfigureEnvironment := @AProbe.ConfigureEnvironment;
  Result.TestBuildResults := @AProbe.TestBuildResults;
  Result.WriteCacheMarker := @AProbe.WriteCacheMarker;
end;

procedure TestFullBuildSequence;
var
  Probe: TInstallProbe;
  CurrentVersion: string;
  OK: Boolean;
  Events: string;
begin
  Probe := TInstallProbe.Create;
  try
    CurrentVersion := '';
    Probe.BindCurrentVersion(CurrentVersion);

    OK := ExecuteFPCSourceInstallFlowCore(
      MakeState('3.2.2', '', True),
      CurrentVersion,
      MakeCallbacks(Probe)
    );

    Check('installflow full build succeeds', OK, 'expected success');
    Check('installflow full build updates current version',
      CurrentVersion = '3.2.2', 'current=' + CurrentVersion);
    Events := Probe.EventText;
    Check('installflow full build runs ordered actions',
      (Pos('init:3.2.2', Events) > 0) and
      (Pos('bootstrap:3.2.2', Events) > Pos('init:3.2.2', Events)) and
      (Pos('clone:3.2.2', Events) > Pos('bootstrap:3.2.2', Events)) and
      (Pos('cache-check:3.2.2', Events) > Pos('clone:3.2.2', Events)) and
      (Pos('compiler:3.2.2', Events) > Pos('cache-check:3.2.2', Events)) and
      (Pos('rtl:3.2.2', Events) > Pos('compiler:3.2.2', Events)) and
      (Pos('packages:3.2.2', Events) > Pos('rtl:3.2.2', Events)) and
      (Pos('install:3.2.2', Events) > Pos('packages:3.2.2', Events)) and
      (Pos('config:3.2.2', Events) > Pos('install:3.2.2', Events)) and
      (Pos('test:3.2.2', Events) > Pos('config:3.2.2', Events)) and
      (Pos('cache-write:3.2.2', Events) > Pos('test:3.2.2', Events)),
      Events);
  finally
    Probe.Free;
  end;
end;

procedure TestCachedBuildShortCircuit;
var
  Probe: TInstallProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TInstallProbe.Create;
  try
    Probe.CacheAvailableResult := True;
    Probe.UseCachedBuildResult := True;
    CurrentVersion := '';
    Probe.BindCurrentVersion(CurrentVersion);

    OK := ExecuteFPCSourceInstallFlowCore(
      MakeState('3.2.2', '', True),
      CurrentVersion,
      MakeCallbacks(Probe)
    );

    Check('installflow cache hit succeeds', OK, 'expected success');
    Check('installflow cache hit skips compiler rebuild',
      Pos('compiler:3.2.2', Probe.EventText) = 0, Probe.EventText);
    Check('installflow cache hit still installs and validates',
      (Pos('install:3.2.2', Probe.EventText) > 0) and
      (Pos('config:3.2.2', Probe.EventText) > 0) and
      (Pos('test:3.2.2', Probe.EventText) > 0),
      Probe.EventText);
    Check('installflow cache hit skips cache marker rewrite',
      Pos('cache-write:3.2.2', Probe.EventText) = 0, Probe.EventText);
  finally
    Probe.Free;
  end;
end;

procedure TestCachedBuildFailureFallsBackToFullBuild;
var
  Probe: TInstallProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TInstallProbe.Create;
  try
    Probe.CacheAvailableResult := True;
    Probe.UseCachedBuildResult := False;
    CurrentVersion := '';
    Probe.BindCurrentVersion(CurrentVersion);

    OK := ExecuteFPCSourceInstallFlowCore(
      MakeState('3.2.2', '', True),
      CurrentVersion,
      MakeCallbacks(Probe)
    );

    Check('installflow cache validation failure falls back to full build',
      OK, 'expected helper to continue with full build');
    Check('installflow cache validation failure still builds compiler',
      Pos('compiler:3.2.2', Probe.EventText) > 0, Probe.EventText);
    Check('installflow cache validation failure rewrites cache marker',
      Pos('cache-write:3.2.2', Probe.EventText) > 0, Probe.EventText);
  finally
    Probe.Free;
  end;
end;

procedure TestFailureRollsBackToPreviousVersion;
var
  Probe: TInstallProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TInstallProbe.Create;
  try
    Probe.BuildRTLResult := False;
    CurrentVersion := '3.0.4';
    Probe.BindCurrentVersion(CurrentVersion);

    OK := ExecuteFPCSourceInstallFlowCore(
      MakeState('3.2.2', '3.0.4', True),
      CurrentVersion,
      MakeCallbacks(Probe)
    );

    Check('installflow failed build returns false', not OK, 'expected failure');
    Check('installflow failed build rolls back current version',
      CurrentVersion = '3.0.4', 'current=' + CurrentVersion);
  finally
    Probe.Free;
  end;
end;

begin
  TestFullBuildSequence;
  TestCachedBuildShortCircuit;
  TestCachedBuildFailureFallsBackToFullBuild;
  TestFailureRollsBackToPreviousVersion;

  if FailCount > 0 then
    Halt(1);
end.
