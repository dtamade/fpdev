program test_executeprocess_vs_tprocess;

{$mode objfpc}{$H+}

uses
  SysUtils, Process;

var
  ExitCode: Integer;
  P: TProcess;
  Output: string;
begin
  WriteLn('=== ExecuteProcess vs TProcess Comparison ===');
  WriteLn;

  // Test 1: ExecuteProcess with simple command
  WriteLn('Test 1: ExecuteProcess with simple fpc command');
  try
    ExitCode := ExecuteProcess('fpc', ['-h']);
    WriteLn('  Exit code: ', ExitCode);
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
  WriteLn;

  // Test 2: TProcess with simple command
  WriteLn('Test 2: TProcess with simple fpc command');
  P := TProcess.Create(nil);
  try
    P.Executable := 'fpc';
    P.Parameters.Add('-h');
    P.Options := [poWaitOnExit];
    try
      P.Execute;
      WriteLn('  Exit code: ', P.ExitStatus);
    except
      on E: Exception do
        WriteLn('  Exception: ', E.Message);
    end;
  finally
    P.Free;
  end;
  WriteLn;

  // Test 3: TProcess with environment variables
  WriteLn('Test 3: TProcess with explicit environment');
  P := TProcess.Create(nil);
  try
    P.Executable := 'fpc';
    P.Parameters.Add('-h');
    P.Options := [poWaitOnExit];
    P.Environment.Add('PATH=' + GetEnvironmentVariable('PATH'));
    try
      P.Execute;
      WriteLn('  Exit code: ', P.ExitStatus);
    except
      on E: Exception do
        WriteLn('  Exception: ', E.Message);
    end;
  finally
    P.Free;
  end;
  WriteLn;

  // Test 4: Check if ExecuteProcess uses shell
  WriteLn('Test 4: ExecuteProcess behavior analysis');
  WriteLn('  GetEnvironmentVariable(''PATH''): ', GetEnvironmentVariable('PATH'));
  WriteLn('  GetEnvironmentVariable(''SHELL''): ', GetEnvironmentVariable('SHELL'));
  WriteLn;

  // Test 5: Try with full path
  WriteLn('Test 5: ExecuteProcess with full path');
  try
    ExitCode := ExecuteProcess('/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc', ['-h']);
    WriteLn('  Exit code: ', ExitCode);
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
  WriteLn;
end.
