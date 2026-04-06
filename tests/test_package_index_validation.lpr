program test_package_index_validation;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, test_temp_paths, fpdev.config, fpjson, jsonparser,
  fpdev.package.manager, fpdev.package.types;

procedure AssertTrue(const ACond: Boolean; const AMsg: string);
begin
  if ACond then
    WriteLn('✓ PASS: ', AMsg)
  else
  begin
    WriteLn('✗ FAIL: ', AMsg);
    Halt(2);
  end;
end;

procedure Main;
var
  Cfg: TFPDevConfigManager;
  PM: TPackageManager;
  RepoPath, RepoURL: string;
  Avail: TPackageArray;
  i: Integer;
  Names: TStringList;
  Settings: TFPDevSettings;
  TempRoot: string;
  ConfigPath: string;
begin
  RepoPath := ExpandFileName(ExtractFileDir(ExtractFileDir(ParamStr(0))) + DirectorySeparator + 'examples' + DirectorySeparator + 'sample-repo-invalid' + DirectorySeparator + 'index.json');
  AssertTrue(FileExists(RepoPath), 'Invalid sample repo index should exist: ' + RepoPath);

  {$IFDEF MSWINDOWS}
  RepoURL := 'file:///' + StringReplace(RepoPath, '\\', '\', [rfReplaceAll]);
  RepoURL := StringReplace(RepoURL, '\', '/', [rfReplaceAll]);
  {$ELSE}
  RepoURL := 'file://' + RepoPath;
  {$ENDIF}

  TempRoot := CreateUniqueTempDir('fpdev-package-index-validation');
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';

  Cfg := TFPDevConfigManager.Create(ConfigPath);
  try
    if not Cfg.LoadConfig then AssertTrue(Cfg.CreateDefaultConfig, 'Create default config');

    AssertTrue(PathUsesSystemTempRoot(Cfg.ConfigPath),
      'Config path should use system temp root');

    // Set InstallRoot to local temp directory to avoid permission issues
    Settings := Cfg.GetSettings;
    Settings.InstallRoot := IncludeTrailingPathDelimiter(TempRoot) + 'test_data_invalid';
    Cfg.SetSettings(Settings);

    AssertTrue(Cfg.AddRepository('invalid-sample', RepoURL), 'Add invalid repo');
    AssertTrue(Cfg.SaveConfig, 'Save config');

    PM := TPackageManager.Create(Cfg);
    try
      AssertTrue(PM.UpdateRepositories, 'UpdateRepositories should succeed');
      Avail := PM.GetAvailablePackageList;
      // 只应保留 valid1 的最高版本 1.1.0
      Names := TStringList.Create;
      try
        for i := 0 to High(Avail) do Names.Add(Avail[i].Name + ':' + Avail[i].Version);
        AssertTrue(Names.IndexOf('valid1:1.1.0')>=0, 'Should keep valid1:1.1.0');
        AssertTrue(Names.IndexOf('valid1:1.0.0')<0, 'Should remove lower version');
        AssertTrue(Names.IndexOf('noversion:')<0, 'Should filter invalid entries without version');
        AssertTrue(Names.IndexOf('emptyurl:1.0.0')<0, 'Should filter entries with empty url array');
        AssertTrue(Names.IndexOf('strurl-empty:1.0.0')<0, 'Should filter entries with empty url string');
      finally
        Names.Free;
      end;
    finally
      PM.Free;
    end;
  finally
    Cfg.Free;
    DeleteFile(ConfigPath);
    CleanupTempDir(TempRoot);
  end;
end;

begin
  try
    WriteLn('Package Index Validation Test');
    WriteLn('============================');
    Main;
    WriteLn('✓ Validation test completed');
  except
    on E: Exception do
    begin
      WriteLn('✗ Exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
