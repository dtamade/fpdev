program test_build_manager_strict_fail;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.manager, fpdev.build.strict;

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

function ProjectRoot: string;
var
  LEnvRoot: string;
begin
  LEnvRoot := Trim(GetEnvironmentVariable('FPDEV_TEST_PROJECT_ROOT'));
  if LEnvRoot <> '' then
    Exit(ExpandFileName(LEnvRoot));

  Result := GetCurrentDir;
end;

function DemoStrictIniPath: string;
begin
  Result := IncludeTrailingPathDelimiter(ProjectRoot) +
    'plays' + PathDelim + 'fpdev.build.manager.demo' + PathDelim +
    'build-manager.strict.ini';
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

  // 使用 demo 内置模板作为严格清单；顶层 runner 会在隔离 workspace 中执行，
  // 因此这里通过 FPDEV_TEST_PROJECT_ROOT 固定到真实项目根。
  LStrictIni := DemoStrictIniPath;

  if BuildManagerResolveStrictConfigPathCore(LStrictIni, '') = LStrictIni then
    WriteLn('STRICT_PATH OK')
  else if not FileExists(LStrictIni) then
  begin
    WriteLn('STRICT_PATH MISSING: ' + LStrictIni);
    Halt(1);
  end
  else
  begin
    WriteLn('STRICT_PATH FAIL');
    Halt(1);
  end;

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
    begin
      WriteLn('STRICT_FAIL UNEXPECTED_PASS');
      Halt(1);
    end;
  finally
    LBM.Free;
  end;
end.
