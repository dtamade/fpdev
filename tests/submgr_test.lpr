program submgr_test;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.config.managers,
  test_temp_paths;

var
  ConfigMgr: IConfigManager;
  RepoMgr: IRepositoryManager;
  TempRoot: string;
  ConfigPath: string;
begin
  TempRoot := CreateUniqueTempDir('submgr_test');
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';

  WriteLn('Creating config manager...');
  ConfigMgr := TConfigManager.Create(ConfigPath);
  WriteLn('Created');

  WriteLn('Getting repository manager...');
  RepoMgr := ConfigMgr.GetRepositoryManager;
  WriteLn('Got repository manager');

  WriteLn('Adding repository...');
  RepoMgr.AddRepository('test', 'https://example.com/test.git');
  WriteLn('Added');

  WriteLn('Checking if repository exists...');
  if RepoMgr.HasRepository('test') then
    WriteLn('Repository found')
  else
    WriteLn('Repository not found');

  WriteLn('Clearing references...');
  RepoMgr := nil;
  ConfigMgr := nil;
  CleanupTempDir(TempRoot);
  WriteLn('Cleared');

  WriteLn('Exiting...');
end.
