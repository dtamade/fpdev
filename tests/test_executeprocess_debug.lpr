program test_executeprocess_debug;

{$mode objfpc}{$H+}

uses
  SysUtils, Process;

var
  ExitCode: Integer;
  Output: string;
  P: TProcess;
begin
  WriteLn('=== ExecuteProcess Debug Test ===');
  WriteLn;

  // Test 1: Try ExecuteProcess with 'fpc'
  WriteLn('Test 1: ExecuteProcess with "fpc"');
  try
    ExitCode := ExecuteProcess('fpc', ['--version']);
    WriteLn('  Exit code: ', ExitCode);
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
  WriteLn;

  // Test 2: Try ExecuteProcess with full path
  WriteLn('Test 2: ExecuteProcess with full path');
  try
    ExitCode := ExecuteProcess('/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc', ['--version']);
    WriteLn('  Exit code: ', ExitCode);
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
  WriteLn;

  // Test 3: Try TProcess with 'fpc'
  WriteLn('Test 3: TProcess with "fpc"');
  P := TProcess.Create(nil);
  try
    P.Executable := 'fpc';
    P.Parameters.Add('--version');
    P.Options := [poWaitOnExit, poUsePipes];
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

  // Test 4: Check PATH environment variable
  WriteLn('Test 4: Check PATH environment variable');
  WriteLn('  PATH: ', GetEnvironmentVariable('PATH'));
  WriteLn;

  // Test 5: Check which command
  WriteLn('Test 5: Check which command');
  P := TProcess.Create(nil);
  try
    P.Executable := 'which';
    P.Parameters.Add('fpc');
    P.Options := [poWaitOnExit, poUsePipes];
    try
      P.Execute;
      SetLength(Output, P.Output.NumBytesAvailable);
      P.Output.Read(Output[1], Length(Output));
      WriteLn('  Result: ', Trim(Output));
    except
      on E: Exception do
        WriteLn('  Exception: ', E.Message);
    end;
  finally
    P.Free;
  end;
  WriteLn;
end.
