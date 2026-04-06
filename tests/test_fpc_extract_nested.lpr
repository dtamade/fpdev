program test_fpc_extract_nested;

{$mode objfpc}{$H+}

{
================================================================================
  test_fpc_extract_nested - Tests for FPC nested package extraction logic
================================================================================

  Tests the TFPCArchiveExtractor helper methods in isolation:
  - FindBinaryArchive: locate binary.*.tar in extracted directory
  - FindBaseArchive: locate base.*.tar.gz in inner directory
  - ExtractLinuxFPCTarball: full 3-step pipeline with real tar commands

  Also tests the post-extraction validation logic:
  - Verify bin/ directory exists after extraction
  - Verify lib/ directory exists after extraction
  - Handle missing binary archive gracefully
  - Handle missing base archive gracefully

  B177: Manifest installation path fix - TDD Red Phase

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.fpc.installer.extract, fpdev.utils.process, test_temp_paths;

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

{ Helper: create a temp directory under GTempRoot }
function MakeTempDir(const ASuffix: string): string;
begin
  Result := GTempRoot + PathDelim + ASuffix;
  ForceDirectories(Result);
end;

{ Helper: create a file with content }
procedure CreateFile(const APath, AContent: string);
begin
  ForceDirectories(ExtractFilePath(APath));
  with TStringList.Create do
  try
    Text := AContent;
    SaveToFile(APath);
  finally
    Free;
  end;
end;

{ ===== Group 1: FindBinaryArchive Tests ===== }

procedure TestFindBinaryArchive_EmptyDir;
var
  Dir: string;
begin
  Dir := MakeTempDir('find_bin_empty');
  Test('FindBinaryArchive returns empty for empty dir',
    TFPCArchiveExtractor.FindBinaryArchive(Dir) = '');
end;

procedure TestFindBinaryArchive_NoBinaryFile;
var
  Dir: string;
begin
  Dir := MakeTempDir('find_bin_nobin');
  CreateFile(Dir + PathDelim + 'readme.txt', 'test');
  CreateFile(Dir + PathDelim + 'install.sh', 'test');
  Test('FindBinaryArchive returns empty when no binary.* file',
    TFPCArchiveExtractor.FindBinaryArchive(Dir) = '');
end;

procedure TestFindBinaryArchive_WithBinaryTar;
var
  Dir, Found: string;
begin
  Dir := MakeTempDir('find_bin_ok');
  CreateFile(Dir + PathDelim + 'binary.x86_64-linux.tar', 'dummy tar');
  CreateFile(Dir + PathDelim + 'install.sh', 'test');
  Found := TFPCArchiveExtractor.FindBinaryArchive(Dir);
  Test('FindBinaryArchive finds binary.x86_64-linux.tar',
    Pos('binary.x86_64-linux.tar', Found) > 0);
end;

procedure TestFindBinaryArchive_WithBinaryTarAarch64;
var
  Dir, Found: string;
begin
  Dir := MakeTempDir('find_bin_aarch64');
  CreateFile(Dir + PathDelim + 'binary.aarch64-linux.tar', 'dummy tar');
  Found := TFPCArchiveExtractor.FindBinaryArchive(Dir);
  Test('FindBinaryArchive finds binary.aarch64-linux.tar',
    Pos('binary.aarch64-linux.tar', Found) > 0);
end;

{ ===== Group 2: FindBaseArchive Tests ===== }

procedure TestFindBaseArchive_EmptyDir;
var
  Dir: string;
begin
  Dir := MakeTempDir('find_base_empty');
  Test('FindBaseArchive returns empty for empty dir',
    TFPCArchiveExtractor.FindBaseArchive(Dir) = '');
end;

procedure TestFindBaseArchive_NoBaseFile;
var
  Dir: string;
begin
  Dir := MakeTempDir('find_base_nobase');
  CreateFile(Dir + PathDelim + 'utils-3.2.2.tar.gz', 'dummy');
  CreateFile(Dir + PathDelim + 'demo-3.2.2.tar.gz', 'dummy');
  Test('FindBaseArchive returns empty when no base.* file',
    TFPCArchiveExtractor.FindBaseArchive(Dir) = '');
end;

procedure TestFindBaseArchive_WithBaseTarGz;
var
  Dir, Found: string;
begin
  Dir := MakeTempDir('find_base_ok');
  CreateFile(Dir + PathDelim + 'base.x86_64-linux.tar.gz', 'dummy');
  CreateFile(Dir + PathDelim + 'utils-3.2.2.tar.gz', 'dummy');
  Found := TFPCArchiveExtractor.FindBaseArchive(Dir);
  Test('FindBaseArchive finds base.x86_64-linux.tar.gz',
    Pos('base.x86_64-linux.tar.gz', Found) > 0);
end;

{ ===== Group 3: ExtractLinuxFPCTarball with real tar (integration) ===== }

procedure TestExtractLinuxFPCTarball_BadTarFile;
var
  TempDir, InstallDir: string;
  StdOut, StdErr: TStringOutput;
  Res: TFPCExtractResult;
begin
  TempDir := MakeTempDir('extract_bad');
  InstallDir := MakeTempDir('install_bad');
  StdOut := TStringOutput.Create;
  StdErr := TStringOutput.Create;

  // Create a fake tar file that is not a valid archive
  CreateFile(TempDir + PathDelim + 'bad.tar', 'not a real tar');

  Res := TFPCArchiveExtractor.ExtractLinuxFPCTarball(
    TempDir + PathDelim + 'bad.tar', TempDir, InstallDir,
    StdOut, StdErr);

  Test('Bad tar file extraction fails', not Res.Success);
  Test('Bad tar file gives error message', Res.ErrorMsg <> '');
end;

{ ===== Group 4: Post-extraction validation ===== }

procedure TestValidateInstall_EmptyDir;
var
  Dir: string;
  HasBin, HasLib: Boolean;
begin
  Dir := MakeTempDir('validate_empty');
  HasBin := DirectoryExists(Dir + PathDelim + 'bin');
  HasLib := DirectoryExists(Dir + PathDelim + 'lib');
  Test('Empty install dir has no bin/', not HasBin);
  Test('Empty install dir has no lib/', not HasLib);
end;

procedure TestValidateInstall_WithBinAndLib;
var
  Dir: string;
  HasBin, HasLib: Boolean;
begin
  Dir := MakeTempDir('validate_ok');
  ForceDirectories(Dir + PathDelim + 'bin');
  ForceDirectories(Dir + PathDelim + 'lib');
  HasBin := DirectoryExists(Dir + PathDelim + 'bin');
  HasLib := DirectoryExists(Dir + PathDelim + 'lib');
  Test('Valid install dir has bin/', HasBin);
  Test('Valid install dir has lib/', HasLib);
end;

procedure TestValidateInstall_OnlyBin;
var
  Dir: string;
  HasBin, HasLib: Boolean;
begin
  Dir := MakeTempDir('validate_binonly');
  ForceDirectories(Dir + PathDelim + 'bin');
  HasBin := DirectoryExists(Dir + PathDelim + 'bin');
  HasLib := DirectoryExists(Dir + PathDelim + 'lib');
  Test('Partial install has bin/', HasBin);
  Test('Partial install has no lib/', not HasLib);
end;

{ ===== Group 5: Real tarball extraction pipeline ===== }

procedure TestExtractPipeline_CreateFakeFPCStructure;
var
  SrcDir, TempDir, InstallDir: string;
  StdOut, StdErr: TStringOutput;
  Res: TFPCExtractResult;
  ProcRes: fpdev.utils.process.TProcessResult;
  InnerDir: string;
begin
  // Create a fake FPC tarball structure:
  //   fpc-3.2.2.x86_64-linux/
  //     binary.x86_64-linux.tar  (contains base.x86_64-linux.tar.gz)
  //   The base.tar.gz contains bin/ and lib/ directories
  SrcDir := MakeTempDir('pipeline_src');
  TempDir := MakeTempDir('pipeline_temp');
  InstallDir := MakeTempDir('pipeline_install');

  // Step 1: Create the base content (bin/ and lib/)
  InnerDir := SrcDir + PathDelim + 'base_content';
  ForceDirectories(InnerDir + PathDelim + 'bin');
  ForceDirectories(InnerDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');
  CreateFile(InnerDir + PathDelim + 'bin' + PathDelim + 'fpc', '#!/bin/sh' + LineEnding + 'echo FPC 3.2.2');
  CreateFile(InnerDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'ppcx64', 'dummy');

  // Step 2: Create base.x86_64-linux.tar.gz from base_content
  ProcRes := TProcessExecutor.Execute('tar', [
    '-czf', SrcDir + PathDelim + 'base.x86_64-linux.tar.gz',
    '-C', InnerDir, 'bin', 'lib'], '');
  Test('Create base.tar.gz succeeds', ProcRes.Success);

  // Step 3: Create binary.x86_64-linux.tar containing base.tar.gz
  ProcRes := TProcessExecutor.Execute('tar', [
    '-cf', SrcDir + PathDelim + 'binary.x86_64-linux.tar',
    '-C', SrcDir, 'base.x86_64-linux.tar.gz'], '');
  Test('Create binary.tar succeeds', ProcRes.Success);

  // Step 4: Create outer fpc directory structure
  ForceDirectories(SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux');
  // Move binary tar into subdirectory
  ProcRes := TProcessExecutor.Execute('mv', [
    SrcDir + PathDelim + 'binary.x86_64-linux.tar',
    SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux' + PathDelim + 'binary.x86_64-linux.tar'], '');
  Test('Move binary.tar into subdir succeeds', ProcRes.Success);

  // Step 5: Create outer tar
  ProcRes := TProcessExecutor.Execute('tar', [
    '-cf', SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux.tar',
    '-C', SrcDir, 'fpc-3.2.2.x86_64-linux'], '');
  Test('Create outer tar succeeds', ProcRes.Success);

  // Step 6: Run the full extraction pipeline
  StdOut := TStringOutput.Create;
  StdErr := TStringOutput.Create;

  Res := TFPCArchiveExtractor.ExtractLinuxFPCTarball(
    SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux.tar',
    TempDir, InstallDir, StdOut, StdErr);

  Test('Full pipeline extraction succeeds', Res.Success);
  Test('Full pipeline has no error', Res.ErrorMsg = '');
  Test('Install dir has bin/ after extraction',
    DirectoryExists(InstallDir + PathDelim + 'bin'));
  Test('Install dir has lib/ after extraction',
    DirectoryExists(InstallDir + PathDelim + 'lib'));
  Test('Install dir has bin/fpc',
    FileExists(InstallDir + PathDelim + 'bin' + PathDelim + 'fpc'));
  Test('Install dir has lib/fpc/3.2.2/ppcx64',
    FileExists(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'ppcx64'));

  // Verify output messages
  Test('Output mentions base package',
    StdOut.Contains('base') or StdOut.Contains('Base'));
end;

procedure TestExtractPipeline_ExtractsRemainingPackages;
var
  SrcDir, TempDir, InstallDir: string;
  StdOut, StdErr: TStringOutput;
  Res: TFPCExtractResult;
  ProcRes: fpdev.utils.process.TProcessResult;
  BaseDir, UnitsDir: string;
begin
  SrcDir := MakeTempDir('pipeline_packages_src');
  TempDir := MakeTempDir('pipeline_packages_temp');
  InstallDir := MakeTempDir('pipeline_packages_install');

  BaseDir := SrcDir + PathDelim + 'base_content';
  ForceDirectories(BaseDir + PathDelim + 'bin');
  ForceDirectories(BaseDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2');
  CreateFile(BaseDir + PathDelim + 'bin' + PathDelim + 'fpc', '#!/bin/sh' + LineEnding + 'echo FPC 3.2.2');
  CreateFile(BaseDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'ppcx64', 'dummy');

  UnitsDir := SrcDir + PathDelim + 'units_content';
  ForceDirectories(UnitsDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim +
    '3.2.2' + PathDelim + 'units' + PathDelim + 'x86_64-linux' + PathDelim + 'fcl-base');
  CreateFile(UnitsDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim +
    '3.2.2' + PathDelim + 'units' + PathDelim + 'x86_64-linux' + PathDelim +
    'fcl-base' + PathDelim + 'custapp.ppu', 'dummy');

  ProcRes := TProcessExecutor.Execute('tar', [
    '-czf', SrcDir + PathDelim + 'base.x86_64-linux.tar.gz',
    '-C', BaseDir, 'bin', 'lib'], '');
  Test('Create base.tar.gz for package pipeline succeeds', ProcRes.Success);

  ProcRes := TProcessExecutor.Execute('tar', [
    '-czf', SrcDir + PathDelim + 'units-fcl-base.x86_64-linux.tar.gz',
    '-C', UnitsDir, 'lib'], '');
  Test('Create units package tar.gz succeeds', ProcRes.Success);

  ProcRes := TProcessExecutor.Execute('tar', [
    '-cf', SrcDir + PathDelim + 'binary.x86_64-linux.tar',
    '-C', SrcDir, 'base.x86_64-linux.tar.gz', 'units-fcl-base.x86_64-linux.tar.gz'], '');
  Test('Create binary.tar with extra package succeeds', ProcRes.Success);

  ForceDirectories(SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux');
  ProcRes := TProcessExecutor.Execute('mv', [
    SrcDir + PathDelim + 'binary.x86_64-linux.tar',
    SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux' + PathDelim + 'binary.x86_64-linux.tar'], '');
  Test('Move binary.tar with extra package succeeds', ProcRes.Success);

  ProcRes := TProcessExecutor.Execute('tar', [
    '-cf', SrcDir + PathDelim + 'fpc-3.2.2-with-packages.tar',
    '-C', SrcDir, 'fpc-3.2.2.x86_64-linux'], '');
  Test('Create outer tar with extra package succeeds', ProcRes.Success);

  StdOut := TStringOutput.Create;
  StdErr := TStringOutput.Create;
  Res := TFPCArchiveExtractor.ExtractLinuxFPCTarball(
    SrcDir + PathDelim + 'fpc-3.2.2-with-packages.tar',
    TempDir, InstallDir, StdOut, StdErr);

  Test('Full pipeline with extra package succeeds', Res.Success);
  Test('Extra package archive gets extracted',
    FileExists(InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim +
      '3.2.2' + PathDelim + 'units' + PathDelim + 'x86_64-linux' + PathDelim +
      'fcl-base' + PathDelim + 'custapp.ppu'));
end;

{ ===== Group 6: ExtractNestedFPCPackage gap - missing base archive ===== }

procedure TestExtractPipeline_MissingBaseArchive;
var
  SrcDir, TempDir, InstallDir: string;
  StdOut, StdErr: TStringOutput;
  Res: TFPCExtractResult;
  ProcRes: fpdev.utils.process.TProcessResult;
begin
  // Create a structure where binary.tar exists but contains NO base.*.tar.gz
  // This tests the gap where ExtractNestedFPCPackage would silently succeed
  SrcDir := MakeTempDir('pipeline_nobase_src');
  TempDir := MakeTempDir('pipeline_nobase_temp');
  InstallDir := MakeTempDir('pipeline_nobase_install');

  // Create a dummy file (not base.tar.gz)
  CreateFile(SrcDir + PathDelim + 'utils.x86_64-linux.tar.gz', 'dummy utils');

  // Create binary.x86_64-linux.tar containing only utils.tar.gz
  ProcRes := TProcessExecutor.Execute('tar', [
    '-cf', SrcDir + PathDelim + 'binary.x86_64-linux.tar',
    '-C', SrcDir, 'utils.x86_64-linux.tar.gz'], '');
  Test('Create binary.tar (no base) succeeds', ProcRes.Success);

  // Create outer directory structure
  ForceDirectories(SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux');
  ProcRes := TProcessExecutor.Execute('mv', [
    SrcDir + PathDelim + 'binary.x86_64-linux.tar',
    SrcDir + PathDelim + 'fpc-3.2.2.x86_64-linux' + PathDelim + 'binary.x86_64-linux.tar'], '');
  Test('Move binary.tar succeeds', ProcRes.Success);

  // Create outer tar
  ProcRes := TProcessExecutor.Execute('tar', [
    '-cf', SrcDir + PathDelim + 'fpc-3.2.2-nobase.tar',
    '-C', SrcDir, 'fpc-3.2.2.x86_64-linux'], '');
  Test('Create outer tar (no base) succeeds', ProcRes.Success);

  // Run extraction
  StdOut := TStringOutput.Create;
  StdErr := TStringOutput.Create;

  Res := TFPCArchiveExtractor.ExtractLinuxFPCTarball(
    SrcDir + PathDelim + 'fpc-3.2.2-nobase.tar',
    TempDir, InstallDir, StdOut, StdErr);

  // This should FAIL because base archive is missing
  // (Before fix: would succeed silently in ExtractNestedFPCPackage)
  Test('Missing base archive extraction fails', not Res.Success);
  Test('Missing base archive gives error message', Res.ErrorMsg <> '');
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Nested Package Extraction Tests ===');
  WriteLn;

  // Create temp root
  GTempRoot := CreateUniqueTempDir('fpdev_test_extract');
  Test('Temp root uses system temp root', PathUsesSystemTempRoot(GTempRoot));

  try
    // Group 1: FindBinaryArchive
    WriteLn('--- FindBinaryArchive ---');
    TestFindBinaryArchive_EmptyDir;
    TestFindBinaryArchive_NoBinaryFile;
    TestFindBinaryArchive_WithBinaryTar;
    TestFindBinaryArchive_WithBinaryTarAarch64;

    // Group 2: FindBaseArchive
    WriteLn('');
    WriteLn('--- FindBaseArchive ---');
    TestFindBaseArchive_EmptyDir;
    TestFindBaseArchive_NoBaseFile;
    TestFindBaseArchive_WithBaseTarGz;

    // Group 3: Bad input handling
    WriteLn('');
    WriteLn('--- Bad Input Handling ---');
    TestExtractLinuxFPCTarball_BadTarFile;

    // Group 4: Post-extraction validation
    WriteLn('');
    WriteLn('--- Post-extraction Validation ---');
    TestValidateInstall_EmptyDir;
    TestValidateInstall_WithBinAndLib;
    TestValidateInstall_OnlyBin;

    // Group 5: Real tarball extraction pipeline
    WriteLn('');
    WriteLn('--- Full Extraction Pipeline ---');
    TestExtractPipeline_CreateFakeFPCStructure;
    TestExtractPipeline_ExtractsRemainingPackages;

    // Group 6: Missing base archive gap
    WriteLn('');
    WriteLn('--- Missing Base Archive Gap ---');
    TestExtractPipeline_MissingBaseArchive;
  finally
    // Cleanup
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
