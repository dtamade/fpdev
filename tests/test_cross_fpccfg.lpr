program test_cross_fpccfg;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.cross.fpccfg, test_temp_paths;

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

function MakeTarget(const ACPU, AOS, AABI, ASubArch, ABinutilsPath,
  ABinutilsPrefix, ALibPath, ACrossOpt: string): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := True;
  Result.CPU := ACPU;
  Result.OS := AOS;
  Result.ABI := AABI;
  Result.SubArch := ASubArch;
  Result.BinutilsPath := ABinutilsPath;
  Result.BinutilsPrefix := ABinutilsPrefix;
  Result.LibrariesPath := ALibPath;
  Result.CrossOpt := ACrossOpt;
end;

{ HasCrossTarget tests }

procedure TestHasCrossTarget_Empty;
var
  Mgr: TFPCCfgManager;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Check(Mgr.HasCrossTarget('arm', 'linux') = False,
      'HasCrossTarget: empty file returns False');
  finally
    Mgr.Free;
  end;
end;

procedure TestHasCrossTarget_Exists;
var
  Mgr: TFPCCfgManager;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString(
      '# some config' + LineEnding +
      '# BEGIN fpdev-cross:arm-linux' + LineEnding +
      '#IFDEF CPUARM' + LineEnding +
      '#ENDIF' + LineEnding +
      '# END fpdev-cross:arm-linux' + LineEnding);
    Check(Mgr.HasCrossTarget('arm', 'linux') = True,
      'HasCrossTarget: existing section returns True');
    Check(Mgr.HasCrossTarget('x86_64', 'win64') = False,
      'HasCrossTarget: non-existing section returns False');
  finally
    Mgr.Free;
  end;
end;

{ InsertCrossTarget tests }

procedure TestInsert_EmptyFile;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7',
      '/usr/bin', 'arm-linux-gnueabihf-',
      '/usr/arm-linux-gnueabihf/lib', '');
    Check(Mgr.InsertCrossTarget(Target) = True,
      'Insert: succeeds on empty file');
    Content := Mgr.GetContent;
    Check(Pos('# BEGIN fpdev-cross:arm-linux', Content) > 0,
      'Insert: has BEGIN tag');
    Check(Pos('# END fpdev-cross:arm-linux', Content) > 0,
      'Insert: has END tag');
    Check(Pos('#IFDEF CPUARM', Content) > 0,
      'Insert: has CPU ifdef');
    Check(Pos('#IFDEF LINUX', Content) > 0,
      'Insert: has OS ifdef');
    Check(Pos('-FD/usr/bin', Content) > 0,
      'Insert: has binutils path');
    Check(Pos('-XParm-linux-gnueabihf-', Content) > 0,
      'Insert: has binutils prefix');
    Check(Pos('-Fl/usr/arm-linux-gnueabihf/lib', Content) > 0,
      'Insert: has library path');
    Check(Pos('-CaEABIHF', Content) > 0,
      'Insert: has ABI option');
    Check(Pos('-CfVFPV3', Content) > 0,
      'Insert: has FPU option');
    Check(Pos('-CpARMV7A', Content) > 0,
      'Insert: has SubArch option');
  finally
    Mgr.Free;
  end;
end;

procedure TestInsert_ExistingContent;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString(
      '# existing config' + LineEnding +
      '-O2' + LineEnding);
    Target := MakeTarget('x86_64', 'win64', '', '', '', 'x86_64-w64-mingw32-', '', '');
    Check(Mgr.InsertCrossTarget(Target) = True,
      'Insert: succeeds with existing content');
    Content := Mgr.GetContent;
    Check(Pos('# existing config', Content) > 0,
      'Insert: preserves existing content');
    Check(Pos('-O2', Content) > 0,
      'Insert: preserves existing options');
    Check(Pos('# BEGIN fpdev-cross:x86_64-win64', Content) > 0,
      'Insert: new section added');
  finally
    Mgr.Free;
  end;
end;

procedure TestInsert_Duplicate;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := MakeTarget('arm', 'linux', '', '', '', '', '', '');
    Mgr.InsertCrossTarget(Target);
    Check(Mgr.InsertCrossTarget(Target) = False,
      'Insert: duplicate returns False');
    Check(Pos('already exists', Mgr.GetLastError) > 0,
      'Insert: error mentions already exists');
  finally
    Mgr.Free;
  end;
end;

procedure TestInsert_MissingCPU;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := Default(TCrossTarget);
    Target.OS := 'linux';
    Check(Mgr.InsertCrossTarget(Target) = False,
      'Insert: missing CPU returns False');
  finally
    Mgr.Free;
  end;
end;

procedure TestInsert_WithExplicitCrossOpt;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := MakeTarget('arm', 'linux', '', '', '/usr/bin', '',
      '/usr/arm-linux-gnueabihf/lib', '-CaEABIHF -CfVFPV3 -CpARMV7A');
    Mgr.InsertCrossTarget(Target);
    Content := Mgr.GetContent;
    Check(Pos('-CaEABIHF -CfVFPV3 -CpARMV7A', Content) > 0,
      'Insert: explicit CrossOpt used directly');
  finally
    Mgr.Free;
  end;
end;

{ UpdateCrossTarget tests }

procedure TestUpdate_Existing;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    // Insert initial
    Target := MakeTarget('arm', 'linux', 'eabi', '', '/usr/bin', '', '', '');
    Mgr.InsertCrossTarget(Target);
    Check(Pos('-CaEABI', Mgr.GetContent) > 0, 'Update: initial has -CaEABI');

    // Update to eabihf
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7',
      '/opt/cross/bin', 'arm-linux-gnueabihf-',
      '/opt/cross/arm-linux-gnueabihf/lib', '');
    Check(Mgr.UpdateCrossTarget(Target) = True,
      'Update: succeeds for existing section');
    Content := Mgr.GetContent;
    Check(Pos('-CaEABIHF', Content) > 0,
      'Update: new content has -CaEABIHF');
    Check(Pos('-CfVFPV3', Content) > 0,
      'Update: new content has -CfVFPV3');
    Check(Pos('-FD/opt/cross/bin', Content) > 0,
      'Update: new binutils path');
  finally
    Mgr.Free;
  end;
end;

procedure TestUpdate_NonExisting;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := MakeTarget('arm', 'linux', '', '', '', '', '', '');
    Check(Mgr.UpdateCrossTarget(Target) = False,
      'Update: non-existing returns False');
    Check(Pos('not found', Mgr.GetLastError) > 0,
      'Update: error mentions not found');
  finally
    Mgr.Free;
  end;
end;

{ RemoveCrossTarget tests }

procedure TestRemove_Existing;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := MakeTarget('arm', 'linux', 'eabihf', '', '', '', '', '');
    Mgr.InsertCrossTarget(Target);
    Check(Mgr.HasCrossTarget('arm', 'linux') = True,
      'Remove: section exists before remove');

    Check(Mgr.RemoveCrossTarget('arm', 'linux') = True,
      'Remove: succeeds');
    Content := Mgr.GetContent;
    Check(Pos('fpdev-cross:arm-linux', Content) = 0,
      'Remove: section completely gone');
    Check(Mgr.HasCrossTarget('arm', 'linux') = False,
      'Remove: HasCrossTarget returns False after remove');
  finally
    Mgr.Free;
  end;
end;

procedure TestRemove_PreservesOtherSections;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    // Insert two sections
    Target := MakeTarget('arm', 'linux', '', '', '', '', '', '');
    Mgr.InsertCrossTarget(Target);
    Target := MakeTarget('x86_64', 'win64', '', '', '', '', '', '');
    Mgr.InsertCrossTarget(Target);

    // Remove first
    Mgr.RemoveCrossTarget('arm', 'linux');
    Content := Mgr.GetContent;
    Check(Pos('fpdev-cross:arm-linux', Content) = 0,
      'Remove: arm-linux section gone');
    Check(Pos('fpdev-cross:x86_64-win64', Content) > 0,
      'Remove: x86_64-win64 section preserved');
  finally
    Mgr.Free;
  end;
end;

procedure TestRemove_NonExisting;
var
  Mgr: TFPCCfgManager;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Check(Mgr.RemoveCrossTarget('arm', 'linux') = False,
      'Remove: non-existing returns False');
  finally
    Mgr.Free;
  end;
end;

{ InsertOrUpdate tests }

procedure TestInsertOrUpdate_Insert;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := MakeTarget('arm', 'linux', '', '', '', '', '', '');
    Check(Mgr.InsertOrUpdate(Target) = True,
      'InsertOrUpdate: inserts when not present');
    Check(Mgr.HasCrossTarget('arm', 'linux') = True,
      'InsertOrUpdate: section exists after insert');
  finally
    Mgr.Free;
  end;
end;

procedure TestInsertOrUpdate_Update;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    Target := MakeTarget('arm', 'linux', 'eabi', '', '', '', '', '');
    Mgr.InsertOrUpdate(Target);

    // Update
    Target := MakeTarget('arm', 'linux', 'eabihf', '', '', '', '', '');
    Check(Mgr.InsertOrUpdate(Target) = True,
      'InsertOrUpdate: updates when present');
    Content := Mgr.GetContent;
    Check(Pos('-CaEABIHF', Content) > 0,
      'InsertOrUpdate: updated content correct');
  finally
    Mgr.Free;
  end;
end;

{ Round-trip test }

procedure TestRoundTrip_InsertRemoveInsert;
var
  Mgr: TFPCCfgManager;
  Target: TCrossTarget;
  Content: string;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('# original config' + LineEnding);

    // Insert
    Target := MakeTarget('arm', 'linux', 'eabihf', 'armv7',
      '/usr/bin', 'arm-linux-gnueabihf-',
      '/usr/arm-linux-gnueabihf/lib', '');
    Mgr.InsertCrossTarget(Target);
    Check(Mgr.HasCrossTarget('arm', 'linux'), 'RoundTrip: present after insert');

    // Remove
    Mgr.RemoveCrossTarget('arm', 'linux');
    Check(not Mgr.HasCrossTarget('arm', 'linux'), 'RoundTrip: gone after remove');

    // Re-insert
    Target.ABI := 'eabi';
    Mgr.InsertCrossTarget(Target);
    Content := Mgr.GetContent;
    Check(Mgr.HasCrossTarget('arm', 'linux'), 'RoundTrip: present after re-insert');
    Check(Pos('-CaEABI', Content) > 0, 'RoundTrip: re-inserted with new ABI');
    Check(Pos('# original config', Content) > 0, 'RoundTrip: original config preserved');
  finally
    Mgr.Free;
  end;
end;

{ File I/O test }

procedure TestFileIO_SaveAndLoad;
var
  Mgr1, Mgr2: TFPCCfgManager;
  Target: TCrossTarget;
  TempDir, TmpFile: string;
begin
  TempDir := CreateUniqueTempDir('test_fpccfg');
  TmpFile := TempDir + PathDelim + 'test_fpccfg.cfg';
  try
    // Save
    Mgr1 := TFPCCfgManager.Create(TmpFile);
    try
      Mgr1.LoadFromString('# test config' + LineEnding);
      Target := MakeTarget('arm', 'linux', 'eabihf', '',
        '/usr/bin', 'arm-linux-gnueabihf-', '/usr/arm-linux-gnueabihf/lib', '');
      Mgr1.InsertCrossTarget(Target);
      Check(Mgr1.SaveToFile = True, 'FileIO: save succeeds');
    finally
      Mgr1.Free;
    end;

    // Load
    Mgr2 := TFPCCfgManager.Create(TmpFile);
    try
      Check(Mgr2.LoadFromFile = True, 'FileIO: load succeeds');
      Check(Mgr2.HasCrossTarget('arm', 'linux') = True,
        'FileIO: loaded file has cross target');
      Check(Pos('-CaEABIHF', Mgr2.GetContent) > 0,
        'FileIO: loaded content has -CaEABIHF');
    finally
      Mgr2.Free;
    end;
  finally
    CleanupTempDir(TempDir);
  end;
end;

{ Multi-target test }

procedure TestMultiTarget;
var
  Mgr: TFPCCfgManager;
  T1, T2, T3: TCrossTarget;
begin
  Mgr := TFPCCfgManager.Create('');
  try
    Mgr.LoadFromString('');
    T1 := MakeTarget('arm', 'linux', 'eabihf', '', '', '', '', '');
    T2 := MakeTarget('x86_64', 'win64', '', '', '', '', '', '');
    T3 := MakeTarget('aarch64', 'linux', '', '', '', '', '', '');

    Mgr.InsertCrossTarget(T1);
    Mgr.InsertCrossTarget(T2);
    Mgr.InsertCrossTarget(T3);

    Check(Mgr.HasCrossTarget('arm', 'linux'), 'MultiTarget: has arm-linux');
    Check(Mgr.HasCrossTarget('x86_64', 'win64'), 'MultiTarget: has x86_64-win64');
    Check(Mgr.HasCrossTarget('aarch64', 'linux'), 'MultiTarget: has aarch64-linux');

    // Remove middle one
    Mgr.RemoveCrossTarget('x86_64', 'win64');
    Check(not Mgr.HasCrossTarget('x86_64', 'win64'), 'MultiTarget: x86_64-win64 removed');
    Check(Mgr.HasCrossTarget('arm', 'linux'), 'MultiTarget: arm-linux still present');
    Check(Mgr.HasCrossTarget('aarch64', 'linux'), 'MultiTarget: aarch64-linux still present');
  finally
    Mgr.Free;
  end;
end;

begin
  WriteLn('=== fpc.cfg Cross-Compilation Manager Tests ===');
  WriteLn;

  // HasCrossTarget
  TestHasCrossTarget_Empty;
  TestHasCrossTarget_Exists;

  // Insert
  TestInsert_EmptyFile;
  TestInsert_ExistingContent;
  TestInsert_Duplicate;
  TestInsert_MissingCPU;
  TestInsert_WithExplicitCrossOpt;

  // Update
  TestUpdate_Existing;
  TestUpdate_NonExisting;

  // Remove
  TestRemove_Existing;
  TestRemove_PreservesOtherSections;
  TestRemove_NonExisting;

  // InsertOrUpdate
  TestInsertOrUpdate_Insert;
  TestInsertOrUpdate_Update;

  // Round-trip
  TestRoundTrip_InsertRemoveInsert;

  // File I/O
  TestFileIO_SaveAndLoad;

  // Multi-target
  TestMultiTarget;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
