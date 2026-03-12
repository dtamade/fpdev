program test_config_settings;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson,
  fpdev.config.interfaces,
  fpdev.config.settings;

type
  TStubNotifier = class(TInterfacedObject, IConfigChangeNotifier)
  public
    Calls: Integer;
    procedure NotifyConfigChanged;
  end;

procedure TStubNotifier.NotifyConfigChanged;
begin
  Inc(Calls);
end;

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

procedure TestDefaultSettings;
var
  Mgr: TSettingsManager;
  Settings: TFPDevSettings;
begin
  Mgr := TSettingsManager.Create(nil);
  try
    Settings := Mgr.GetSettings;
    Check(Settings.AutoUpdate = False, 'settings manager defaults auto_update to false');
    Check(Settings.ParallelJobs = 4, 'settings manager defaults parallel jobs to 4');
    Check(Settings.KeepSources = True, 'settings manager defaults keep_sources to true');
    Check(Settings.Mirror = 'auto', 'settings manager defaults mirror to auto');
  finally
    Mgr.Free;
  end;
end;

procedure TestSetSettingsNotifies;
var
  Stub: TStubNotifier;
  Notifier: IConfigChangeNotifier;
  Mgr: TSettingsManager;
  Settings: TFPDevSettings;
begin
  Stub := TStubNotifier.Create;
  Notifier := Stub;
  Mgr := TSettingsManager.Create(Notifier);
  try
    Settings := Mgr.GetSettings;
    Settings.AutoUpdate := True;
    Settings.ParallelJobs := 8;
    Settings.InstallRoot := '/tmp/fpdev';
    Check(Mgr.SetSettings(Settings), 'settings manager accepts updates');
    Check(Stub.Calls = 1, 'settings manager notifies on update');
    Settings := Mgr.GetSettings;
    Check(Settings.AutoUpdate = True, 'settings manager persists auto_update');
    Check(Settings.ParallelJobs = 8, 'settings manager persists parallel jobs');
    Check(Settings.InstallRoot = '/tmp/fpdev', 'settings manager persists install root');
  finally
    Mgr.Free;
  end;
end;

procedure TestLoadAndSaveJSON;
var
  Mgr: TSettingsManager;
  JSON: TJSONObject;
  Saved: TJSONObject;
  Settings: TFPDevSettings;
begin
  Mgr := TSettingsManager.Create(nil);
  try
    JSON := TJSONObject.Create;
    try
      JSON.Add('auto_update', True);
      JSON.Add('parallel_jobs', 12);
      JSON.Add('keep_sources', False);
      JSON.Add('install_root', '/opt/fpdev');
      JSON.Add('default_repo', 'official_fpc');
      JSON.Add('mirror', 'gitee');
      JSON.Add('custom_repo_url', 'https://mirror.example.com/fpdev-repo.git');
      Mgr.LoadFromJSON(JSON);
    finally
      JSON.Free;
    end;

    Settings := Mgr.GetSettings;
    Check(Settings.AutoUpdate = True, 'settings manager loads auto_update');
    Check(Settings.ParallelJobs = 12, 'settings manager loads parallel jobs');
    Check(Settings.KeepSources = False, 'settings manager loads keep_sources');
    Check(Settings.DefaultRepo = 'official_fpc', 'settings manager loads default repo');
    Check(Settings.Mirror = 'gitee', 'settings manager loads mirror');
    Check(Settings.CustomRepoURL = 'https://mirror.example.com/fpdev-repo.git',
      'settings manager loads custom repo url');

    Mgr.SaveToJSON(Saved);
    try
      Check(Saved.Get('parallel_jobs', 0) = 12, 'settings manager saves parallel jobs');
      Check(Saved.Get('mirror', '') = 'gitee', 'settings manager saves mirror');
      Check(Saved.Get('custom_repo_url', '') = 'https://mirror.example.com/fpdev-repo.git',
        'settings manager saves custom repo url');
    finally
      Saved.Free;
    end;
  finally
    Mgr.Free;
  end;
end;

begin
  WriteLn('=== Config Settings Manager Tests ===');
  TestDefaultSettings;
  TestSetSettingsNotifies;
  TestLoadAndSaveJSON;
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
