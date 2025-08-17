program test_build_manager_strict_fail;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.manager;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

procedure WriteText(const APath, AText: string);
var
  F: TextFile;
begin
  AssignFile(F, APath);
  Rewrite(F);
  try
    WriteLn(F, AText);
  finally
    CloseFile(F);
  end;
end;

var
  LBM: TBuildManager;
  LVer, LBase, LDest, LBin, LStrictIni: string;
  LOk: Boolean;
begin
  LVer := 'main';
  LBase := 'tests_tmp' + PathDelim + 'strict_fail';
  LDest := LBase + '_sandbox';
  EnsureDir(LDest);
  EnsureDir('logs');

  // 准备沙箱（故意不满足严格清单）
  LBin := IncludeTrailingPathDelimiter(LDest) + 'fpc-' + LVer + PathDelim + 'bin';
  EnsureDir(LBin);
  WriteText(IncludeTrailingPathDelimiter(LBin) + 'dummy.txt', 'x'); // 无 fpc/ppc 前缀

  // 使用 demo 内置模板作为严格清单
  LStrictIni := 'plays' + PathDelim + 'fpdev.build.manager.demo' + PathDelim + 'build-manager.strict.ini';

  LBM := TBuildManager.Create('sources' + PathDelim + 'fpc', 2, True);
  try
    LBM.SetSandboxRoot(LDest);
    LBM.SetAllowInstall(True);
    LBM.SetLogVerbosity(1);
    LBM.SetStrictResults(True);
    LBM.SetStrictConfigPath(LStrictIni);

    LOk := LBM.TestResults(LVer);
    if not LOk then
      WriteLn('STRICT_FAIL OK')  // 期望失败
    else
      WriteLn('STRICT_FAIL UNEXPECTED_PASS');
  finally
    LBM.Free;
  end;
end.

