program wrapper_test;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config,
  test_temp_paths;

var
  Config: TFPDevConfigManager;
  TempRoot: string;
  ConfigPath: string;
begin
  TempRoot := CreateUniqueTempDir('wrapper_test');
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';

  WriteLn('Test: Creating TFPDevConfigManager...');
  Config := TFPDevConfigManager.Create(ConfigPath);
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
    CleanupTempDir(TempRoot);
    WriteLn('TFPDevConfigManager freed');
  end;

  WriteLn('Program exiting...');
end.
