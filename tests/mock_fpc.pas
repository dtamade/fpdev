program mock_fpc;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes;

var
  i: Integer;
  OutputFile: string;
  CompileTarget: string;
  MockExe: TStringList;
begin
  // Mock FPC that returns version 3.2.2 when called with -iV
  if (ParamCount = 1) and (ParamStr(1) = '-iV') then
  begin
    WriteLn('3.2.2');
    Flush(Output); // Ensure output is flushed
    Halt(0); // Use Halt instead of ExitCode + Exit
  end;

  // For compilation requests, find output file and create a mock executable
  OutputFile := '';
  CompileTarget := '';

  i := 1;
  while i <= ParamCount do
  begin
    if (Pos('-o', ParamStr(i)) = 1) and (Length(ParamStr(i)) > 2) then
    begin
      // -ofile.exe format
      OutputFile := Copy(ParamStr(i), 3, MaxInt);
    end
    else if (ParamStr(i) = '-o') and (i < ParamCount) then
    begin
      // -o file.exe format
      Inc(i);
      OutputFile := ParamStr(i);
    end
    else if (Pos('.pas', LowerCase(ParamStr(i))) > 0) then
    begin
      CompileTarget := ParamStr(i);
    end;
    Inc(i);
  end;

  // If we have both output file and source, create a mock executable
  if (OutputFile <> '') and (CompileTarget <> '') and FileExists(CompileTarget) then
  begin
    // Create a simple batch/shell script that outputs "Hello, World!"
    MockExe := TStringList.Create;
    try
      {$IFDEF MSWINDOWS}
      MockExe.Add('@echo off');
      MockExe.Add('echo Hello, World!');
      // Save as batch file
      MockExe.SaveToFile(ChangeFileExt(OutputFile, '.bat'));
      // Also create the .exe file marker (empty file)
      MockExe.Clear;
      MockExe.SaveToFile(OutputFile);
      {$ELSE}
      MockExe.Add('#!/bin/sh');
      MockExe.Add('echo "Hello, World!"');
      MockExe.SaveToFile(OutputFile);
      // Make it executable
      FpChmod(OutputFile, &755);
      {$ENDIF}
      ExitCode := 0;
    finally
      MockExe.Free;
    end;
  end
  else
  begin
    WriteLn('Mock FPC compiler');
    ExitCode := 0;
  end;
end.
