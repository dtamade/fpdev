program test_build_manager_strict_pass;

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
  LVer, LBase, LDest, LBin, LLib, LCfgDir, LStrictIni: string;
  LOk: Boolean;
begin
  LVer := 'main';
  LBase := 'tests_tmp' + PathDelim + 'strict_pass';
  LDest := LBase + '_sandbox';
  EnsureDir(LDest);
  EnsureDir('logs');

  // 准备沙箱（满足严格清单的最小条件）
  LBin := IncludeTrailingPathDelimiter(LDest) + 'fpc-' + LVer + PathDelim + 'bin';
  EnsureDir(LBin);
  // 放置符合前缀的可执行占位文件
  WriteText(IncludeTrailingPathDelimiter(LBin) + 'fpc', 'x');

  // lib 存在且有子目录（最小化）
  LLib := IncludeTrailingPathDelimiter(LDest) + 'fpc-' + LVer + PathDelim + 'lib' + PathDelim + 'fpc';
  EnsureDir(LLib);
  WriteText(IncludeTrailingPathDelimiter(LLib) + 'placeholder', 'x');

  // demo strict.ini requires a non-empty fpc.cfg candidate.
  LCfgDir := IncludeTrailingPathDelimiter(LDest) + 'fpc-' + LVer + PathDelim + 'etc';
  EnsureDir(LCfgDir);
  WriteText(IncludeTrailingPathDelimiter(LCfgDir) + 'fpc.cfg', '# test config');

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
    if LOk then
      WriteLn('STRICT_PASS OK')
    else
    begin
      WriteLn('STRICT_PASS FAIL');
      Halt(1);
    end;
  finally
    LBM.Free;
  end;
end.
