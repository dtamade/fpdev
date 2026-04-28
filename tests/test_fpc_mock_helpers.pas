unit test_fpc_mock_helpers;

{$mode objfpc}{$H+}

interface

procedure CompileMockFPCBinary(const ATargetPath: string);
procedure CompileVersionMismatchMockFPCBinary(const ATargetPath: string);

implementation

uses
  SysUtils, Classes, Process,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  test_temp_paths;

function ResolveExecutableOnPath(const AExecutable: string): string;
var
  SearchPath: string;
  Entry: string;
  SepPos: Integer;
  Candidate: string;
begin
  if FileExists(AExecutable) then
    Exit(ExpandFileName(AExecutable));

  SearchPath := GetEnvironmentVariable('PATH');
  while SearchPath <> '' do
  begin
    SepPos := Pos(PathSeparator, SearchPath);
    if SepPos > 0 then
    begin
      Entry := Copy(SearchPath, 1, SepPos - 1);
      Delete(SearchPath, 1, SepPos);
    end
    else
    begin
      Entry := SearchPath;
      SearchPath := '';
    end;

    if Entry = '' then
      Continue;

    Candidate := IncludeTrailingPathDelimiter(Entry) + AExecutable;
    if FileExists(Candidate) then
      Exit(Candidate);
    {$IFDEF MSWINDOWS}
    if FileExists(Candidate + '.exe') then
      Exit(Candidate + '.exe');
    {$ENDIF}
  end;

  Result := '';
end;

procedure WriteMockCompilerScript(const ATargetPath, AVersion: string);
var
  Script: TStringList;
begin
  ForceDirectories(ExtractFileDir(ATargetPath));
  Script := TStringList.Create;
  try
    Script.Add('#!/bin/sh');
    Script.Add('if [ "$1" = "-iV" ]; then');
    Script.Add('  echo "' + AVersion + '"');
    Script.Add('  exit 0');
    Script.Add('fi');
    Script.Add('');
    Script.Add('OUTPUT_FILE=""');
    Script.Add('COMPILE_TARGET=""');
    Script.Add('while [ "$#" -gt 0 ]; do');
    Script.Add('  case "$1" in');
    Script.Add('    -o*) OUTPUT_FILE="${1#-o}" ;;');
    Script.Add('    -o) shift; OUTPUT_FILE="$1" ;;');
    Script.Add('    *.pas) COMPILE_TARGET="$1" ;;');
    Script.Add('  esac');
    Script.Add('  shift');
    Script.Add('done');
    Script.Add('');
    Script.Add('if [ -n "$OUTPUT_FILE" ] && [ -n "$COMPILE_TARGET" ] && [ -f "$COMPILE_TARGET" ]; then');
    Script.Add('  mkdir -p "$(dirname "$OUTPUT_FILE")"');
    Script.Add('  cat > "$OUTPUT_FILE" <<''EOF''');
    Script.Add('#!/bin/sh');
    Script.Add('echo "Hello, World!"');
    Script.Add('EOF');
    Script.Add('  chmod +x "$OUTPUT_FILE"');
    Script.Add('  exit 0');
    Script.Add('fi');
    Script.Add('');
    Script.Add('echo "Mock FPC compiler"');
    Script.Add('exit 0');
    Script.SaveToFile(ATargetPath);
    FpChmod(ATargetPath, &755);
  finally
    Script.Free;
  end;
end;

procedure CompileMockFPCBinary(const ATargetPath: string);
var
  MockFPCSource: string;
  CompilerPath: string;
  CompileProcess: TProcess;
begin
  MockFPCSource := ResolveTestAssetPath('tests' + PathDelim + 'mock_fpc.pas');
  ForceDirectories(ExtractFileDir(ATargetPath));
  {$IFDEF UNIX}
  if MockFPCSource <> '' then;
  WriteMockCompilerScript(ATargetPath, '3.2.2');
  Exit;
  {$ENDIF}
  CompilerPath := ResolveExecutableOnPath('fpc');
  if CompilerPath = '' then
    raise Exception.Create('Failed to locate fpc executable for mock compiler build');

  CompileProcess := TProcess.Create(nil);
  try
    CompileProcess.Executable := CompilerPath;
    CompileProcess.Parameters.Add('-o' + ATargetPath);
    CompileProcess.Parameters.Add(MockFPCSource);
    CompileProcess.Options := CompileProcess.Options + [poWaitOnExit];
    CompileProcess.Execute;

    if CompileProcess.ExitStatus <> 0 then
      raise Exception.Create('Failed to compile mock FPC executable');
  finally
    CompileProcess.Free;
  end;
end;

procedure CompileVersionMismatchMockFPCBinary(const ATargetPath: string);
var
  TempRoot: string;
  MockSourcePath: string;
  CompilerPath: string;
  MockSource: TStringList;
  CompileProcess: TProcess;
begin
  TempRoot := CreateUniqueTempDir('test_mock_fpc_version_mismatch');
  ForceDirectories(ExtractFileDir(ATargetPath));
  {$IFDEF UNIX}
  WriteMockCompilerScript(ATargetPath, '0.0.0-bad');
  Exit;
  {$ENDIF}
  CompilerPath := ResolveExecutableOnPath('fpc');
  if CompilerPath = '' then
    raise Exception.Create('Failed to locate fpc executable for version mismatch mock build');
  try
    MockSourcePath := TempRoot + PathDelim + 'mock_fpc_version_mismatch.pas';
    MockSource := TStringList.Create;
    try
      MockSource.Add('program mock_fpc_version_mismatch;');
      MockSource.Add('');
      MockSource.Add('{$mode objfpc}{$H+}');
      MockSource.Add('');
      MockSource.Add('uses');
      MockSource.Add('  SysUtils, Classes');
      MockSource.Add('  {$IFDEF UNIX}');
      MockSource.Add('  , BaseUnix');
      MockSource.Add('  {$ENDIF};');
      MockSource.Add('');
      MockSource.Add('var');
      MockSource.Add('  i: Integer;');
      MockSource.Add('  OutputFile: string;');
      MockSource.Add('  CompileTarget: string;');
      MockSource.Add('  MockExe: TStringList;');
      MockSource.Add('begin');
      MockSource.Add('  if (ParamCount = 1) and (ParamStr(1) = ''-iV'') then');
      MockSource.Add('  begin');
      MockSource.Add('    WriteLn(''0.0.0-bad'');');
      MockSource.Add('    Flush(Output);');
      MockSource.Add('    Halt(0);');
      MockSource.Add('  end;');
      MockSource.Add('');
      MockSource.Add('  OutputFile := '''';');
      MockSource.Add('  CompileTarget := '''';');
      MockSource.Add('');
      MockSource.Add('  i := 1;');
      MockSource.Add('  while i <= ParamCount do');
      MockSource.Add('  begin');
      MockSource.Add('    if (Pos(''-o'', ParamStr(i)) = 1) and (Length(ParamStr(i)) > 2) then');
      MockSource.Add('      OutputFile := Copy(ParamStr(i), 3, MaxInt)');
      MockSource.Add('    else if (ParamStr(i) = ''-o'') and (i < ParamCount) then');
      MockSource.Add('    begin');
      MockSource.Add('      Inc(i);');
      MockSource.Add('      OutputFile := ParamStr(i);');
      MockSource.Add('    end');
      MockSource.Add('    else if (Pos(''.pas'', LowerCase(ParamStr(i))) > 0) then');
      MockSource.Add('      CompileTarget := ParamStr(i);');
      MockSource.Add('    Inc(i);');
      MockSource.Add('  end;');
      MockSource.Add('');
      MockSource.Add('  if (OutputFile <> '''') and (CompileTarget <> '''') and FileExists(CompileTarget) then');
      MockSource.Add('  begin');
      MockSource.Add('    MockExe := TStringList.Create;');
      MockSource.Add('    try');
      MockSource.Add('      {$IFDEF MSWINDOWS}');
      MockSource.Add('      MockExe.Add(''@echo off'');');
      MockSource.Add('      MockExe.Add(''echo Hello, World!'');');
      MockSource.Add('      MockExe.SaveToFile(ChangeFileExt(OutputFile, ''.bat''));');
      MockSource.Add('      MockExe.Clear;');
      MockSource.Add('      MockExe.SaveToFile(OutputFile);');
      MockSource.Add('      {$ELSE}');
      MockSource.Add('      MockExe.Add(''#!/bin/sh'');');
      MockSource.Add('      MockExe.Add(''echo "Hello, World!"'');');
      MockSource.Add('      MockExe.SaveToFile(OutputFile);');
      MockSource.Add('      FpChmod(OutputFile, &755);');
      MockSource.Add('      {$ENDIF}');
      MockSource.Add('      ExitCode := 0;');
      MockSource.Add('    finally');
      MockSource.Add('      MockExe.Free;');
      MockSource.Add('    end;');
      MockSource.Add('  end');
      MockSource.Add('  else');
      MockSource.Add('  begin');
      MockSource.Add('    WriteLn(''Mock FPC compiler'');');
      MockSource.Add('    ExitCode := 0;');
      MockSource.Add('  end;');
      MockSource.Add('end.');
      MockSource.SaveToFile(MockSourcePath);
    finally
      MockSource.Free;
    end;

    CompileProcess := TProcess.Create(nil);
    try
      CompileProcess.Executable := CompilerPath;
      CompileProcess.Parameters.Add('-o' + ATargetPath);
      CompileProcess.Parameters.Add(MockSourcePath);
      CompileProcess.Options := CompileProcess.Options + [poWaitOnExit];
      CompileProcess.Execute;

      if CompileProcess.ExitStatus <> 0 then
        raise Exception.Create('Failed to compile version mismatch mock FPC executable');
    finally
      CompileProcess.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

end.
