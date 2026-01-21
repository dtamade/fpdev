program debug_update_repos;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.config.interfaces, fpdev.config.managers,
  fpdev.pkg.repository;

var
  Config: IConfigManager;
  RepoService: TPackageRepositoryService;
  RepoPath, RepoURL: string;
begin
  WriteLn('Debug UpdateRepositories');
  WriteLn('========================');

  // Setup - use same path calculation as the test
  RepoPath := ExpandFileName(ExtractFileDir(ExtractFileDir(ParamStr(0))) + PathDelim + 'examples' + PathDelim + 'sample-repo-invalid' + PathDelim + 'index.json');
  WriteLn('Repository path: ', RepoPath);
  WriteLn('File exists: ', FileExists(RepoPath));

  {$IFDEF MSWINDOWS}
  RepoURL := 'file:///' + StringReplace(RepoPath, '\', '/', [rfReplaceAll]);
  {$ELSE}
  RepoURL := 'file://' + RepoPath;
  {$ENDIF}
  WriteLn('Repository URL: ', RepoURL);

  // Create config
  Config := TConfigManager.Create('debug_config.json');
  if not Config.LoadConfig then
    Config.CreateDefaultConfig;

  Config.GetRepositoryManager.AddRepository('test-repo', RepoURL);
  Config.SaveConfig;

  // Create repository service
  RepoService := TPackageRepositoryService.Create(Config, 'debug_cache');
  try
    WriteLn('Calling UpdateRepositories...');
    if RepoService.UpdateRepositories(nil, nil) then
      WriteLn('SUCCESS: UpdateRepositories returned true')
    else
      WriteLn('FAILED: UpdateRepositories returned false');
  finally
    RepoService.Free;
  end;

  WriteLn('Done');
end.
