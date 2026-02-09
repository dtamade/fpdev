program test_cross_install_flow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.cross.search;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

{ Test: Auto-detect flow for ARM target }

procedure TestAutoDetect_ARM_Binutils;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  Res: TCrossSearchResult;
begin
  Search := TCrossToolchainSearch.Create;
  try
    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Target.OS := 'linux';
    Res := Search.SearchBinutils(Target);
    if Res.Found then
    begin
      Check(Res.BinutilsPath <> '', 'AutoDetect ARM: path is non-empty');
      Check(Pos('arm', Res.BinutilsPrefix) > 0, 'AutoDetect ARM: prefix contains arm');
      WriteLn('  [info] Found: ', Res.BinutilsPath, ' prefix=', Res.BinutilsPrefix);
    end
    else
    begin
      WriteLn('  [info] ARM cross-tools not installed, skipping verification');
      Check(True, 'AutoDetect ARM: search completes without crash');
    end;
  finally
    Search.Free;
  end;
end;

procedure TestAutoDetect_ARM_Libraries;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  Libs: TStringArray;
begin
  Search := TCrossToolchainSearch.Create;
  try
    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Target.OS := 'linux';
    Libs := Search.SearchLibraries(Target);
    if Length(Libs) > 0 then
    begin
      Check(Libs[0] <> '', 'AutoDetect ARM libs: first path is non-empty');
      WriteLn('  [info] Found ', Length(Libs), ' library path(s)');
    end
    else
    begin
      WriteLn('  [info] ARM libraries not found on system');
      Check(True, 'AutoDetect ARM libs: search completes without crash');
    end;
  finally
    Search.Free;
  end;
end;

{ Test: Auto-detect flow for Win64 target }

procedure TestAutoDetect_Win64_Binutils;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  Res: TCrossSearchResult;
begin
  Search := TCrossToolchainSearch.Create;
  try
    Target := Default(TCrossTarget);
    Target.CPU := 'x86_64';
    Target.OS := 'win64';
    Res := Search.SearchBinutils(Target);
    if Res.Found then
    begin
      Check(Pos('mingw', Res.BinutilsPrefix) > 0, 'AutoDetect Win64: prefix contains mingw');
      WriteLn('  [info] Found: ', Res.BinutilsPath, ' prefix=', Res.BinutilsPrefix);
    end
    else
    begin
      WriteLn('  [info] Win64 cross-tools not installed');
      Check(True, 'AutoDetect Win64: search completes without crash');
    end;
  finally
    Search.Free;
  end;
end;

{ Test: Auto-detect with configured path override }

procedure TestAutoDetect_ConfiguredOverride;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  Res: TCrossSearchResult;
  TmpDir, ToolPath: string;
begin
  Search := TCrossToolchainSearch.Create;
  try
    TmpDir := GetTempDir(False) + 'fpdev_test_autoflow_' + IntToStr(GetProcessID);
    ForceDirectories(TmpDir);
    ToolPath := TmpDir + PathDelim + 'custom-prefix-as';
    with TFileStream.Create(ToolPath, fmCreate) do Free;

    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Target.OS := 'linux';
    Target.BinutilsPath := TmpDir;
    Target.BinutilsPrefix := 'custom-prefix-';
    Res := Search.SearchBinutils(Target);

    Check(Res.Found, 'ConfiguredOverride: finds configured path');
    Check(Res.Layer = 0, 'ConfiguredOverride: layer is 0 (configured)');
    Check(Res.BinutilsPath = TmpDir, 'ConfiguredOverride: path matches');

    DeleteFile(ToolPath);
    RemoveDir(TmpDir);
  finally
    Search.Free;
  end;
end;

{ Test: SearchBinutilsWithConfig uses fpc.cfg as fallback }

procedure TestAutoDetect_FpcCfgFallback;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  Res: TCrossSearchResult;
  TmpCfg, BinDir, ToolPath: string;
  SL: TStringList;
begin
  Search := TCrossToolchainSearch.Create;
  try
    BinDir := GetTempDir(False) + 'fpdev_test_cfgfall_' + IntToStr(GetProcessID);
    ForceDirectories(BinDir);
    ToolPath := BinDir + PathDelim + 'sparc-solaris-as';
    with TFileStream.Create(ToolPath, fmCreate) do Free;

    TmpCfg := GetTempDir(False) + 'fpdev_test_fallback_' + IntToStr(GetProcessID) + '.cfg';
    SL := TStringList.Create;
    try
      SL.Add('#IFDEF CPUSPARC');
      SL.Add('-FD' + BinDir);
      SL.Add('-XPsparc-solaris-');
      SL.Add('#ENDIF');
      SL.SaveToFile(TmpCfg);
    finally
      SL.Free;
    end;

    Target := Default(TCrossTarget);
    Target.CPU := 'sparc';
    Target.OS := 'solaris';
    Res := Search.SearchBinutilsWithConfig(Target, TmpCfg);

    Check(Res.Found, 'FpcCfgFallback: finds via config hints');
    Check(Res.Layer = 6, 'FpcCfgFallback: layer is 6 (config-hints)');
    Check(Res.BinutilsPath = BinDir, 'FpcCfgFallback: correct path from config');

    DeleteFile(ToolPath);
    RemoveDir(BinDir);
    DeleteFile(TmpCfg);
  finally
    Search.Free;
  end;
end;

{ Test: Integration - search fills both binutils and libraries }

procedure TestAutoDetect_FullIntegration;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  BinRes: TCrossSearchResult;
  Libs: TStringArray;
begin
  Search := TCrossToolchainSearch.Create;
  try
    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Target.OS := 'linux';

    BinRes := Search.SearchBinutils(Target);
    Libs := Search.SearchLibraries(Target);

    if BinRes.Found and (Length(Libs) > 0) then
      WriteLn('  [info] Full auto-detect: binutils=', BinRes.BinutilsPath,
        ' libs=', Libs[0])
    else if BinRes.Found then
      WriteLn('  [info] Binutils found but no libraries')
    else if Length(Libs) > 0 then
      WriteLn('  [info] Libraries found but no binutils')
    else
      WriteLn('  [info] Neither binutils nor libraries found');

    Check(True, 'FullIntegration: search completes without crash');
  finally
    Search.Free;
  end;
end;

{ Test: Diagnose output matches configure expectations }

procedure TestAutoDetect_DiagnoseMatchesConfigure;
var
  Search: TCrossToolchainSearch;
  Target: TCrossTarget;
  BinRes: TCrossSearchResult;
  DiagLines: TStringArray;
  I: Integer;
  DiagShowsBin: Boolean;
begin
  Search := TCrossToolchainSearch.Create;
  try
    Target := Default(TCrossTarget);
    Target.CPU := 'arm';
    Target.OS := 'linux';

    BinRes := Search.SearchBinutils(Target);
    DiagLines := Search.DiagnoseTarget(Target);

    DiagShowsBin := False;
    for I := 0 to High(DiagLines) do
    begin
      if BinRes.Found and (Pos('[OK] Binutils found', DiagLines[I]) > 0) then
        DiagShowsBin := True;
      if (not BinRes.Found) and (Pos('[X] Binutils not found', DiagLines[I]) > 0) then
        DiagShowsBin := True;
    end;
    Check(DiagShowsBin, 'DiagnoseMatches: diagnosis consistent with search result');
  finally
    Search.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Install Flow Tests ===');
  WriteLn;

  TestAutoDetect_ARM_Binutils;
  TestAutoDetect_ARM_Libraries;
  TestAutoDetect_Win64_Binutils;
  TestAutoDetect_ConfiguredOverride;
  TestAutoDetect_FpcCfgFallback;
  TestAutoDetect_FullIntegration;
  TestAutoDetect_DiagnoseMatchesConfigure;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
