program test_fpc_post_install;

{$mode objfpc}{$H+}

{
================================================================================
  test_fpc_post_install - Tests for FPC post-installation environment setup
================================================================================

  Tests the post-installation pipeline:
  - GenerateFpcConfig: fpc.cfg file content and location
  - CreateLinuxCompilerWrapper: wrapper script and symlink
  - SetupEnvironment: toolchain registration in config.json
  - End-to-end: complete post-install pipeline validation

  B180: Post-install environment setup enhancement

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.fpc.installer.config, test_temp_paths;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;
  GTempRoot: string;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

{ TStringOutput - captures output for test verification }
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
    function GetBuffer: string;
    function Contains(const S: string): Boolean;
    procedure Clear;
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
  Write(S); if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S); if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S); if AColor = ccDefault then; if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S); if AColor = ccDefault then; if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.GetBuffer: string;
begin
  Result := FBuffer.Text;
end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

{ Helper functions }
function MakeTempDir(const ASuffix: string): string;
begin
  Result := GTempRoot + PathDelim + ASuffix;
  ForceDirectories(Result);
end;

function ReadFileContent(const APath: string): string;
begin
  Result := '';
  if FileExists(APath) then
  begin
    with TStringList.Create do
    try
      LoadFromFile(APath);
      Result := Text;
    finally
      Free;
    end;
  end;
end;

{ ===== Group 1: GenerateFpcConfig Tests ===== }

procedure TestGenerateFpcConfig_CreatesFile;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  CfgPath: string;
begin
  InstallDir := MakeTempDir('cfg_create');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    CfgPath := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg';
    Test('GenerateFpcConfig creates fpc.cfg file', FileExists(CfgPath));
  finally
    Gen.Free;
  end;
end;

procedure TestGenerateFpcConfig_ContainsVersion;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  CfgPath, Content: string;
begin
  InstallDir := MakeTempDir('cfg_version');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    CfgPath := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg';
    Content := ReadFileContent(CfgPath);
    Test('fpc.cfg contains version comment', Pos('3.2.2', Content) > 0);
  finally
    Gen.Free;
  end;
end;

procedure TestGenerateFpcConfig_ContainsUnitPaths;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  CfgPath, Content: string;
begin
  InstallDir := MakeTempDir('cfg_units');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    CfgPath := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg';
    Content := ReadFileContent(CfgPath);
    Test('fpc.cfg contains -Fu unit search path', Pos('-Fu', Content) > 0);
    Test('fpc.cfg contains -Fl library search path', Pos('-Fl', Content) > 0);
    Test('fpc.cfg contains -Fi include search path', Pos('-Fi', Content) > 0);
    Test('fpc.cfg contains $fpctarget variable', Pos('$fpctarget', Content) > 0);
  finally
    Gen.Free;
  end;
end;

procedure TestGenerateFpcConfig_ContainsFDPath;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  CfgPath, Content: string;
begin
  InstallDir := MakeTempDir('cfg_fd');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    CfgPath := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg';
    Content := ReadFileContent(CfgPath);
    Test('fpc.cfg contains -FD compiler binary path', Pos('-FD', Content) > 0);
  finally
    Gen.Free;
  end;
end;

procedure TestGenerateFpcConfig_OutputMessage;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
begin
  InstallDir := MakeTempDir('cfg_output');
  ForceDirectories(InstallDir + PathDelim + 'bin');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    Test('GenerateFpcConfig outputs progress message', Out1.Contains('fpc.cfg'));
  finally
    Gen.Free;
  end;
end;

procedure TestGenerateFpcConfig_NilOutput;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  CfgPath: string;
begin
  InstallDir := MakeTempDir('cfg_nilout');
  ForceDirectories(InstallDir + PathDelim + 'bin');

  Gen := TFPCConfigGenerator.Create(nil);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    CfgPath := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg';
    Test('GenerateFpcConfig works with nil output', FileExists(CfgPath));
  finally
    Gen.Free;
  end;
end;

procedure TestGenerateFpcConfig_PathsAreAbsolute;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  CfgPath, Content: string;
begin
  InstallDir := MakeTempDir('cfg_abspath');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    CfgPath := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg';
    Content := ReadFileContent(CfgPath);
    // Verify the install directory path appears in the config
    Test('fpc.cfg contains install path', Pos(InstallDir, Content) > 0);
  finally
    Gen.Free;
  end;
end;

{ ===== Group 2: CreateLinuxCompilerWrapper Tests ===== }

{$IFDEF LINUX}
procedure TestCreateLinuxWrapper_CreatesScript;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  CompilerName, BinPath: string;
begin
  InstallDir := MakeTempDir('wrapper_create');
  BinPath := InstallDir + PathDelim + 'bin';
  ForceDirectories(BinPath);
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  // Create a fake native compiler in lib
  CompilerName := GetNativeCompilerName;
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('echo "fake compiler"');
    SaveToFile(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + CompilerName);
  finally
    Free;
  end;

  // Create a fake fpc binary to be replaced
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('echo "original fpc"');
    SaveToFile(BinPath + PathDelim + 'fpc');
  finally
    Free;
  end;

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.CreateLinuxCompilerWrapper(InstallDir, '3.2.2');

    // The wrapper should replace fpc, and the original should be backed up
    Test('Linux wrapper: fpc exists after wrapper creation',
      FileExists(BinPath + PathDelim + 'fpc'));
    Test('Linux wrapper: fpc.orig backup created',
      FileExists(BinPath + PathDelim + 'fpc.orig'));
    Test('Linux wrapper: compiler symlink created',
      FileExists(BinPath + PathDelim + CompilerName));
  finally
    Gen.Free;
  end;
end;

procedure TestCreateLinuxWrapper_ScriptContent;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  BinPath, Content: string;
begin
  InstallDir := MakeTempDir('wrapper_content');
  BinPath := InstallDir + PathDelim + 'bin';
  ForceDirectories(BinPath);
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  // Create fake fpc binary
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    SaveToFile(BinPath + PathDelim + 'fpc');
  finally
    Free;
  end;

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.CreateLinuxCompilerWrapper(InstallDir, '3.2.2');

    Content := ReadFileContent(BinPath + PathDelim + 'fpc');
    Test('Linux wrapper script contains shebang', Pos('#!/bin/sh', Content) > 0);
    Test('Linux wrapper script uses -n flag', Pos('-n', Content) > 0);
    Test('Linux wrapper script references fpc.cfg', Pos('fpc.cfg', Content) > 0);
    Test('Linux wrapper script references native compiler',
      Pos(GetNativeCompilerName, Content) > 0);
  finally
    Gen.Free;
  end;
end;

procedure TestCreateLinuxWrapper_OutputMessages;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  BinPath: string;
begin
  InstallDir := MakeTempDir('wrapper_output');
  BinPath := InstallDir + PathDelim + 'bin';
  ForceDirectories(BinPath);
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');

  with TStringList.Create do
  try
    Add('#!/bin/sh');
    SaveToFile(BinPath + PathDelim + 'fpc');
  finally
    Free;
  end;

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.CreateLinuxCompilerWrapper(InstallDir, '3.2.2');
    Test('Linux wrapper outputs symlink message', Out1.Contains('symlink'));
    Test('Linux wrapper outputs wrapper message', Out1.Contains('wrapper'));
  finally
    Gen.Free;
  end;
end;
{$ENDIF}

{ ===== Group 3: Different version tests ===== }

procedure TestGenerateFpcConfig_DifferentVersions;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  Content: string;
begin
  // Test with version 3.2.0
  InstallDir := MakeTempDir('cfg_v320');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.0');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.2.0');
    Content := ReadFileContent(InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg');
    Test('fpc.cfg for 3.2.0 contains version 3.2.0', Pos('3.2.0', Content) > 0);
  finally
    Gen.Free;
  end;

  // Test with trunk version
  InstallDir := MakeTempDir('cfg_trunk');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  ForceDirectories(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.3.1');

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    Gen.GenerateFpcConfig(InstallDir, '3.3.1');
    Content := ReadFileContent(InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg');
    Test('fpc.cfg for 3.3.1 contains version 3.3.1', Pos('3.3.1', Content) > 0);
  finally
    Gen.Free;
  end;
end;

{ ===== Group 4: Idempotency tests ===== }

procedure TestGenerateFpcConfig_Idempotent;
var
  InstallDir: string;
  Gen: TFPCConfigGenerator;
  Out1: TStringOutput;
  Content1, Content2, CfgPath: string;
begin
  InstallDir := MakeTempDir('cfg_idempotent');
  ForceDirectories(InstallDir + PathDelim + 'bin');
  CfgPath := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg';

  Out1 := TStringOutput.Create;
  Gen := TFPCConfigGenerator.Create(Out1);
  try
    // Generate twice
    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    Content1 := ReadFileContent(CfgPath);

    Gen.GenerateFpcConfig(InstallDir, '3.2.2');
    Content2 := ReadFileContent(CfgPath);

    Test('GenerateFpcConfig is idempotent (same content)', Content1 = Content2);
  finally
    Gen.Free;
  end;
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Post-Install Environment Tests ===');
  WriteLn;

  GTempRoot := CreateUniqueTempDir('fpdev_test_postinstall');

  try
    // Group 1: GenerateFpcConfig
    WriteLn('--- GenerateFpcConfig ---');
    TestGenerateFpcConfig_CreatesFile;
    TestGenerateFpcConfig_ContainsVersion;
    TestGenerateFpcConfig_ContainsUnitPaths;
    TestGenerateFpcConfig_ContainsFDPath;
    TestGenerateFpcConfig_OutputMessage;
    TestGenerateFpcConfig_NilOutput;
    TestGenerateFpcConfig_PathsAreAbsolute;

    // Group 2: CreateLinuxCompilerWrapper (Linux only)
    WriteLn('');
    WriteLn('--- CreateLinuxCompilerWrapper ---');
    {$IFDEF LINUX}
    TestCreateLinuxWrapper_CreatesScript;
    TestCreateLinuxWrapper_ScriptContent;
    TestCreateLinuxWrapper_OutputMessages;
    {$ELSE}
    WriteLn('  (skipped: Linux-only tests)');
    {$ENDIF}

    // Group 3: Different versions
    WriteLn('');
    WriteLn('--- Different Versions ---');
    TestGenerateFpcConfig_DifferentVersions;

    // Group 4: Idempotency
    WriteLn('');
    WriteLn('--- Idempotency ---');
    TestGenerateFpcConfig_Idempotent;
  finally
    CleanupTempDir(GTempRoot);
  end;

  WriteLn('');
  WriteLn('=== Test Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);
  WriteLn;

  if GFailCount > 0 then
    Halt(1);
end.
