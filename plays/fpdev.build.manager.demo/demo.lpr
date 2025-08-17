program demo;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.build.manager;

procedure Run;
var
  LBM: TBuildManager;
  LRoot, LVer: string;
  LStrict, LVerbose, LNoInstall, LTestOnly: Boolean;
begin
  LRoot := 'sources' + PathDelim + 'fpc';
  LVer := 'main';
  // 解析命令行参数
  LStrict := FindCmdLineSwitch('strict', True);
  LVerbose := FindCmdLineSwitch('v', True) or FindCmdLineSwitch('verbose', True);
  LNoInstall := FindCmdLineSwitch('no-install', True) or (GetEnvironmentVariable('NO_INSTALL') = '1');
  LTestOnly := FindCmdLineSwitch('test-only', True) or (GetEnvironmentVariable('TEST_ONLY') = '1');
  LBM := TBuildManager.Create(LRoot, 2, True);
  try
    WriteLn('== BuildManager Demo ==');
    // 设置沙箱并允许安装（不会写系统目录；无 make 时自动跳过）
    LBM.SetSandboxRoot('sandbox_demo');
    LBM.SetAllowInstall(not LNoInstall);
    if LVerbose then LBM.SetLogVerbosity(1) else LBM.SetLogVerbosity(0);
    LBM.SetStrictResults(LStrict);
    if not LTestOnly then
    begin
      if LBM.BuildCompiler(LVer) then WriteLn('BuildCompiler OK') else WriteLn('BuildCompiler FAIL');
      if LBM.BuildRTL(LVer) then WriteLn('BuildRTL OK') else WriteLn('BuildRTL FAIL');
      if not LNoInstall then begin
        if LBM.Install(LVer) then WriteLn('Install OK') else WriteLn('Install FAIL');
      end else begin
        WriteLn('Install skipped (no-install)');
      end;
      if LBM.Configure(LVer) then WriteLn('Configure OK') else WriteLn('Configure FAIL');
    end
    else
      WriteLn('Test-only mode: skipping Build/Install/Configure');
    WriteLn('Log file: ', LBM.LogFileName);
    if LBM.TestResults(LVer) then
      WriteLn('TestResults OK')
    else
    begin
      WriteLn('TestResults FAIL');
      WriteLn('Tip: 可开启详细日志与严格校验：SetLogVerbosity(1) + SetStrictResults(True)');
    end;
  finally
    LBM.Free;
  end;
end;

begin
  Run;
end.

