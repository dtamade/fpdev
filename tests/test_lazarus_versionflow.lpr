program test_lazarus_versionflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.lazarus.types,
  fpdev.lazarus.versionflow,
  test_cli_helpers;

type
  TVersionFlowProbe = class
  public
    Installed: Boolean;
    SetDefaultOK: Boolean;
    ConfiguredLookupHit: Boolean;
    LastSetDefaultVersion: string;
    LastInstallPathVersion: string;
    LastLazarusInfoVersion: string;

    function IsVersionInstalled(const AVersion: string): Boolean;
    function SetDefaultVersion(const AVersion: string): Boolean;
    function LookupConfiguredVersionInfo(
      const AVersion: string;
      out AVersionInfo: TLazarusVersionInfo
    ): Boolean;
    function ResolveInstallPath(const AVersion: string): string;
    function LookupLazarusInfo(const AVersion: string; out ALazarusInfo: TLazarusInfo): Boolean;
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
  if AVersion <> '' then;
  Result := Installed;
end;

function TVersionFlowProbe.SetDefaultVersion(const AVersion: string): Boolean;
begin
  LastSetDefaultVersion := AVersion;
  Result := SetDefaultOK;
end;

function TVersionFlowProbe.LookupConfiguredVersionInfo(
  const AVersion: string;
  out AVersionInfo: TLazarusVersionInfo
): Boolean;
begin
  AVersionInfo := Default(TLazarusVersionInfo);
  ConfiguredLookupHit := True;
  if not SameText(AVersion, '9.9') then
    Exit(False);

  AVersionInfo.Version := '9.9';
  AVersionInfo.ReleaseDate := '';
  AVersionInfo.GitTag := '';
  AVersionInfo.Branch := 'custom_branch';
  AVersionInfo.FPCVersion := '3.2.2';
  AVersionInfo.Available := False;
  AVersionInfo.Installed := False;
  Result := True;
end;

function TVersionFlowProbe.ResolveInstallPath(const AVersion: string): string;
begin
  LastInstallPathVersion := AVersion;
  Result := '/managed/lazarus/' + AVersion;
end;

function TVersionFlowProbe.LookupLazarusInfo(
  const AVersion: string;
  out ALazarusInfo: TLazarusInfo
): Boolean;
begin
  LastLazarusInfoVersion := AVersion;
  FillChar(ALazarusInfo, SizeOf(ALazarusInfo), 0);
  Result := SameText(AVersion, '9.9');
  if Result then
    ALazarusInfo.SourceURL := 'https://example.com/lazarus.git';
end;

procedure TestNormalizeDefaultVersion;
begin
  Check(
    'normalize strips lazarus prefix',
    NormalizeDefaultLazarusVersionCore('lazarus-3.0') = '3.0',
    'normalized=' + NormalizeDefaultLazarusVersionCore('lazarus-3.0')
  );
  Check(
    'normalize keeps plain version',
    NormalizeDefaultLazarusVersionCore('3.2') = '3.2',
    'normalized=' + NormalizeDefaultLazarusVersionCore('3.2')
  );
end;

procedure TestWriteManagedVersionList;
var
  Versions: TLazarusVersionArray;
  Outp: TStringOutput;
  Buffer: string;
begin
  SetLength(Versions, 2);
  Versions[0].Version := '3.0';
  Versions[0].Installed := True;
  Versions[0].ReleaseDate := '2024-01-01';
  Versions[0].FPCVersion := '3.2.2';
  Versions[0].Branch := 'lazarus_3_0';
  Versions[1].Version := '4.0';
  Versions[1].Installed := False;
  Versions[1].ReleaseDate := 'rolling';
  Versions[1].FPCVersion := '3.2.4';
  Versions[1].Branch := 'main';

  Outp := TStringOutput.Create;
  try
    Check(
      'versionflow list writer succeeds',
      WriteManagedLazarusVersionListCore(Versions, 'lazarus-3.0', True, Outp),
      'list writer returned false'
    );
    Buffer := Outp.GetBuffer;
    Check(
      'versionflow list marks default installed version',
      Pos('Installed*', Buffer) > 0,
      Buffer
    );
    Check(
      'versionflow list includes fpc column',
      Pos('3.2.2', Buffer) > 0,
      Buffer
    );
  finally
    Outp.Free;
  end;
end;

procedure TestSetManagedDefaultVersionGuard;
var
  Probe: TVersionFlowProbe;
  Outp: TStringOutput;
  Errp: TStringOutput;
begin
  Probe := TVersionFlowProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Probe.Installed := False;
    Probe.SetDefaultOK := True;

    Check(
      'setdefault helper fails for missing install',
      not SetManagedLazarusDefaultVersionCore(
        '9.9',
        Outp,
        Errp,
        @Probe.IsVersionInstalled,
        @Probe.SetDefaultVersion
      ),
      'expected missing install guard'
    );
    Check(
      'setdefault helper does not call setter when missing',
      Probe.LastSetDefaultVersion = '',
      'setter should not run'
    );
    Check(
      'setdefault helper writes missing install error',
      Errp.GetBuffer <> '',
      'expected error output'
    );
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestShowVersionInfoFallsBackToConfiguredInfo;
var
  Probe: TVersionFlowProbe;
  Outp: TStringOutput;
  Versions: TLazarusVersionArray;
  Buffer: string;
begin
  Probe := TVersionFlowProbe.Create;
  Outp := TStringOutput.Create;
  try
    Probe.Installed := False;
    SetLength(Versions, 1);
    Versions[0].Version := '3.0';
    Versions[0].Installed := True;
    Versions[0].Branch := 'lazarus_3_0';
    Versions[0].FPCVersion := '3.2.0';

    Check(
      'show-info helper falls back to configured version info',
      ShowManagedLazarusVersionInfoCore(
        '9.9',
        Outp,
        Versions,
        @Probe.LookupConfiguredVersionInfo,
        @Probe.IsVersionInstalled,
        @Probe.ResolveInstallPath,
        @Probe.LookupLazarusInfo
      ),
      'expected configured fallback to succeed'
    );
    Buffer := Outp.GetBuffer;
    Check(
      'show-info helper looked up configured version',
      Probe.ConfiguredLookupHit,
      'configured lookup not used'
    );
    Check(
      'show-info helper prints configured version',
      Pos('Version:      9.9', Buffer) > 0,
      Buffer
    );
    Check(
      'show-info helper prints configured branch',
      Pos('Branch:       custom_branch', Buffer) > 0,
      Buffer
    );
  finally
    Outp.Free;
    Probe.Free;
  end;
end;

begin
  WriteLn('=== Lazarus Versionflow Tests ===');

  TestNormalizeDefaultVersion;
  TestWriteManagedVersionList;
  TestSetManagedDefaultVersionGuard;
  TestShowVersionInfoFallsBackToConfiguredInfo;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
