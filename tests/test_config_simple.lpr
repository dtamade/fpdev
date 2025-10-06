program test_config_simple;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.config;

var
  Config: TFPDevConfigManager;
begin
  WriteLn('Creating config manager...');
  Config := TFPDevConfigManager.Create('test_temp.json');
  try
    WriteLn('Config manager created successfully');
    
    WriteLn('Adding repository...');
    if Config.AddRepository('test', 'https://test.com/repo.git') then
      WriteLn('Repository added successfully')
    else
      WriteLn('Failed to add repository');
      
    WriteLn('Checking repository...');
    if Config.HasRepository('test') then
      WriteLn('Repository exists: ', Config.GetRepository('test'))
    else
      WriteLn('Repository not found');
      
  finally
    WriteLn('Freeing config manager...');
    Config.Free;
    WriteLn('Done');
  end;
end.
