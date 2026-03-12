program test_simple;

{$mode objfpc}{$H+}

uses
  SysUtils, test_pause_control,
  fpdev.cmd.project;

begin
  try
    WriteLn('Testing project module...');
    fpdev.cmd.project.execute([]);
    WriteLn('Project module test completed.');
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.ClassName, ': ', E.Message);
    end;
  end;
  
  PauseIfRequested('Press Enter to continue...');
end.
