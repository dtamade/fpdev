program test_package_index_validation;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpdev.config, fpjson, jsonparser, fpdev.cmd.package;

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
begin
  RepoPath := ExpandFileName(ExtractFileDir(ParamStr(0)) + DirectorySeparator + '..' + DirectorySeparator + 'examples' + DirectorySeparator + 'sample-repo-invalid' + DirectorySeparator + 'index.json');
  AssertTrue(FileExists(RepoPath), 'Invalid sample repo index should exist: ' + RepoPath);

  {$IFDEF MSWINDOWS}
  RepoURL := 'file:///' + StringReplace(RepoPath, '\\', '\', [rfReplaceAll]);
  RepoURL := StringReplace(RepoURL, '\', '/', [rfReplaceAll]);
  {$ELSE}
  RepoURL := 'file://' + RepoPath;
  {$ENDIF}

  Cfg := TFPDevConfigManager.Create('tests_repo_config_invalid.json');
  try
    if not Cfg.LoadConfig then AssertTrue(Cfg.CreateDefaultConfig, 'Create default config');
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

