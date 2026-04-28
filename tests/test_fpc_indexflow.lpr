program test_fpc_indexflow;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fpdev.config,
  fpdev.fpc.types,
  fpdev.version.registry,
  fpdev.fpc.indexflow,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestBuildFPCIndexJSONCore;
var
  Releases: TFPCReleaseArray;
  Json: string;
  Stamp: TDateTime;
begin
  SetLength(Releases, 2);
  Releases[0] := Default(TFPCReleaseInfo);
  Releases[0].Version := '3.2.2';
  Releases[0].GitTag := 'release_3_2_2';
  Releases[0].Branch := 'fixes_3_2';
  Releases[0].Channel := 'stable';

  Releases[1] := Default(TFPCReleaseInfo);
  Releases[1].Version := 'main';
  Releases[1].GitTag := 'main';
  Releases[1].Branch := 'main';
  Releases[1].Channel := 'development';

  Stamp := EncodeDateTime(2026, 4, 12, 8, 30, 0, 0);
  Json := BuildFPCIndexJSONCore(Releases, Stamp);

  Check('index json contains updated_at field',
    Pos('"updated_at": "2026-04-12T08:30:00Z"', Json) > 0,
    Json);
  Check('index json contains stable release version',
    Pos('"version": "3.2.2"', Json) > 0,
    Json);
  Check('index json contains release tag',
    Pos('"tag": "release_3_2_2"', Json) > 0,
    Json);
  Check('index json contains development channel',
    Pos('"channel": "development"', Json) > 0,
    Json);
end;

procedure TestExecuteFPCUpdateIndexCore;
var
  TempRoot: string;
  ConfigPath: string;
  IndexPath: string;
  Cfg: TFPDevConfigManager;
  Settings: TFPDevSettings;
  Content: string;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_indexflow');
  ConfigPath := TempRoot + PathDelim + 'config.json';
  Cfg := TFPDevConfigManager.Create(ConfigPath);
  try
    Check('compat config manager creates default config',
      Cfg.CreateDefaultConfig,
      'failed to create default config');
    Settings := Cfg.GetSettings;
    Settings.InstallRoot := TempRoot;
    Check('compat config manager stores custom install root',
      Cfg.SetSettings(Settings),
      'failed to set install root');
    Check('compat config manager saves config',
      Cfg.SaveConfig,
      'failed to save config');
  finally
    Cfg.Free;
  end;

  IndexPath := ExecuteFPCUpdateIndexCore(ConfigPath);
  Content := ReadAllTextIfExists(IndexPath);

  Check('update index helper returns cache index path',
    IndexPath = TempRoot + PathDelim + 'cache' + PathDelim + 'fpc' + PathDelim + 'index.json',
    'got=' + IndexPath);
  Check('update index helper writes index file',
    FileExists(IndexPath),
    'missing ' + IndexPath);
  Check('update index helper writes items payload',
    Pos('"items": [', Content) > 0,
    Content);
  Check('update index helper writes known release tag',
    Pos('"tag": "release_3_2_2"', Content) > 0,
    Content);

  CleanupTempDir(TempRoot);
end;

begin
  WriteLn('=== FPC Indexflow Tests ===');

  TestBuildFPCIndexJSONCore;
  TestExecuteFPCUpdateIndexCore;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
