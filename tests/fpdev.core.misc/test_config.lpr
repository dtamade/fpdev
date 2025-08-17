program test_config;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  Classes,
  fpdev.config.test;

begin
  try
    WriteLn('FPDev Configuration Management Test Suite');
    WriteLn('==========================================');
    WriteLn;
    
    RunConfigTests;
    
    WriteLn;
    WriteLn('Test suite completed.');
    
  except
    on E: Exception do
    begin
      WriteLn('Error running tests: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  {$IFDEF MSWINDOWS}
  WriteLn;
  WriteLn('Press Enter to continue...');
  ReadLn;
  {$ENDIF}
end.
