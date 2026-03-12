program test_cross_search;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.cross.search, test_temp_paths;

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

function MakeTarget(const ACPU, AOS: string): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := True;
  Result.CPU := ACPU;
  Result.OS := AOS;
end;

function MakeTargetFull(const ACPU, AOS, AABI, ABinutilsPath, ABinutilsPrefix: string): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := True;
  Result.CPU := ACPU;
  Result.OS := AOS;
  Result.ABI := AABI;
  Result.BinutilsPath := ABinutilsPath;
  Result.BinutilsPrefix := ABinutilsPrefix;
end;

{ === Tests: Constructor and basic API === }

procedure TestCreateAndFree;
var
  S: TCrossToolchainSearch;
begin
  S := TCrossToolchainSearch.Create;
  try
    Check(S.GetSearchLogCount = 0, 'Create: log count starts at 0');
  finally
    S.Free;
  end;
end;

procedure TestClearLog;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    S.SearchBinutils(T);
    Check(S.GetSearchLogCount > 0, 'ClearLog: search produces log entries');
    S.ClearLog;
    Check(S.GetSearchLogCount = 0, 'ClearLog: count is 0 after clear');
  finally
    S.Free;
  end;
end;

{ === Tests: Prefix candidates === }

procedure TestPrefixCandidates_ARM;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasGnueabihf: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasGnueabihf := False;
    for I := 0 to High(Log) do
      if Pos('arm-linux-gnueabihf-', Log[I]) > 0 then
        HasGnueabihf := True;
    Check(HasGnueabihf, 'Prefix ARM linux: searches arm-linux-gnueabihf-');
  finally
    S.Free;
  end;
end;

procedure TestPrefixCandidates_Win64;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasMingw: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('x86_64', 'win64');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasMingw := False;
    for I := 0 to High(Log) do
      if Pos('x86_64-w64-mingw32-', Log[I]) > 0 then
        HasMingw := True;
    Check(HasMingw, 'Prefix Win64: searches x86_64-w64-mingw32-');
  finally
    S.Free;
  end;
end;

procedure TestPrefixCandidates_AArch64;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasGnu: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('aarch64', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasGnu := False;
    for I := 0 to High(Log) do
      if Pos('aarch64-linux-gnu-', Log[I]) > 0 then
        HasGnu := True;
    Check(HasGnu, 'Prefix AArch64: searches aarch64-linux-gnu-');
  finally
    S.Free;
  end;
end;

procedure TestPrefixCandidates_ConfiguredPrefix;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasCustom: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTargetFull('arm', 'linux', '', '', 'my-custom-prefix-');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasCustom := False;
    for I := 0 to High(Log) do
      if Pos('my-custom-prefix-', Log[I]) > 0 then
        HasCustom := True;
    Check(HasCustom, 'ConfiguredPrefix: uses custom prefix');
  finally
    S.Free;
  end;
end;

{ === Tests: Layer execution order === }

procedure TestLayerOrder;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  SeenLayer1, SeenLayer2: Boolean;
  I, Layer1Idx, Layer2Idx: Integer;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    SeenLayer1 := False;
    SeenLayer2 := False;
    Layer1Idx := MaxInt;
    Layer2Idx := MaxInt;
    for I := 0 to High(Log) do
    begin
      if Pos('[L1:', Log[I]) = 1 then
      begin
        SeenLayer1 := True;
        if I < Layer1Idx then Layer1Idx := I;
      end;
      if Pos('[L2:', Log[I]) = 1 then
      begin
        SeenLayer2 := True;
        if I < Layer2Idx then Layer2Idx := I;
      end;
    end;
    Check(SeenLayer1, 'LayerOrder: Layer 1 (fpdev-managed) is searched');
    Check(SeenLayer2, 'LayerOrder: Layer 2 (system-paths) is searched');
    Check(Layer1Idx < Layer2Idx, 'LayerOrder: Layer 1 before Layer 2');
  finally
    S.Free;
  end;
end;

procedure TestSearchLogFormat;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('x86_64', 'win64');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    Check(Length(Log) > 0, 'SearchLogFormat: log is non-empty');
    Check(Pos('[L', Log[0]) = 1, 'SearchLogFormat: entry starts with [L');
    Check(Pos('=>', Log[0]) > 0, 'SearchLogFormat: entry has => marker');
  finally
    S.Free;
  end;
end;

{ === Tests: Configured path shortcut === }

procedure TestConfiguredPathFound;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Res: TCrossSearchResult;
  TmpDir, ToolPath: string;
begin
  TmpDir := '';
  S := TCrossToolchainSearch.Create;
  try
    // Create a temp directory with a fake tool
    TmpDir := CreateUniqueTempDir('fpdev_test_search');
    ToolPath := TmpDir + PathDelim + 'arm-linux-gnueabihf-as';
    // Create a dummy file
    with TFileStream.Create(ToolPath, fmCreate) do Free;

    T := MakeTargetFull('arm', 'linux', '', TmpDir, 'arm-linux-gnueabihf-');
    Res := S.SearchBinutilsWithConfig(T, '');

    Check(Res.Found, 'ConfiguredPath: finds tool in configured path');
    Check(Res.Layer = 0, 'ConfiguredPath: layer = 0 (configured)');
    Check(Res.BinutilsPath = TmpDir, 'ConfiguredPath: correct path');
    Check(Res.BinutilsPrefix = 'arm-linux-gnueabihf-', 'ConfiguredPath: correct prefix');

  finally
    S.Free;
    CleanupTempDir(TmpDir);
  end;
end;

procedure TestConfiguredPathNotFound;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Res: TCrossSearchResult;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTargetFull('arm', 'linux', '', '/nonexistent/path', 'arm-linux-gnueabihf-');
    Res := S.SearchBinutilsWithConfig(T, '');
    // Should still search other layers after configured path fails
    Check(S.GetSearchLogCount > 1, 'ConfiguredPathNotFound: searches other layers');
  finally
    S.Free;
  end;
end;

{ === Tests: Layer 1 (fpdev-managed) simulation === }

procedure TestLayer1_FPDevManaged;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasFpdevManaged: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasFpdevManaged := False;
    for I := 0 to High(Log) do
      if Pos('fpdev-managed', Log[I]) > 0 then
        HasFpdevManaged := True;
    Check(HasFpdevManaged, 'Layer1: fpdev-managed directories searched');
  finally
    S.Free;
  end;
end;

{ === Tests: Layer 6 (fpc.cfg config hints) === }

procedure TestLayer6_ConfigHints_WithMatch;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  TempRoot, TmpCfg, BinDir, ToolPath: string;
  SL: TStringList;
  Log: TStringArray;
  HasConfigHints: Boolean;
  I: Integer;
begin
  TempRoot := '';
  S := TCrossToolchainSearch.Create;
  try
    // Use a very unusual target that won't be found on the system
    // so search reaches Layer 6

    // Create a temp binutils dir with a dummy tool
    TempRoot := CreateUniqueTempDir('fpdev_test_bindir');
    BinDir := TempRoot + PathDelim + 'bin';
    ForceDirectories(BinDir);
    ToolPath := BinDir + PathDelim + 'sparc64-solaris-as';
    with TFileStream.Create(ToolPath, fmCreate) do Free;

    // Create a temp fpc.cfg pointing to it
    TmpCfg := TempRoot + PathDelim + 'fpdev_test_fpc.cfg';
    SL := TStringList.Create;
    try
      SL.Add('# FPC configuration');
      SL.Add('#IFDEF CPUSPARC');
      SL.Add('#IFDEF SOLARIS');
      SL.Add('-FD' + BinDir);
      SL.Add('-XPsparc64-solaris-');
      SL.Add('#ENDIF');
      SL.Add('#ENDIF');
      SL.SaveToFile(TmpCfg);
    finally
      SL.Free;
    end;

    T := MakeTarget('sparc', 'solaris');
    S.SearchBinutilsWithConfig(T, TmpCfg);

    Check(S.GetSearchLogCount > 0, 'ConfigHints: produces log entries');

    Log := S.GetSearchLog;
    HasConfigHints := False;
    for I := 0 to High(Log) do
      if Pos('config-hints', Log[I]) > 0 then
        HasConfigHints := True;
    Check(HasConfigHints, 'ConfigHints: config-hints layer present in log');

  finally
    S.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestLayer6_ConfigHints_NoFile;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    S.SearchBinutilsWithConfig(T, '/nonexistent/fpc.cfg');
    // Should still complete without error
    Check(S.GetSearchLogCount > 0, 'ConfigHints NoFile: search completes with log');
  finally
    S.Free;
  end;
end;

{ === Tests: Library search === }

procedure TestSearchLibraries_ARM;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'linux');
    T.LibrariesPath := '/usr/arm-linux-gnueabihf/lib';
    Libs := S.SearchLibraries(T);
    Check(Length(Libs) >= 1, 'SearchLibs ARM: returns candidates');
    Check(Libs[0] = '/usr/arm-linux-gnueabihf/lib', 'SearchLibs ARM: configured path is first');
  finally
    S.Free;
  end;
end;

procedure TestSearchLibraries_NoConfigured;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Libs: TStringArray;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('x86_64', 'win64');
    Libs := S.SearchLibraries(T);
    // On most systems, the candidate list will be empty (dirs don't exist)
    // but the function should not crash
    Check(True, 'SearchLibs NoConfigured: does not crash');
  finally
    S.Free;
  end;
end;

{ === Tests: Multiple architectures search === }

procedure TestSearchMultiArch;
var
  S: TCrossToolchainSearch;
  Targets: array[0..4] of TCrossTarget;
  I: Integer;
begin
  S := TCrossToolchainSearch.Create;
  try
    Targets[0] := MakeTarget('arm', 'linux');
    Targets[1] := MakeTarget('aarch64', 'linux');
    Targets[2] := MakeTarget('x86_64', 'win64');
    Targets[3] := MakeTarget('i386', 'win32');
    Targets[4] := MakeTarget('riscv64', 'linux');

    for I := 0 to High(Targets) do
    begin
      S.SearchBinutils(Targets[I]);
      Check(S.GetSearchLogCount > 0,
        'MultiArch ' + Targets[I].CPU + '-' + Targets[I].OS + ': produces log');
    end;
  finally
    S.Free;
  end;
end;

{ === Tests: Result record structure === }

procedure TestResultRecord_NotFound;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Res: TCrossSearchResult;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('zzz_unknown', 'zzz_unknown');
    Res := S.SearchBinutils(T);
    Check(not Res.Found, 'ResultRecord NotFound: Found is false for unknown target');
    Check(Res.BinutilsPath = '', 'ResultRecord NotFound: path is empty');
    Check(Res.BinutilsPrefix = '', 'ResultRecord NotFound: prefix is empty');
  finally
    S.Free;
  end;
end;

procedure TestResultRecord_FoundMock;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Res: TCrossSearchResult;
  TmpDir, ToolPath: string;
begin
  TmpDir := '';
  S := TCrossToolchainSearch.Create;
  try
    // Create temp dir simulating fpdev-managed cross toolchain
    TmpDir := CreateUniqueTempDir('fpdev_test_result');
    ToolPath := TmpDir + PathDelim + 'test-prefix-as';
    with TFileStream.Create(ToolPath, fmCreate) do Free;

    T := MakeTargetFull('arm', 'linux', '', TmpDir, 'test-prefix-');
    Res := S.SearchBinutilsWithConfig(T, '');

    Check(Res.Found, 'ResultRecord Found: Found is true');
    Check(Res.BinutilsPath = TmpDir, 'ResultRecord Found: correct path');
    Check(Res.BinutilsPrefix = 'test-prefix-', 'ResultRecord Found: correct prefix');
    Check(Res.Layer >= 0, 'ResultRecord Found: layer >= 0');
    Check(Res.LayerName <> '', 'ResultRecord Found: layer name non-empty');

  finally
    S.Free;
    CleanupTempDir(TmpDir);
  end;
end;

{ === Tests: Prefix candidates for more architectures === }

procedure TestPrefix_Mipsel;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasMipsel: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('mipsel', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasMipsel := False;
    for I := 0 to High(Log) do
      if Pos('mipsel-linux-gnu-', Log[I]) > 0 then
        HasMipsel := True;
    Check(HasMipsel, 'Prefix mipsel: searches mipsel-linux-gnu-');
  finally
    S.Free;
  end;
end;

procedure TestPrefix_Riscv64;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasRiscv: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('riscv64', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasRiscv := False;
    for I := 0 to High(Log) do
      if Pos('riscv64-linux-gnu-', Log[I]) > 0 then
        HasRiscv := True;
    Check(HasRiscv, 'Prefix riscv64: searches riscv64-linux-gnu-');
  finally
    S.Free;
  end;
end;

procedure TestPrefix_Powerpc64;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasPpc: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('powerpc64', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasPpc := False;
    for I := 0 to High(Log) do
      if Pos('powerpc64', Log[I]) > 0 then
        HasPpc := True;
    Check(HasPpc, 'Prefix powerpc64: searches powerpc64 variants');
  finally
    S.Free;
  end;
end;

procedure TestPrefix_Sparc;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasSparc: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('sparc', 'linux');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasSparc := False;
    for I := 0 to High(Log) do
      if Pos('sparc', Log[I]) > 0 then
        HasSparc := True;
    Check(HasSparc, 'Prefix sparc: searches sparc variants');
  finally
    S.Free;
  end;
end;

{ === Tests: Android targets === }

procedure TestPrefix_AndroidARM;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasAndroid: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('arm', 'android');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasAndroid := False;
    for I := 0 to High(Log) do
      if Pos('androideabi-', Log[I]) > 0 then
        HasAndroid := True;
    Check(HasAndroid, 'Prefix Android ARM: searches androideabi prefix');
  finally
    S.Free;
  end;
end;

{ === Tests: Darwin targets === }

procedure TestPrefix_DarwinAArch64;
var
  S: TCrossToolchainSearch;
  T: TCrossTarget;
  Log: TStringArray;
  I: Integer;
  HasDarwin: Boolean;
begin
  S := TCrossToolchainSearch.Create;
  try
    T := MakeTarget('aarch64', 'darwin');
    S.SearchBinutils(T);
    Log := S.GetSearchLog;
    HasDarwin := False;
    for I := 0 to High(Log) do
      if Pos('aarch64-apple-darwin-', Log[I]) > 0 then
        HasDarwin := True;
    Check(HasDarwin, 'Prefix Darwin AArch64: searches apple-darwin prefix');
  finally
    S.Free;
  end;
end;

begin
  WriteLn('=== Cross-Compilation Toolchain Search Tests ===');
  WriteLn;

  // Basic API
  TestCreateAndFree;
  TestClearLog;

  // Prefix candidates
  TestPrefixCandidates_ARM;
  TestPrefixCandidates_Win64;
  TestPrefixCandidates_AArch64;
  TestPrefixCandidates_ConfiguredPrefix;

  // Layer execution
  TestLayerOrder;
  TestSearchLogFormat;

  // Configured path
  TestConfiguredPathFound;
  TestConfiguredPathNotFound;

  // Layer 1 (fpdev-managed)
  TestLayer1_FPDevManaged;

  // Layer 6 (config hints)
  TestLayer6_ConfigHints_WithMatch;
  TestLayer6_ConfigHints_NoFile;

  // Library search
  TestSearchLibraries_ARM;
  TestSearchLibraries_NoConfigured;

  // Multi-architecture
  TestSearchMultiArch;

  // Result record
  TestResultRecord_NotFound;
  TestResultRecord_FoundMock;

  // Extended prefixes
  TestPrefix_Mipsel;
  TestPrefix_Riscv64;
  TestPrefix_Powerpc64;
  TestPrefix_Sparc;
  TestPrefix_AndroidARM;
  TestPrefix_DarwinAArch64;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
