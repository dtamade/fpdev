program test_config_simple;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, fpdev.config, test_temp_paths;

var
  Config: TFPDevConfigManager;
  ConfigPath: string;
  TempRoot: string;
begin
  TempRoot := CreateUniqueTempDir('fpdev-test-config-simple');
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';

  WriteLn('Creating config manager...');
  Config := TFPDevConfigManager.Create(ConfigPath);
  try
    WriteLn('Config manager created successfully');
    if Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(Config.ConfigPath)) = 1 then
      WriteLn('Config path uses system temp root')
    else
      WriteLn('Config path is not under system temp root: ', Config.ConfigPath);
    
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
    CleanupTempDir(TempRoot);
    WriteLn('Done');
  end;
end.
