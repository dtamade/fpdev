program test_cross_config_extended;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config.interfaces, fpdev.config.managers, test_temp_paths;

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

function MakeTmpConfigPath: string;
begin
  Result := CreateUniqueTempDir('fpdev_test_config_ext') + PathDelim + 'config.json';
end;

procedure CleanupTmpConfigPath(const APath: string);
begin
  if APath <> '' then
    CleanupTempDir(ExtractFileDir(APath));
end;

{ === Tests: Extended fields round-trip via AddCrossTarget/GetCrossTarget === }

procedure TestExtendedFields_RoundTrip;
var
  Cfg: IConfigManager;
  CrossMgr: ICrossTargetManager;
  Target, ReadBack: TCrossTarget;
  TmpPath: string;
begin
  TmpPath := MakeTmpConfigPath;
  Cfg := TConfigManager.Create(TmpPath);
  Cfg.LoadConfig;
  CrossMgr := Cfg.GetCrossTargetManager;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.BinutilsPath := '/usr/bin';
  Target.LibrariesPath := '/usr/lib/arm-linux';
  Target.CPU := 'arm';
  Target.OS := 'linux';
  Target.SubArch := 'armv7';
  Target.ABI := 'eabihf';
  Target.BinutilsPrefix := 'arm-linux-gnueabihf-';
  Target.CrossOpt := '-CaEABIHF -CfVFPV3';

  CrossMgr.AddCrossTarget('arm-linux', Target);
  Check(CrossMgr.GetCrossTarget('arm-linux', ReadBack), 'RoundTrip: target found');
  Check(ReadBack.Enabled = True, 'RoundTrip: Enabled preserved');
  Check(ReadBack.BinutilsPath = '/usr/bin', 'RoundTrip: BinutilsPath preserved');
  Check(ReadBack.LibrariesPath = '/usr/lib/arm-linux', 'RoundTrip: LibrariesPath preserved');
  Check(ReadBack.CPU = 'arm', 'RoundTrip: CPU preserved');
  Check(ReadBack.OS = 'linux', 'RoundTrip: OS preserved');
  Check(ReadBack.SubArch = 'armv7', 'RoundTrip: SubArch preserved');
  Check(ReadBack.ABI = 'eabihf', 'RoundTrip: ABI preserved');
  Check(ReadBack.BinutilsPrefix = 'arm-linux-gnueabihf-', 'RoundTrip: BinutilsPrefix preserved');
  Check(ReadBack.CrossOpt = '-CaEABIHF -CfVFPV3', 'RoundTrip: CrossOpt preserved');
  CleanupTmpConfigPath(TmpPath);
end;

{ === Tests: Backward compatibility - old format (3 fields only) === }

procedure TestBackwardCompat_OldFormatJSON;
var
  Cfg: IConfigManager;
  CrossMgr: ICrossTargetManager;
  ReadBack: TCrossTarget;
  TmpPath: string;
  SL: TStringList;
begin
  TmpPath := MakeTmpConfigPath;
  // Write old-format config with only 3 fields
  SL := TStringList.Create;
  try
    SL.Add('{');
    SL.Add('  "version": "1.0",');
    SL.Add('  "toolchains": {},');
    SL.Add('  "lazarus": {"default_version":"","versions":{}},');
    SL.Add('  "cross_targets": {');
    SL.Add('    "win64": {');
    SL.Add('      "enabled": true,');
    SL.Add('      "binutils_path": "/usr/x86_64-w64-mingw32/bin",');
    SL.Add('      "libraries_path": "/usr/x86_64-w64-mingw32/lib"');
    SL.Add('    }');
    SL.Add('  },');
    SL.Add('  "repositories": {},');
    SL.Add('  "settings": {"auto_update":false,"parallel_jobs":2,"keep_sources":true,"install_root":""}');
    SL.Add('}');
    SL.SaveToFile(TmpPath);
  finally
    SL.Free;
  end;

  Cfg := TConfigManager.Create(TmpPath);
  Cfg.LoadConfig;
  CrossMgr := Cfg.GetCrossTargetManager;

  Check(CrossMgr.GetCrossTarget('win64', ReadBack), 'OldFormat: win64 found');
  Check(ReadBack.Enabled = True, 'OldFormat: Enabled read correctly');
  Check(ReadBack.BinutilsPath = '/usr/x86_64-w64-mingw32/bin', 'OldFormat: BinutilsPath read');
  Check(ReadBack.LibrariesPath = '/usr/x86_64-w64-mingw32/lib', 'OldFormat: LibrariesPath read');
  // Extended fields should default to empty
  Check(ReadBack.CPU = '', 'OldFormat: CPU defaults to empty');
  Check(ReadBack.OS = '', 'OldFormat: OS defaults to empty');
  Check(ReadBack.SubArch = '', 'OldFormat: SubArch defaults to empty');
  Check(ReadBack.ABI = '', 'OldFormat: ABI defaults to empty');
  Check(ReadBack.BinutilsPrefix = '', 'OldFormat: BinutilsPrefix defaults to empty');
  Check(ReadBack.CrossOpt = '', 'OldFormat: CrossOpt defaults to empty');

  CleanupTmpConfigPath(TmpPath);
end;

{ === Tests: Extended fields are written to JSON correctly === }

procedure TestExtendedFields_SaveToJSON;
var
  Cfg: IConfigManager;
  CrossMgr: ICrossTargetManager;
  Target: TCrossTarget;
  TmpPath: string;
  SL: TStringList;
  JSON: string;
begin
  TmpPath := MakeTmpConfigPath;
  Cfg := TConfigManager.Create(TmpPath);
  Cfg.LoadConfig;
  CrossMgr := Cfg.GetCrossTargetManager;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.BinutilsPath := '/path/bin';
  Target.LibrariesPath := '/path/lib';
  Target.CPU := 'aarch64';
  Target.OS := 'darwin';
  Target.BinutilsPrefix := 'aarch64-apple-darwin-';
  CrossMgr.AddCrossTarget('aarch64-darwin', Target);

  Cfg.SaveConfig;

  // Read back the file to verify JSON structure
  SL := TStringList.Create;
  try
    SL.LoadFromFile(TmpPath);
    JSON := SL.Text;
    Check(Pos('"cpu"', JSON) > 0, 'SaveJSON: cpu field written');
    Check(Pos('"aarch64"', JSON) > 0, 'SaveJSON: aarch64 value written');
    Check(Pos('"os"', JSON) > 0, 'SaveJSON: os field written');
    Check(Pos('"darwin"', JSON) > 0, 'SaveJSON: darwin value written');
    Check(Pos('"binutils_prefix"', JSON) > 0, 'SaveJSON: binutils_prefix written');
  finally
    SL.Free;
  end;

  CleanupTmpConfigPath(TmpPath);
end;

{ === Tests: Empty extended fields not written to JSON === }

procedure TestEmptyFields_NotWritten;
var
  Cfg: IConfigManager;
  CrossMgr: ICrossTargetManager;
  Target: TCrossTarget;
  TmpPath: string;
  SL: TStringList;
  JSON: string;
begin
  TmpPath := MakeTmpConfigPath;
  Cfg := TConfigManager.Create(TmpPath);
  Cfg.LoadConfig;
  CrossMgr := Cfg.GetCrossTargetManager;

  // Only set the 3 original fields
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.BinutilsPath := '/bin';
  Target.LibrariesPath := '/lib';
  CrossMgr.AddCrossTarget('minimal', Target);

  Cfg.SaveConfig;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(TmpPath);
    JSON := SL.Text;
    // Empty extended fields should not appear in JSON
    Check(Pos('"cpu"', JSON) = 0, 'EmptyFields: cpu not written when empty');
    Check(Pos('"sub_arch"', JSON) = 0, 'EmptyFields: sub_arch not written');
    Check(Pos('"abi"', JSON) = 0, 'EmptyFields: abi not written');
    Check(Pos('"cross_opt"', JSON) = 0, 'EmptyFields: cross_opt not written');
  finally
    SL.Free;
  end;

  CleanupTmpConfigPath(TmpPath);
end;

{ === Tests: Multiple targets with different field combinations === }

procedure TestMultipleTargets;
var
  Cfg: IConfigManager;
  CrossMgr: ICrossTargetManager;
  T1, T2, R1, R2: TCrossTarget;
  Names: TStringArray;
  TmpPath: string;
begin
  TmpPath := MakeTmpConfigPath;
  Cfg := TConfigManager.Create(TmpPath);
  Cfg.LoadConfig;
  CrossMgr := Cfg.GetCrossTargetManager;

  T1 := Default(TCrossTarget);
  T1.Enabled := True;
  T1.CPU := 'arm';
  T1.OS := 'linux';
  T1.ABI := 'eabihf';
  CrossMgr.AddCrossTarget('arm-linux', T1);

  T2 := Default(TCrossTarget);
  T2.Enabled := False;
  T2.CPU := 'x86_64';
  T2.OS := 'win64';
  CrossMgr.AddCrossTarget('win64', T2);

  Names := CrossMgr.ListCrossTargets;
  Check(Length(Names) = 2, 'MultiTarget: 2 targets');

  Check(CrossMgr.GetCrossTarget('arm-linux', R1), 'MultiTarget: arm-linux found');
  Check(R1.ABI = 'eabihf', 'MultiTarget: arm-linux ABI correct');

  Check(CrossMgr.GetCrossTarget('win64', R2), 'MultiTarget: win64 found');
  Check(R2.Enabled = False, 'MultiTarget: win64 disabled');
  Check(R2.CPU = 'x86_64', 'MultiTarget: win64 CPU correct');
  CleanupTmpConfigPath(TmpPath);
end;

{ === Tests: Save and reload preserves all fields === }

procedure TestSaveReload_FullCycle;
var
  Cfg1, Cfg2: IConfigManager;
  CrossMgr1, CrossMgr2: ICrossTargetManager;
  Target, ReadBack: TCrossTarget;
  TmpPath: string;
begin
  TmpPath := MakeTmpConfigPath;

  // Phase 1: Write
  Cfg1 := TConfigManager.Create(TmpPath);
  Cfg1.LoadConfig;
  CrossMgr1 := Cfg1.GetCrossTargetManager;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.BinutilsPath := '/cross/bin';
  Target.LibrariesPath := '/cross/lib';
  Target.CPU := 'mipsel';
  Target.OS := 'linux';
  Target.SubArch := '';
  Target.ABI := '';
  Target.BinutilsPrefix := 'mipsel-linux-gnu-';
  Target.CrossOpt := '-CfSOFT';
  CrossMgr1.AddCrossTarget('mipsel-linux', Target);
  Cfg1.SaveConfig;

  // Phase 2: Read back from fresh instance
  Cfg2 := TConfigManager.Create(TmpPath);
  Cfg2.LoadConfig;
  CrossMgr2 := Cfg2.GetCrossTargetManager;

  Check(CrossMgr2.GetCrossTarget('mipsel-linux', ReadBack), 'FullCycle: target found');
  Check(ReadBack.Enabled = True, 'FullCycle: Enabled');
  Check(ReadBack.BinutilsPath = '/cross/bin', 'FullCycle: BinutilsPath');
  Check(ReadBack.LibrariesPath = '/cross/lib', 'FullCycle: LibrariesPath');
  Check(ReadBack.CPU = 'mipsel', 'FullCycle: CPU');
  Check(ReadBack.OS = 'linux', 'FullCycle: OS');
  Check(ReadBack.BinutilsPrefix = 'mipsel-linux-gnu-', 'FullCycle: BinutilsPrefix');
  Check(ReadBack.CrossOpt = '-CfSOFT', 'FullCycle: CrossOpt');

  CleanupTmpConfigPath(TmpPath);
end;

{ === Tests: Update existing target preserves/overwrites fields === }

procedure TestUpdateTarget;
var
  Cfg: IConfigManager;
  CrossMgr: ICrossTargetManager;
  Target, ReadBack: TCrossTarget;
  TmpPath: string;
begin
  TmpPath := MakeTmpConfigPath;
  Cfg := TConfigManager.Create(TmpPath);
  Cfg.LoadConfig;
  CrossMgr := Cfg.GetCrossTargetManager;

  // Initial add
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := 'arm';
  Target.OS := 'linux';
  Target.ABI := 'eabi';
  CrossMgr.AddCrossTarget('arm-linux', Target);

  // Update with new values
  Target.ABI := 'eabihf';
  Target.SubArch := 'armv7';
  Target.CrossOpt := '-CaEABIHF';
  CrossMgr.AddCrossTarget('arm-linux', Target);

  Check(CrossMgr.GetCrossTarget('arm-linux', ReadBack), 'Update: target found');
  Check(ReadBack.ABI = 'eabihf', 'Update: ABI updated');
  Check(ReadBack.SubArch = 'armv7', 'Update: SubArch added');
  Check(ReadBack.CrossOpt = '-CaEABIHF', 'Update: CrossOpt added');
  CleanupTmpConfigPath(TmpPath);
end;

{ === Tests: Remove target === }

procedure TestRemoveTarget;
var
  Cfg: IConfigManager;
  CrossMgr: ICrossTargetManager;
  Target, ReadBack: TCrossTarget;
  TmpPath: string;
begin
  TmpPath := MakeTmpConfigPath;
  Cfg := TConfigManager.Create(TmpPath);
  Cfg.LoadConfig;
  CrossMgr := Cfg.GetCrossTargetManager;

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := 'arm';
  Target.OS := 'linux';
  CrossMgr.AddCrossTarget('arm-linux', Target);

  Check(CrossMgr.RemoveCrossTarget('arm-linux'), 'Remove: returns True');
  Check(not CrossMgr.GetCrossTarget('arm-linux', ReadBack), 'Remove: target gone');
  Check(Length(CrossMgr.ListCrossTargets) = 0, 'Remove: list empty');
  CleanupTmpConfigPath(TmpPath);
end;

begin
  WriteLn('=== Cross-Compilation Config Extended Fields Tests ===');
  WriteLn;

  TestExtendedFields_RoundTrip;
  TestBackwardCompat_OldFormatJSON;
  TestExtendedFields_SaveToJSON;
  TestEmptyFields_NotWritten;
  TestMultipleTargets;
  TestSaveReload_FullCycle;
  TestUpdateTarget;
  TestRemoveTarget;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
