program test_build_manager;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.manager;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

procedure WriteDummyFile(const APath: string);
var
  F: TextFile;
begin
  AssignFile(F, APath);
  Rewrite(F);
  try
    WriteLn(F, 'dummy');
  finally
    CloseFile(F);
  end;
end;

var
  LBM: TBuildManager;
  LVer, LTemp, LSrcRoot, LDest, LBin: string;
  LOk: Boolean;
begin
  LVer := 'main';
  LTemp := 'tests_tmp' + PathDelim + 'bm';
  EnsureDir(LTemp);
  EnsureDir('logs');

  // CASE 1: 源码树回退路径（未允许安装）
  LSrcRoot := IncludeTrailingPathDelimiter(LTemp) + 'sources' + PathDelim + 'fpc';
  EnsureDir(LSrcRoot + PathDelim + 'fpc-' + LVer + PathDelim + 'compiler');
  EnsureDir(LSrcRoot + PathDelim + 'fpc-' + LVer + PathDelim + 'rtl');

  LBM := TBuildManager.Create(LSrcRoot, 2, True);
  try
    LBM.SetLogVerbosity(1);
    LBM.SetStrictResults(False);

    LOk := LBM.TestResults(LVer);
    if LOk then WriteLn('CASE1 OK') else WriteLn('CASE1 FAIL');

    // CASE 2: 允许安装 + 沙箱存在最小 bin
    LBM.SetAllowInstall(True);
    LDest := 'tests_tmp' + PathDelim + 'sandbox_demo';
    LBM.SetSandboxRoot(LDest);
    LBin := IncludeTrailingPathDelimiter(LDest) + 'fpc-' + LVer + PathDelim + 'bin';
    EnsureDir(LBin);
    WriteDummyFile(IncludeTrailingPathDelimiter(LBin) + 'dummy.txt');

    LOk := LBM.TestResults(LVer);
    if LOk then WriteLn('CASE2 OK') else WriteLn('CASE2 FAIL');
  finally
    LBM.Free;
  end;
end.

