program test_fpc_sourcebootstrapflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.sourcebootstrapflow,
  test_temp_paths;

type
  TBootstrapProbe = class
  public
    RequiredVersionValue: string;
    SystemCompilerValue: string;
    CompatibleResult: Boolean;
    DownloadResult: Boolean;
    DownloadCalls: Integer;
    ExtractCalls: Integer;
    Logged: TStringList;
    SourceRoot: string;
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AText: string);
    function GetRequiredVersion(const ATargetVersion: string): string;
    function FindSystemCompiler: string;
    function IsCompatible(const ACompilerPath, ARequiredVersion: string): Boolean;
    function DownloadBootstrap(const AVersion: string): Boolean;
    function GetDownloadURL(const AVersion: string): string;
    function GetBootstrapPath(const AVersion: string): string;
    function DownloadArchive(const AURL, ADestFile: string): Boolean;
    function ExtractArchive(const AArchive, ADestDir: string; out AEntryCount: Integer): Boolean;
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

constructor TBootstrapProbe.Create;
begin
  inherited Create;
  Logged := TStringList.Create;
  DownloadResult := True;
  RequiredVersionValue := '3.0.4';
end;

destructor TBootstrapProbe.Destroy;
begin
  Logged.Free;
  inherited Destroy;
end;

procedure TBootstrapProbe.Log(const AText: string);
begin
  Logged.Add(AText);
end;

function TBootstrapProbe.GetRequiredVersion(const ATargetVersion: string): string;
begin
  if ATargetVersion = '' then;
  Result := RequiredVersionValue;
end;

function TBootstrapProbe.FindSystemCompiler: string;
begin
  Result := SystemCompilerValue;
end;

function TBootstrapProbe.IsCompatible(
  const ACompilerPath, ARequiredVersion: string): Boolean;
begin
  if ACompilerPath = '' then;
  if ARequiredVersion = '' then;
  Result := CompatibleResult;
end;

function TBootstrapProbe.GetDownloadURL(const AVersion: string): string;
begin
  Result := 'https://example.invalid/fpc-' + AVersion + '.zip';
end;

function TBootstrapProbe.DownloadBootstrap(const AVersion: string): Boolean;
begin
  Inc(DownloadCalls);
  if AVersion = '' then;
  Result := DownloadResult;
end;

function TBootstrapProbe.GetBootstrapPath(const AVersion: string): string;
begin
  Result := SourceRoot + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion +
    PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function TBootstrapProbe.DownloadArchive(const AURL, ADestFile: string): Boolean;
begin
  Inc(DownloadCalls);
  if AURL = '' then;
  ForceDirectories(ExtractFileDir(ADestFile));
  with TStringList.Create do
  try
    Add('zip-placeholder');
    SaveToFile(ADestFile);
  finally
    Free;
  end;
  Result := DownloadResult;
end;

function TBootstrapProbe.ExtractArchive(
  const AArchive, ADestDir: string; out AEntryCount: Integer): Boolean;
var
  BinaryPath: string;
begin
  Inc(ExtractCalls);
  if AArchive = '' then;
  ForceDirectories(ADestDir + PathDelim + 'bin');
  BinaryPath := ADestDir + PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  BinaryPath := BinaryPath + '.exe';
  {$ENDIF}
  with TStringList.Create do
  try
    Add('binary');
    SaveToFile(BinaryPath);
  finally
    Free;
  end;
  AEntryCount := 1;
  Result := True;
end;

function MakeEnsureCallbacks(AProbe: TBootstrapProbe): TFPCSourceBootstrapEnsureCallbacks;
begin
  Result := Default(TFPCSourceBootstrapEnsureCallbacks);
  Result.GetRequiredVersion := @AProbe.GetRequiredVersion;
  Result.FindSystemCompiler := @AProbe.FindSystemCompiler;
  Result.IsCompatibleCompiler := @AProbe.IsCompatible;
  Result.GetBootstrapPath := @AProbe.GetBootstrapPath;
  Result.DownloadBootstrap := @AProbe.DownloadBootstrap;
end;

function MakeDownloadCallbacks(AProbe: TBootstrapProbe): TFPCSourceBootstrapDownloadCallbacks;
begin
  Result := Default(TFPCSourceBootstrapDownloadCallbacks);
  Result.Log := @AProbe.Log;
  Result.GetDownloadURL := @AProbe.GetDownloadURL;
  Result.GetBootstrapPath := @AProbe.GetBootstrapPath;
  Result.DownloadArchive := @AProbe.DownloadArchive;
  Result.ExtractArchive := @AProbe.ExtractArchive;
end;

procedure TestEnsureUsesSystemCompilerWhenCompatible;
var
  Probe: TBootstrapProbe;
  BootstrapCompiler: string;
  OK: Boolean;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.SystemCompilerValue := '/usr/bin/fpc';
    Probe.CompatibleResult := True;
    BootstrapCompiler := '';

    OK := ExecuteFPCSourceEnsureBootstrapCore(
      '3.2.2',
      BootstrapCompiler,
      MakeEnsureCallbacks(Probe)
    );

    Check('bootstrapflow uses compatible system compiler', OK, 'expected success');
    Check('bootstrapflow stores system compiler path',
      BootstrapCompiler = '/usr/bin/fpc', BootstrapCompiler);
    Check('bootstrapflow skips download when system compiler is compatible',
      Probe.DownloadCalls = 0, 'download calls=' + IntToStr(Probe.DownloadCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestEnsureUsesDownloadedBootstrapWhenPresent;
var
  Probe: TBootstrapProbe;
  TempRoot: string;
  BootstrapCompiler: string;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcebootstrapflow_existing');
  Probe := TBootstrapProbe.Create;
  try
    Probe.SourceRoot := TempRoot;
    Probe.SystemCompilerValue := '';
    Probe.CompatibleResult := False;
    ForceDirectories(ExtractFileDir(Probe.GetBootstrapPath('3.0.4')));
    with TStringList.Create do
    try
      Add('existing');
      SaveToFile(Probe.GetBootstrapPath('3.0.4'));
    finally
      Free;
    end;
    BootstrapCompiler := '';

    OK := ExecuteFPCSourceEnsureBootstrapCore(
      '3.2.2',
      BootstrapCompiler,
      MakeEnsureCallbacks(Probe)
    );

    Check('bootstrapflow uses downloaded bootstrap when present', OK, 'expected success');
    Check('bootstrapflow stores downloaded bootstrap path',
      BootstrapCompiler = Probe.GetBootstrapPath('3.0.4'), BootstrapCompiler);
    Check('bootstrapflow does not redownload existing bootstrap',
      Probe.DownloadCalls = 0, 'download calls=' + IntToStr(Probe.DownloadCalls));
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

procedure TestDownloadBootstrapSuccessPath;
var
  Probe: TBootstrapProbe;
  TempRoot: string;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcebootstrapflow_download');
  Probe := TBootstrapProbe.Create;
  try
    Probe.SourceRoot := TempRoot;

    OK := ExecuteFPCSourceBootstrapDownloadCore(
      '3.0.4',
      TempRoot,
      MakeDownloadCallbacks(Probe)
    );

    Check('bootstrapflow download helper succeeds', OK, 'expected success');
    Check('bootstrapflow download helper downloads archive',
      Probe.DownloadCalls = 1, 'download calls=' + IntToStr(Probe.DownloadCalls));
    Check('bootstrapflow download helper extracts archive',
      Probe.ExtractCalls = 1, 'extract calls=' + IntToStr(Probe.ExtractCalls));
    Check('bootstrapflow download helper materializes bootstrap compiler',
      FileExists(Probe.GetBootstrapPath('3.0.4')), Probe.GetBootstrapPath('3.0.4'));
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

procedure TestEnsureFailsWhenDownloadFails;
var
  Probe: TBootstrapProbe;
  BootstrapCompiler: string;
  OK: Boolean;
begin
  Probe := TBootstrapProbe.Create;
  try
    Probe.SystemCompilerValue := '';
    Probe.CompatibleResult := False;
    Probe.DownloadResult := False;
    BootstrapCompiler := '';

    OK := ExecuteFPCSourceEnsureBootstrapCore(
      '3.2.2',
      BootstrapCompiler,
      MakeEnsureCallbacks(Probe)
    );

    Check('bootstrapflow returns false when bootstrap download fails',
      not OK, 'expected failure');
    Check('bootstrapflow leaves bootstrap compiler empty on failure',
      BootstrapCompiler = '', BootstrapCompiler);
  finally
    Probe.Free;
  end;
end;

begin
  TestEnsureUsesSystemCompilerWhenCompatible;
  TestEnsureUsesDownloadedBootstrapWhenPresent;
  TestDownloadBootstrapSuccessPath;
  TestEnsureFailsWhenDownloadFails;

  if FailCount > 0 then
    Halt(1);
end.
