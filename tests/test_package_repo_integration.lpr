program test_package_repo_integration;

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
  RepoPath, RepoURL: string;
  Settings: TFPDevSettings;
  PM: TPackageManager;
begin
  // 使用相对路径定位示例仓库索引
  RepoPath := ExpandFileName(ExtractFileDir(ExtractFileDir(ParamStr(0))) + DirectorySeparator + 'examples' + DirectorySeparator + 'sample-repo' + DirectorySeparator + 'index.json');
  AssertTrue(FileExists(RepoPath), 'Sample repo index should exist: ' + RepoPath);

  // 通过 file:// URL 暴露本地索引
  {$IFDEF MSWINDOWS}
  RepoURL := 'file:///' + StringReplace(RepoPath, '\\', '\', [rfReplaceAll]);
  RepoURL := StringReplace(RepoURL, '\', '/', [rfReplaceAll]);
  {$ELSE}
  RepoURL := 'file://' + RepoPath;
  {$ENDIF}

  // 初始化配置
  Cfg := TFPDevConfigManager.Create('tests_repo_config.json');
  try
    // 初始化新配置，使 InstallRoot 定位到测试程序旁 data 目录
    if not Cfg.LoadConfig then
      AssertTrue(Cfg.CreateDefaultConfig, 'Create default config');

    // Set InstallRoot to local test directory to avoid permission issues
    Settings := Cfg.GetSettings;
    Settings.InstallRoot := ExtractFileDir(ParamStr(0)) + DirectorySeparator + 'test_data';
    Cfg.SetSettings(Settings);

    // 添加仓库并保存
    AssertTrue(Cfg.AddRepository('local-sample', RepoURL), 'Add local sample repository');
    AssertTrue(Cfg.SaveConfig, 'Save config after adding repo');

    // 直接使用包管理器执行更新与列出
    PM := TPackageManager.Create(Cfg);
    try
      AssertTrue(PM.UpdateRepositories, 'UpdateRepositories should succeed');
      AssertTrue(PM.ListPackages(True), 'ListPackages --all should succeed');
    finally
      PM.Free;
    end;
  finally
    Cfg.Free;
  end;
end;

begin
  try
    WriteLn('Package Repo Integration Test');
    WriteLn('==============================');
    Main;
    WriteLn('✓ Integration test completed');
  except
    on E: Exception do
    begin
      WriteLn('✗ Exception: ', E.Message);
      Halt(1);
    end;
  end;
end.

