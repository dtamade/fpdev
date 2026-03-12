program test_config_core;

{$mode objfpc}{$H+}

uses
  SysUtils,
  test_temp_paths,
  fpdev.config.interfaces,
  fpdev.config.core;

var
  Passed: Integer = 0;
  Failed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(Failed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure TestDefaultConfigPathOverride;
var
  TempRoot: string;
  OverridePath: string;
  Config: IConfigManager;
begin
  TempRoot := CreateUniqueTempDir('config_core_override');
  OverridePath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';
  try
    SetDefaultConfigPathOverride(OverridePath);
    Check(GetDefaultConfigPathOverride = OverridePath, 'core remembers default config path override');
    Config := TConfigManager.Create('');
    Check(ExpandFileName(Config.GetConfigPath) = ExpandFileName(OverridePath),
      'TConfigManager respects default config path override');
  finally
    ClearDefaultConfigPathOverride;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestCreateDefaultConfigSeedsDefaults;
var
  TempRoot: string;
  ConfigPath: string;
  Config: IConfigManager;
  Settings: TFPDevSettings;
  RepoMgr: IRepositoryManager;
begin
  TempRoot := CreateUniqueTempDir('config_core_default');
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';
  try
    Config := TConfigManager.Create(ConfigPath);
    Check(Config.CreateDefaultConfig, 'core creates default config');
    Check(FileExists(ConfigPath), 'core writes config file');

    RepoMgr := Config.GetRepositoryManager;
    Check(RepoMgr.HasRepository('official_fpc'), 'core seeds official_fpc repository');
    Check(RepoMgr.HasRepository('official_lazarus'), 'core seeds official_lazarus repository');

    Settings := Config.GetSettingsManager.GetSettings;
    Check(Settings.InstallRoot <> '', 'core seeds install root');
    Check(Pos(ExpandFileName(TempRoot), ExpandFileName(Settings.InstallRoot)) = 1,
      'core seeds install root under config directory');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestNotifyConfigChangedMarksModified;
var
  TempRoot: string;
  ConfigPath: string;
  Config: IConfigManager;
begin
  TempRoot := CreateUniqueTempDir('config_core_modified');
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';
  try
    Config := TConfigManager.Create(ConfigPath);
    Check(Config.CreateDefaultConfig, 'core creates default config before modified check');
    Check(not Config.IsModified, 'core starts unmodified after default config save');
    Check(Config.GetRepositoryManager.AddRepository('custom', 'https://example.com/custom.git'),
      'sub-manager mutation succeeds');
    Check(Config.IsModified, 'sub-manager mutation marks config modified');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  WriteLn('=== Config Core Tests ===');
  TestDefaultConfigPathOverride;
  TestCreateDefaultConfigSeedsDefaults;
  TestNotifyConfigChangedMarksModified;
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
