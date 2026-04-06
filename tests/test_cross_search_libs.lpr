program test_cross_search_libs;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, test_temp_paths,
  fpdev.config.interfaces,
  fpdev.cross.search;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string); forward;

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

function MakeTarget(const ACPU, AOS: string): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := True;
  Result.CPU := ACPU;
  Result.OS := AOS;
end;

{ === Tests: SearchLibraries basic === }

procedure TestSearchLibs_ConfiguredPathFirst;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
  TmpDir: string;
  NestedDir: string;
begin
  S := TCrossToolchainSearch.Create;
  try
    // Create a temp directory to use as configured path
    TmpDir := CreateUniqueTempDir('fpdev_test_libs');
    Check(PathUsesSystemTempRoot(TmpDir), 'ConfiguredFirst temp dir lives under system temp');
    NestedDir := IncludeTrailingPathDelimiter(TmpDir) + 'nested';
    ForceDirectories(NestedDir);

    T := MakeTarget('arm', 'linux');
    T.LibrariesPath := TmpDir;
    Libs := S.SearchLibraries(T);
    Check(Length(Libs) >= 1, 'ConfiguredFirst: at least 1 result');
    Check(Libs[0] = TmpDir, 'ConfiguredFirst: configured path is first');

    CleanupTempDir(TmpDir);
    Check(not DirectoryExists(TmpDir), 'ConfiguredFirst: temp dir cleanup removes nested children');
  finally
    S.Free;
  end;
end;

procedure TestSearchLibs_NoConfigured;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('zzz_fake', 'zzz_fake');
    Libs := S.SearchLibraries(T);
    // On any system, fake target won't have existing dirs
    Check(True, 'NoConfigured: does not crash');
  finally
    S.Free;
  end;
end;

procedure TestSearchLibs_Deduplication;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
  TmpDir: string;
  I, J: Integer;
  HasDup: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    // Create a temp dir that could match multiple paths
    TmpDir := CreateUniqueTempDir('fpdev_test_dedup');
    Check(PathUsesSystemTempRoot(TmpDir), 'Dedup temp dir lives under system temp');

    T := MakeTarget('arm', 'linux');
    T.LibrariesPath := TmpDir;
    Libs := S.SearchLibraries(T);

    // Check no duplicates
    HasDup := False;
    for I := 0 to High(Libs) do
      for J := I + 1 to High(Libs) do
        if Libs[I] = Libs[J] then
          HasDup := True;
    Check(not HasDup, 'Dedup: no duplicate paths');

    CleanupTempDir(TmpDir);
  finally
    S.Free;
  end;
end;

{ === Tests: SearchLibraries for specific targets === }

procedure TestSearchLibs_ARM_Linux;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    Libs := S.SearchLibraries(T);
    // Result depends on system, just ensure no crash
    Check(True, 'ARM Linux: search completes');
  finally
    S.Free;
  end;
end;

procedure TestSearchLibs_Win64;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('x86_64', 'win64');
    Libs := S.SearchLibraries(T);
    Check(True, 'Win64: search completes');
  finally
    S.Free;
  end;
end;

procedure TestSearchLibs_AArch64;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('aarch64', 'linux');
    Libs := S.SearchLibraries(T);
    Check(True, 'AArch64: search completes');
  finally
    S.Free;
  end;
end;

procedure TestSearchLibs_Android;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'android');
    Libs := S.SearchLibraries(T);
    Check(True, 'Android: search completes');
  finally
    S.Free;
  end;
end;

procedure TestSearchLibs_Mipsel;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('mipsel', 'linux');
    Libs := S.SearchLibraries(T);
    Check(True, 'Mipsel: search completes');
  finally
    S.Free;
  end;
end;

{ === Tests: DiagnoseTarget === }

procedure TestDiagnose_Basic;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Lines: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('x86_64', 'win64');
    Lines := S.DiagnoseTarget(T);
    Check(Length(Lines) > 0, 'Diagnose basic: non-empty result');
    Check(Pos('Target: x86_64-win64', Lines[0]) > 0, 'Diagnose basic: target line');
  finally
    S.Free;
  end;
end;

procedure TestDiagnose_ContainsBinutilsStatus;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Lines: TStringArray;
  I: Integer;
  HasBinStatus: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    Lines := S.DiagnoseTarget(T);
    HasBinStatus := False;
    for I := 0 to High(Lines) do
      if (Pos('[OK] Binutils', Lines[I]) > 0) or (Pos('[X] Binutils', Lines[I]) > 0) then
        HasBinStatus := True;
    Check(HasBinStatus, 'Diagnose: has binutils status line');
  finally
    S.Free;
  end;
end;

procedure TestDiagnose_ContainsLibsStatus;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Lines: TStringArray;
  I: Integer;
  HasLibStatus: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    Lines := S.DiagnoseTarget(T);
    HasLibStatus := False;
    for I := 0 to High(Lines) do
      if (Pos('Libraries', Lines[I]) > 0) then
        HasLibStatus := True;
    Check(HasLibStatus, 'Diagnose: has libraries status line');
  finally
    S.Free;
  end;
end;

procedure TestDiagnose_ContainsSearchLog;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Lines: TStringArray;
  I: Integer;
  HasSearchLog: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    Lines := S.DiagnoseTarget(T);
    HasSearchLog := False;
    for I := 0 to High(Lines) do
      if Pos('Search log', Lines[I]) > 0 then
        HasSearchLog := True;
    Check(HasSearchLog, 'Diagnose: has search log section');
  finally
    S.Free;
  end;
end;

procedure TestDiagnose_UnknownTarget;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Lines: TStringArray;
  I: Integer;
  HasNotFound: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('zzz_unknown', 'zzz_unknown');
    Lines := S.DiagnoseTarget(T);
    HasNotFound := False;
    for I := 0 to High(Lines) do
      if Pos('[X] Binutils not found', Lines[I]) > 0 then
        HasNotFound := True;
    Check(HasNotFound, 'Diagnose unknown: reports binutils not found');
  finally
    S.Free;
  end;
end;

procedure TestDiagnose_FoundTarget;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Lines: TStringArray;
  TmpDir, ToolPath: string;
  I: Integer;
  HasFound: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    // Create a fake toolchain
    TmpDir := CreateUniqueTempDir('fpdev_test_diag');
    Check(PathUsesSystemTempRoot(TmpDir), 'Diagnose temp dir lives under system temp');
    ToolPath := TmpDir + PathDelim + 'test-diag-as';
    with TFileStream.Create(ToolPath, fmCreate) do Free;

    T := Default(TCrossTarget);
    T.CPU := 'arm';
    T.OS := 'linux';
    T.BinutilsPath := TmpDir;
    T.BinutilsPrefix := 'test-diag-';
    Lines := S.DiagnoseTarget(T);
    HasFound := False;
    for I := 0 to High(Lines) do
      if Pos('[OK] Binutils found', Lines[I]) > 0 then
        HasFound := True;
    Check(HasFound, 'Diagnose found: reports binutils found');

    DeleteFile(ToolPath);
    CleanupTempDir(TmpDir);
  finally
    S.Free;
  end;
end;

{ === Tests: Multiple lib dirs === }

procedure TestSearchLibs_MultipleDirs;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
  TmpDir1, TmpDir2: string;
begin
  S := TCrossToolchainSearch.Create;
  try
    TmpDir1 := CreateUniqueTempDir('fpdev_test_multi1');
    TmpDir2 := CreateUniqueTempDir('fpdev_test_multi2');
    Check(PathUsesSystemTempRoot(TmpDir1), 'MultipleDirs temp dir 1 lives under system temp');
    Check(PathUsesSystemTempRoot(TmpDir2), 'MultipleDirs temp dir 2 lives under system temp');

    // Create a target with configured path, and create another dir that could match
    // a multiarch path (simulated by creating the dir)
    T := MakeTarget('arm', 'linux');
    T.LibrariesPath := TmpDir1;
    Libs := S.SearchLibraries(T);
    // Should have at least the configured path
    Check(Length(Libs) >= 1, 'MultipleDirs: at least 1 path');
    Check(Libs[0] = TmpDir1, 'MultipleDirs: configured path is first');

    CleanupTempDir(TmpDir1);
    CleanupTempDir(TmpDir2);
  finally
    S.Free;
  end;
end;

{ === Tests: System-dependent library discovery === }

procedure TestSearchLibs_RealSystem;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
  I: Integer;
begin
  S := TCrossToolchainSearch.Create;
  try
    // On a Debian/Ubuntu system with cross packages installed,
    // this might find /usr/arm-linux-gnueabihf/lib etc.
    T := MakeTarget('arm', 'linux');
    Libs := S.SearchLibraries(T);
    if Length(Libs) > 0 then
    begin
      WriteLn('  [info] System has ', Length(Libs), ' ARM lib path(s):');
      for I := 0 to High(Libs) do
        WriteLn('    ', Libs[I]);
    end;
    Check(True, 'RealSystem: completes without error');
  finally
    S.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Library Search Tests ===');
  WriteLn;

  // Basic library search
  TestSearchLibs_ConfiguredPathFirst;
  TestSearchLibs_NoConfigured;
  TestSearchLibs_Deduplication;

  // Target-specific
  TestSearchLibs_ARM_Linux;
  TestSearchLibs_Win64;
  TestSearchLibs_AArch64;
  TestSearchLibs_Android;
  TestSearchLibs_Mipsel;

  // DiagnoseTarget
  TestDiagnose_Basic;
  TestDiagnose_ContainsBinutilsStatus;
  TestDiagnose_ContainsLibsStatus;
  TestDiagnose_ContainsSearchLog;
  TestDiagnose_UnknownTarget;
  TestDiagnose_FoundTarget;

  // Multiple dirs
  TestSearchLibs_MultipleDirs;

  // System-dependent
  TestSearchLibs_RealSystem;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
