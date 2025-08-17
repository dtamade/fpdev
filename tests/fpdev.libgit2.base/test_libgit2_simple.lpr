program test_libgit2_simple;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.git2;

var
  GitManager: TGit2Manager;

begin
  try
    WriteLn('libgit2 Simple Test');
    WriteLn('==================');
    WriteLn;

    // Check if DLL exists
    if FileExists('git2.dll') then
      WriteLn('✓ git2.dll found')
    else
      WriteLn('✗ git2.dll not found');

    // Test libgit2 initialization
    GitManager := TGit2Manager.Create;
    try
      if GitManager.Initialize then
      begin
        WriteLn('✓ libgit2 initialized successfully');
        WriteLn('Git functionality is ready!');
      end
      else
      begin
        WriteLn('✗ libgit2 initialization failed');
      end;
    finally
      GitManager.Free;
    end;

    WriteLn;
    WriteLn('Test completed.');

  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
