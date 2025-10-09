program wrapper_test;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config;

var
  Config: TFPDevConfigManager;
begin
  WriteLn('Test: Creating TFPDevConfigManager...');
  Config := TFPDevConfigManager.Create('test_temp.json');
  try
    WriteLn('TFPDevConfigManager created successfully');
    
    WriteLn('Adding repository...');
    if Config.AddRepository('test', 'https://example.com/test.git') then
      WriteLn('Repository added')
    else
      WriteLn('Failed to add repository');
    
    WriteLn('Test body completed');
  finally
    WriteLn('Freeing TFPDevConfigManager...');
    Config.Free;
    WriteLn('TFPDevConfigManager freed');
  end;
  
  WriteLn('Program exiting...');
end.
