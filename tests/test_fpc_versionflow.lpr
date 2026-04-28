program test_fpc_versionflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.types,
  fpdev.fpc.versionflow,
  test_cli_helpers;

type
  TVersionFlowProbe = class
  public
    Installed: Boolean;
    SetDefaultOK: Boolean;
    ActivationSuccess: Boolean;
    LastSetDefaultVersion: string;
    LastActivateVersion: string;
    LastActivateBinPath: string;

    function IsVersionInstalled(const AVersion: string): Boolean;
    function SetDefaultVersion(const AVersion: string): Boolean;
    function GetInstallPath(const AVersion: string): string;
    function ActivateVersion(const AVersion, ABinPath: string): TActivationResult;
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

function TVersionFlowProbe.IsVersionInstalled(const AVersion: string): Boolean;
begin
  if AVersion <> '' then; // suppress hint
  Result := Installed;
end;

function TVersionFlowProbe.SetDefaultVersion(const AVersion: string): Boolean;
begin
  LastSetDefaultVersion := AVersion;
  Result := SetDefaultOK;
end;

function TVersionFlowProbe.GetInstallPath(const AVersion: string): string;
begin
  Result := '/managed/fpc/' + AVersion;
end;

function TVersionFlowProbe.ActivateVersion(
  const AVersion, ABinPath: string
): TActivationResult;
begin
  Initialize(Result);
  LastActivateVersion := AVersion;
  LastActivateBinPath := ABinPath;
  Result.Success := ActivationSuccess;
  if not Result.Success then
    Result.ErrorMessage := 'activation failed';
end;

procedure TestNormalizeDefaultVersion;
begin
  Check('normalize strips fpc prefix',
    NormalizeDefaultFPCVersionCore('fpc-3.2.2') = '3.2.2',
    'normalized=' + NormalizeDefaultFPCVersionCore('fpc-3.2.2'));
  Check('normalize keeps plain version',
    NormalizeDefaultFPCVersionCore('3.2.2') = '3.2.2',
    'normalized=' + NormalizeDefaultFPCVersionCore('3.2.2'));
  Check('normalize keeps empty string',
    NormalizeDefaultFPCVersionCore('') = '',
    'normalized should be empty');
end;

procedure TestWriteManagedVersionList;
var
  Versions: TFPCVersionArray;
  Outp: TStringOutput;
  Buffer: string;
begin
  SetLength(Versions, 2);
  Versions[0].Version := '3.2.2';
  Versions[0].Installed := True;
  Versions[0].ReleaseDate := '2021-05-19';
  Versions[0].Branch := 'fixes_3_2';
  Versions[1].Version := '3.3.1';
  Versions[1].Installed := False;
  Versions[1].ReleaseDate := 'rolling';
  Versions[1].Branch := 'main';

  Outp := TStringOutput.Create;
  try
    Check('versionflow list writer succeeds',
      WriteManagedFPCVersionListCore(Versions, 'fpc-3.2.2', True, Outp),
      'list writer returned false');
    Buffer := Outp.GetBuffer;
    Check('versionflow list prints all header',
      Pos('Available FPC versions', Buffer) > 0,
      Buffer);
    Check('versionflow list marks default installed version',
      Pos('Installed*', Buffer) > 0,
      Buffer);
    Check('versionflow list prints current version footer',
      Pos('Current FPC version: 3.2.2', Buffer) > 0,
      Buffer);
  finally
    Outp.Free;
  end;
end;

procedure TestSetManagedDefaultVersion;
var
  Probe: TVersionFlowProbe;
  Outp, Errp: TStringOutput;
begin
  Probe := TVersionFlowProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Probe.Installed := True;
    Probe.SetDefaultOK := True;

    Check('setdefault helper succeeds',
      SetManagedFPCDefaultVersionCore(
        '3.2.2',
        Outp,
        Errp,
        @Probe.IsVersionInstalled,
        @Probe.SetDefaultVersion
      ),
      Errp.GetBuffer);
    Check('setdefault helper forwards version',
      Probe.LastSetDefaultVersion = '3.2.2',
      'version=' + Probe.LastSetDefaultVersion);
    Check('setdefault helper writes activated output',
      Outp.Contains('Activated FPC 3.2.2'),
      Outp.GetBuffer);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestActivateManagedVersion;
var
  Probe: TVersionFlowProbe;
  ActivResult: TActivationResult;
begin
  Probe := TVersionFlowProbe.Create;
  try
    Probe.Installed := True;
    Probe.ActivationSuccess := True;
    Probe.SetDefaultOK := True;

    ActivResult := ActivateManagedFPCVersionCore(
      '3.2.2',
      @Probe.IsVersionInstalled,
      @Probe.GetInstallPath,
      @Probe.ActivateVersion,
      @Probe.SetDefaultVersion
    );

    Check('activate helper succeeds',
      ActivResult.Success,
      ActivResult.ErrorMessage);
    Check('activate helper forwards version',
      Probe.LastActivateVersion = '3.2.2',
      'version=' + Probe.LastActivateVersion);
    Check('activate helper derives bin path',
      Probe.LastActivateBinPath = '/managed/fpc/3.2.2/bin',
      'bin=' + Probe.LastActivateBinPath);
    Check('activate helper sets default after activation',
      Probe.LastSetDefaultVersion = '3.2.2',
      'default=' + Probe.LastSetDefaultVersion);
  finally
    Probe.Free;
  end;
end;

procedure TestActivateManagedVersionFailsWhenMissing;
var
  Probe: TVersionFlowProbe;
  ActivResult: TActivationResult;
begin
  Probe := TVersionFlowProbe.Create;
  try
    Probe.Installed := False;
    Probe.ActivationSuccess := True;
    Probe.SetDefaultOK := True;

    ActivResult := ActivateManagedFPCVersionCore(
      '9.9.9',
      @Probe.IsVersionInstalled,
      @Probe.GetInstallPath,
      @Probe.ActivateVersion,
      @Probe.SetDefaultVersion
    );

    Check('activate helper fails when version missing',
      not ActivResult.Success,
      'expected failure');
    Check('activate helper reports missing version',
      Pos('not installed', ActivResult.ErrorMessage) > 0,
      ActivResult.ErrorMessage);
    Check('activate helper does not call activation callback',
      Probe.LastActivateVersion = '',
      'activation callback should not run');
  finally
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Versionflow Tests ===');

  TestNormalizeDefaultVersion;
  TestWriteManagedVersionList;
  TestSetManagedDefaultVersion;
  TestActivateManagedVersion;
  TestActivateManagedVersionFailsWhenMissing;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
