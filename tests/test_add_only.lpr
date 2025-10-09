program test_add_only;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config;

var
  Config: TFPDevConfigManager;
begin
  WriteLn('Creating...');
  Config := TFPDevConfigManager.Create('test_temp.json');
  try
    WriteLn('Calling AddRepository...');
    if Config.AddRepository('test', 'https://example.com/test.git') then
      WriteLn('PASS: Repository added')
    else
      WriteLn('FAIL: Failed to add repository');
    WriteLn('AddRepository returned');
  finally
    WriteLn('Freeing...');
    Config.Free;
    WriteLn('Freed');
  end;
  WriteLn('Exiting...');
end.
