program test_fpc_sourcemanagerflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.manager,
  fpdev.fpc.sourcemanagerflow,
  test_temp_paths;

type
  TBridgeProbe = class;

  TTrackedBuildManager = class(TBuildManager)
  private
    FOwner: TBridgeProbe;
  public
    constructor CreateForProbe(AOwner: TBridgeProbe; const ASourceRoot: string);
    destructor Destroy; override;
  end;

  TBridgeProbe = class
  public
    TempRoot: string;
    CreateCalls: Integer;
    DispatchCalls: Integer;
    DestroyCalls: Integer;
    LastAllowInstall: Boolean;
    LastAction: Integer;
    LastVersion: string;
    ReturnNilManager: Boolean;
    FailDispatch: Boolean;
    LastManagerMatches: Boolean;
    LastManager: TBuildManager;
    function CreateManager(const AAllowInstall: Boolean): TBuildManager;
    function DispatchAction(ABuildManager: TBuildManager; AAction: Integer;
      const AVersion: string): Boolean;
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

constructor TTrackedBuildManager.CreateForProbe(
  AOwner: TBridgeProbe;
  const ASourceRoot: string
);
begin
  FOwner := AOwner;
  inherited Create(ASourceRoot, 1, False);
end;

destructor TTrackedBuildManager.Destroy;
begin
  if FOwner <> nil then
    Inc(FOwner.DestroyCalls);
  inherited Destroy;
end;

function TBridgeProbe.CreateManager(const AAllowInstall: Boolean): TBuildManager;
begin
  Inc(CreateCalls);
  LastAllowInstall := AAllowInstall;
  if ReturnNilManager then
    Exit(nil);

  Result := TTrackedBuildManager.CreateForProbe(Self, TempRoot);
  LastManager := Result;
end;

function TBridgeProbe.DispatchAction(ABuildManager: TBuildManager; AAction: Integer;
  const AVersion: string): Boolean;
begin
  Inc(DispatchCalls);
  LastAction := AAction;
  LastVersion := AVersion;
  LastManagerMatches := ABuildManager = LastManager;
  Result := not FailDispatch;
end;

procedure TestBridgeForwardsBuildActionAndFreesManager;
var
  TempRoot: string;
  Probe: TBridgeProbe;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcemanagerflow');
  Probe := TBridgeProbe.Create;
  try
    Check('sourcemanagerflow temp root stays under shared temp',
      PathUsesSystemTempRoot(TempRoot),
      TempRoot);
    Probe.TempRoot := TempRoot;
    OK := ExecuteFPCSourceBuildManagerBridgeCore(
      '3.2.2',
      False,
      FPC_SOURCE_MANAGER_ACTION_BUILD_COMPILER,
      @Probe.CreateManager,
      @Probe.DispatchAction
    );

    Check('sourcemanagerflow build bridge returns dispatch result', OK, 'expected success');
    Check('sourcemanagerflow build bridge forwards allow install false',
      not Probe.LastAllowInstall,
      'allow_install=True');
    Check('sourcemanagerflow build bridge dispatches exactly once',
      Probe.DispatchCalls = 1,
      IntToStr(Probe.DispatchCalls));
    Check('sourcemanagerflow build bridge forwards action',
      Probe.LastAction = FPC_SOURCE_MANAGER_ACTION_BUILD_COMPILER,
      IntToStr(Probe.LastAction));
    Check('sourcemanagerflow build bridge forwards version',
      Probe.LastVersion = '3.2.2',
      Probe.LastVersion);
    Check('sourcemanagerflow build bridge dispatches the created manager',
      Probe.LastManagerMatches,
      'manager mismatch');
    Check('sourcemanagerflow build bridge frees created manager',
      Probe.DestroyCalls = 1,
      IntToStr(Probe.DestroyCalls));
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

procedure TestBridgeUsesInstallFlagForInstallActions;
var
  TempRoot: string;
  Probe: TBridgeProbe;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcemanagerflow_install');
  Probe := TBridgeProbe.Create;
  try
    Probe.TempRoot := TempRoot;
    OK := ExecuteFPCSourceBuildManagerBridgeCore(
      '3.2.2',
      True,
      FPC_SOURCE_MANAGER_ACTION_INSTALL_BINARIES,
      @Probe.CreateManager,
      @Probe.DispatchAction
    );

    Check('sourcemanagerflow install bridge returns dispatch result', OK, 'expected success');
    Check('sourcemanagerflow install bridge forwards allow install true',
      Probe.LastAllowInstall,
      'allow_install=False');
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

procedure TestBridgeFailsWhenFactoryReturnsNil;
var
  TempRoot: string;
  Probe: TBridgeProbe;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcemanagerflow_nil');
  Probe := TBridgeProbe.Create;
  try
    Probe.TempRoot := TempRoot;
    Probe.ReturnNilManager := True;
    OK := ExecuteFPCSourceBuildManagerBridgeCore(
      '3.2.2',
      False,
      FPC_SOURCE_MANAGER_ACTION_BUILD_RTL,
      @Probe.CreateManager,
      @Probe.DispatchAction
    );

    Check('sourcemanagerflow returns false when factory returns nil',
      not OK,
      'expected failure');
    Check('sourcemanagerflow does not dispatch when factory returns nil',
      Probe.DispatchCalls = 0,
      IntToStr(Probe.DispatchCalls));
    Check('sourcemanagerflow does not free nil manager',
      Probe.DestroyCalls = 0,
      IntToStr(Probe.DestroyCalls));
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

procedure TestBridgeFreesManagerOnDispatchFailure;
var
  TempRoot: string;
  Probe: TBridgeProbe;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcemanagerflow_fail');
  Probe := TBridgeProbe.Create;
  try
    Probe.TempRoot := TempRoot;
    Probe.FailDispatch := True;
    OK := ExecuteFPCSourceBuildManagerBridgeCore(
      '3.2.2',
      True,
      FPC_SOURCE_MANAGER_ACTION_TEST_RESULTS,
      @Probe.CreateManager,
      @Probe.DispatchAction
    );

    Check('sourcemanagerflow returns false when dispatch fails',
      not OK,
      'expected failure');
    Check('sourcemanagerflow still frees manager on dispatch failure',
      Probe.DestroyCalls = 1,
      IntToStr(Probe.DestroyCalls));
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

procedure TestCacheMarkerWrite;
var
  TempRoot: string;
  CachePath: string;
  Lines: TStringList;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcemanagerflow_cache');
  try
    Check('sourcemanagerflow cache temp root stays under shared temp',
      PathUsesSystemTempRoot(TempRoot),
      TempRoot);
    Check('sourcemanagerflow writes cache marker file',
      WriteFPCSourceCacheMarkerCore(TempRoot, '3.2.2', EncodeDateTime(2026, 5, 2, 13, 0, 0, 0)),
      'expected cache marker write success');

    CachePath := TempRoot + PathDelim + 'cache' + PathDelim + 'fpc-3.2.2.cache';
    Check('sourcemanagerflow cache marker file exists',
      FileExists(CachePath),
      CachePath);

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(CachePath);
      Check('sourcemanagerflow cache marker stores version line',
        (Lines.Count >= 1) and (Lines[0] = 'version=3.2.2'),
        Lines.Text);
      Check('sourcemanagerflow cache marker stores built_at line',
        (Lines.Count >= 2) and (Pos('built_at=', Lines[1]) = 1),
        Lines.Text);
    finally
      Lines.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestBridgeForwardsBuildActionAndFreesManager;
  TestBridgeUsesInstallFlagForInstallActions;
  TestBridgeFailsWhenFactoryReturnsNil;
  TestBridgeFreesManagerOnDispatchFailure;
  TestCacheMarkerWrite;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
