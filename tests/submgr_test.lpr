program submgr_test;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.config.managers;

var
  ConfigMgr: IConfigManager;
  RepoMgr: IRepositoryManager;
begin
  WriteLn('Creating config manager...');
  ConfigMgr := TConfigManager.Create('test_temp.json');
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
  WriteLn('Cleared');
  
  WriteLn('Exiting...');
end.
