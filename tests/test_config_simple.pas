program test_config_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.config.managers;

var
  Config: IConfigManager;
  RepoMgr: IRepositoryManager;
  Repos: TStringArray;
  i: Integer;

begin
  WriteLn('=== Simple Config Manager Test ===');
  WriteLn;
  
  try
    // Create config manager with a test path
    WriteLn('Creating config manager...');
    Config := TConfigManager.Create('test_config.json');
    WriteLn('Config manager created successfully');
    WriteLn;
    
    // Get repository manager
    WriteLn('Getting repository manager...');
    RepoMgr := Config.GetRepositoryManager;
    WriteLn('Repository manager obtained');
    WriteLn;
    
    // Add repositories
    WriteLn('Adding repositories...');
    if RepoMgr.AddRepository('test_repo1', 'https://example.com/repo1.git') then
      WriteLn('  + test_repo1 added')
    else
      WriteLn('  ! Failed to add test_repo1');
      
    if RepoMgr.AddRepository('test_repo2', 'https://example.com/repo2.git') then
      WriteLn('  + test_repo2 added')
    else
      WriteLn('  ! Failed to add test_repo2');
    WriteLn;
    
    // List repositories
    WriteLn('Listing repositories...');
    Repos := RepoMgr.ListRepositories;
    WriteLn('Found ', Length(Repos), ' repositories:');
    for i := 0 to High(Repos) do
      WriteLn('  - ', Repos[i], ' = ', RepoMgr.GetRepository(Repos[i]));
    WriteLn;
    
    // Check if repository exists
    WriteLn('Checking repository existence...');
    if RepoMgr.HasRepository('test_repo1') then
      WriteLn('  test_repo1 exists')
    else
      WriteLn('  test_repo1 does not exist');
      
    if RepoMgr.HasRepository('nonexistent') then
      WriteLn('  nonexistent exists')
    else
      WriteLn('  nonexistent does not exist');
    WriteLn;
    
    // Save config
    WriteLn('Saving configuration...');
    if Config.SaveConfig then
      WriteLn('Configuration saved successfully')
    else
      WriteLn('Failed to save configuration');
    WriteLn;
    
    WriteLn('=== Test completed successfully ===');
    
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  // Clean up test file
  if FileExists('test_config.json') then
    DeleteFile('test_config.json');
end.
