program test_fpc_builder_bootstrapcompat;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs,
  fpdev.utils.process, fpdev.utils,
  test_config_isolation,
  test_temp_paths,
  fpdev.fpc.builder;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    procedure Clear;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TStringOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

procedure Check(const AName: string; const ACondition: Boolean; const AReason: string = '');
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

procedure TestRejectsDifferentMinorSystemCompilerEvenIfNewer;
begin
  Check(
    'rejects system 3.3.1 for target 3.2.2',
    not FPCBuilderCanUseSystemCompilerAsBootstrapCore('3.2.2', '3.3.1', '3.2.0'),
    '3.3.1 reached rtl/systemh.inc failures in real 3.2.2 source builds'
  );
end;

procedure TestAcceptsSameSeriesSystemCompiler;
begin
  Check(
    'accepts system 3.2.2 for target 3.2.2',
    FPCBuilderCanUseSystemCompilerAsBootstrapCore('3.2.2', '3.2.2', '3.2.0')
  );

  Check(
    'accepts system 3.2.0 for target 3.2.2',
    FPCBuilderCanUseSystemCompilerAsBootstrapCore('3.2.2', '3.2.0', '3.2.0')
  );
end;

procedure TestRejectsOlderCompilerBelowRequiredVersion;
begin
  Check(
    'rejects system 3.1.9 for target 3.2.2',
    not FPCBuilderCanUseSystemCompilerAsBootstrapCore('3.2.2', '3.1.9', '3.2.0'),
    '3.1.9 should not satisfy the 3.2.0 bootstrap requirement for 3.2.2'
  );
end;

procedure TestAcceptsNewerPatchWithinRequiredSeries;
begin
  Check(
    'accepts system 3.0.6 for target 3.2.0',
    FPCBuilderCanUseSystemCompilerAsBootstrapCore('3.2.0', '3.0.6', '3.0.4'),
    '3.0.6 should satisfy the 3.0.4 bootstrap requirement for 3.2.0'
  );
end;

procedure TestReadsBootstrapRequirementFromDownloadedMakefile;
var
  Config: IConfigManager;
  SettingsMgr: ISettingsManager;
  Settings: TFPDevSettings;
  Builder: TFPCSourceBuilder;
  TempRoot: string;
  SourceDir: string;
  MakefilePath: string;
  Lines: TStringList;
begin
  TempRoot := CreateUniqueTempDir('fpdev-bootstrapcompat');
  Config := CreateIsolatedConfigManager;
  SettingsMgr := Config.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TempRoot;
  SettingsMgr.SetSettings(Settings);

  SourceDir := TempRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  ForceDirectories(SourceDir);
  MakefilePath := SourceDir + PathDelim + 'Makefile';

  Lines := TStringList.Create;
  try
    Lines.Add('REQUIREDVERSION=30202');
    Lines.SaveToFile(MakefilePath);
  finally
    Lines.Free;
  end;

  Builder := TFPCSourceBuilder.Create(Config);
  try
    Check(
      'reads bootstrap version from downloaded Makefile',
      Builder.GetRequiredBootstrapVersion('3.2.2') = '3.2.2',
      'bootstrap=' + Builder.GetRequiredBootstrapVersion('3.2.2')
    );
  finally
    Builder.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure WriteBuildHarnessMakefile(const AMakefilePath: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('REQUIREDVERSION=30202');
    Lines.Add('REQUIREDVERSION2=30200');
    Lines.Add('all:');
    Lines.Add(#9 + '@echo $(PP) > build-pp.txt');
    Lines.Add('install:');
    Lines.Add(#9 + '@echo $(PP) >> build-pp.txt');
    Lines.SaveToFile(AMakefilePath);
  finally
    Lines.Free;
  end;
end;

procedure WriteBootstrapStub(const APath, AVersion: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Add('#!/bin/sh');
    Lines.Add('if [ "$1" = "-iV" ]; then');
    Lines.Add('  echo "' + AVersion + '"');
    Lines.Add('  exit 0');
    Lines.Add('fi');
    Lines.Add('exit 0');
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
  TProcessExecutor.Execute('chmod', ['+x', APath], '');
end;

function ReadTrimmedTextFile(const APath: string): string;
var
  Lines: TStringList;
begin
  Result := '';
  if not FileExists(APath) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(APath);
    Result := Trim(Lines.Text);
  finally
    Lines.Free;
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure TestBuildFromSourceUsesSourceVersionForCustomPrefixBootstrap;
var
  Config: IConfigManager;
  SettingsMgr: ISettingsManager;
  Settings: TFPDevSettings;
  Builder: TFPCSourceBuilder;
  TempRoot: string;
  SourceDir: string;
  CustomPrefix: string;
  TargetBootstrapExe: string;
  RequiredBootstrapExe: string;
  MakefilePath: string;
  BuildPPPath: string;
  OutBufObj: TStringOutput;
  ErrBufObj: TStringOutput;
  OutBuf: IOutput;
  ErrBuf: IOutput;
  BuildOK: Boolean;
  SavedPath: string;
  SystemStubDir: string;
  SystemStubExe: string;
begin
  TempRoot := CreateUniqueTempDir('fpdev-custom-prefix-bootstrap');

  Config := CreateIsolatedConfigManager;
  SettingsMgr := Config.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TempRoot;
  Settings.ParallelJobs := 1;
  SettingsMgr.SetSettings(Settings);

  SourceDir := TempRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  CustomPrefix := TempRoot + PathDelim + 'custom-prefix';
  TargetBootstrapExe := TempRoot + PathDelim + 'toolchains' + PathDelim + 'fpc' +
    PathDelim + '3.2.2' + PathDelim + 'bin' + PathDelim + 'fpc';
  RequiredBootstrapExe := TempRoot + PathDelim + 'toolchains' + PathDelim + 'fpc' +
    PathDelim + '3.2.0' + PathDelim + 'bin' + PathDelim + 'fpc';
  MakefilePath := SourceDir + PathDelim + 'Makefile';
  BuildPPPath := SourceDir + PathDelim + 'build-pp.txt';

  ForceDirectories(SourceDir);
  ForceDirectories(ExtractFileDir(TargetBootstrapExe));
  ForceDirectories(ExtractFileDir(RequiredBootstrapExe));

  WriteBootstrapStub(TargetBootstrapExe, '3.2.2');
  WriteBootstrapStub(RequiredBootstrapExe, '3.2.0');
  SystemStubDir := TempRoot + PathDelim + 'system-fpc-stub';
  SystemStubExe := SystemStubDir + PathDelim + 'fpc';
  WriteBootstrapStub(SystemStubExe, '3.3.1');
  SavedPath := GetEnvironmentVariable('PATH');
  if SavedPath <> '' then
    set_env('PATH', SystemStubDir + PathSeparator + SavedPath)
  else
    set_env('PATH', SystemStubDir);

  WriteBuildHarnessMakefile(MakefilePath);

  OutBufObj := TStringOutput.Create;
  ErrBufObj := TStringOutput.Create;
  OutBuf := OutBufObj as IOutput;
  ErrBuf := ErrBufObj as IOutput;

  Builder := TFPCSourceBuilder.Create(Config, OutBuf, ErrBuf);
  try
    Check(
      'ensure bootstrap prefers installed target compiler',
      Builder.EnsureBootstrapCompiler('3.2.2'),
      ErrBufObj.Text
    );
    Check(
      'ensure bootstrap rejects incompatible system compiler',
      OutBufObj.Contains('System FPC version 3.3.1 is not bootstrap-compatible with target 3.2.2'),
      OutBufObj.Text
    );
    Check(
      'ensure bootstrap falls back to installed compiler',
      OutBufObj.Contains('OK: Installed bootstrap compiler available at: ' + TargetBootstrapExe),
      OutBufObj.Text
    );

    OutBufObj.Clear;
    ErrBufObj.Clear;
    BuildOK := Builder.BuildFromSource(SourceDir, CustomPrefix);
    Check('custom prefix harness build succeeds', BuildOK, ErrBufObj.Text);
    Check(
      'custom prefix build uses installed bootstrap compiler',
      OutBufObj.Contains('Using installed FPC 3.2.2 as bootstrap compiler'),
      OutBufObj.Text
    );
    Check(
      'custom prefix executing line includes PP',
      OutBufObj.Contains('PP=' + TargetBootstrapExe),
      OutBufObj.Text
    );
    Check(
      'make receives PP from installed bootstrap',
      Pos(TargetBootstrapExe, ReadTrimmedTextFile(BuildPPPath)) > 0,
      ReadTrimmedTextFile(BuildPPPath)
    );
  finally
    Builder.Free;
    RestoreEnv('PATH', SavedPath);
    CleanupTempDir(TempRoot);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  FPC Builder Bootstrap Compatibility');
  WriteLn('========================================');

  TestRejectsDifferentMinorSystemCompilerEvenIfNewer;
  TestAcceptsSameSeriesSystemCompiler;
  TestRejectsOlderCompilerBelowRequiredVersion;
  TestAcceptsNewerPatchWithinRequiredSeries;
  TestReadsBootstrapRequirementFromDownloadedMakefile;
  TestBuildFromSourceUsesSourceVersionForCustomPrefixBootstrap;

  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
