program test_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
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
  
  WriteLn('Press Enter to continue...');
  ReadLn;
end.
