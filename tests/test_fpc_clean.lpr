program test_fpc_clean;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.cmd.fpc, fpdev.config.interfaces, fpdev.config.managers
  {$IFDEF UNIX}
  , BaseUnix
  {$ENDIF};

var
  TestInstallRoot: string;
  TestSourceDir: string;
  ConfigManager: IConfigManager;
  FPCManager: TFPCManager;

procedure SetupTestEnvironment;
var
  TestFile: TextFile;
  BuildDir: string;
  Settings: TFPDevSettings;
  SettingsMgr: ISettingsManager;
begin
  // 创建临时安装根目录
  TestInstallRoot := 'test_install_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

  // 设置配置管理器使用测试目录
  SettingsMgr := ConfigManager.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  SettingsMgr.SetSettings(Settings);

  // 创建FPC源码目录结构: InstallRoot/sources/fpc/fpc-test
  TestSourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-test';
  ForceDirectories(TestSourceDir);

  // 创建模拟的FPC源码结构
  ForceDirectories(TestSourceDir + PathDelim + 'compiler');
  ForceDirectories(TestSourceDir + PathDelim + 'rtl');
  ForceDirectories(TestSourceDir + PathDelim + 'packages');

  BuildDir := TestSourceDir + PathDelim + 'compiler';

  // 创建编译产物（应该被清理）
  AssignFile(TestFile, BuildDir + PathDelim + 'ppc386.o');
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy object file');
  CloseFile(TestFile);

  AssignFile(TestFile, BuildDir + PathDelim + 'system.ppu');
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy unit file');
  CloseFile(TestFile);

  {$IFDEF MSWINDOWS}
  AssignFile(TestFile, BuildDir + PathDelim + 'ppc386.exe');
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy executable');
  CloseFile(TestFile);
  {$ELSE}
  AssignFile(TestFile, BuildDir + PathDelim + 'ppc386');
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy executable');
  CloseFile(TestFile);
  // Set execute permission on Unix
  FpChmod(BuildDir + PathDelim + 'ppc386', &755);
  {$ENDIF}

  // 创建源代码文件（不应该被清理）
  AssignFile(TestFile, BuildDir + PathDelim + 'compiler.pas');
  Rewrite(TestFile);
  WriteLn(TestFile, 'program compiler; begin end.');
  CloseFile(TestFile);

  AssignFile(TestFile, TestSourceDir + PathDelim + 'Makefile');
  Rewrite(TestFile);
  WriteLn(TestFile, 'all:');
  WriteLn(TestFile, #9'@echo "Building FPC"');
  CloseFile(TestFile);

  WriteLn('[Setup] Created test FPC source directory: ', TestSourceDir);
end;

procedure TeardownTestEnvironment;
var
  SR: TSearchRec;
  FilePath: string;

  procedure DeleteDirectory(const DirPath: string);
  var
    SR2: TSearchRec;
    FilePath2: string;
  begin
    if not DirectoryExists(DirPath) then Exit;

    if FindFirst(DirPath + PathDelim + '*', faAnyFile, SR2) = 0 then
    begin
      repeat
        if (SR2.Name <> '.') and (SR2.Name <> '..') then
        begin
          FilePath2 := DirPath + PathDelim + SR2.Name;
          if (SR2.Attr and faDirectory) <> 0 then
            DeleteDirectory(FilePath2)
          else
            DeleteFile(FilePath2);
        end;
      until FindNext(SR2) <> 0;
      FindClose(SR2);
    end;
    RemoveDir(DirPath);
  end;

begin
  // 清理测试安装根目录（包含所有子目录）
  if DirectoryExists(TestInstallRoot) then
  begin
    DeleteDirectory(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
  end;
end;

procedure TestCleanRemovesBuildArtifacts;
var
  Success: Boolean;
  CompilerDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources removes build artifacts');
  WriteLn('==================================================');

  CompilerDir := TestSourceDir + PathDelim + 'compiler';

  // 执行清理
  Success := FPCManager.CleanSources('test');

  if not Success then
  begin
    WriteLn('FAIL: CleanSources returned False');
    Halt(1);
  end;

  // Assert: build artifacts should be deleted
  if FileExists(CompilerDir + PathDelim + 'ppc386.o') then
  begin
    WriteLn('FAIL: Object file ppc386.o was not deleted');
    Halt(1);
  end;

  if FileExists(CompilerDir + PathDelim + 'system.ppu') then
  begin
    WriteLn('FAIL: Unit file system.ppu was not deleted');
    Halt(1);
  end;

  {$IFDEF MSWINDOWS}
  if FileExists(CompilerDir + PathDelim + 'ppc386.exe') then
  begin
    WriteLn('FAIL: Executable ppc386.exe was not deleted');
    Halt(1);
  end;
  {$ELSE}
  if FileExists(CompilerDir + PathDelim + 'ppc386') then
  begin
    WriteLn('FAIL: Executable ppc386 was not deleted');
    Halt(1);
  end;
  {$ENDIF}

  // Assert: source files should be preserved
  if not FileExists(CompilerDir + PathDelim + 'compiler.pas') then
  begin
    WriteLn('FAIL: Source file compiler.pas was deleted (should be preserved)');
    Halt(1);
  end;

  if not FileExists(TestSourceDir + PathDelim + 'Makefile') then
  begin
    WriteLn('FAIL: Makefile was deleted (should be preserved)');
    Halt(1);
  end;

  WriteLn('PASS: Build artifacts deleted, source files preserved');
end;

procedure TestCleanNonExistentDirectory;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources handles non-existent directory');
  WriteLn('==================================================');

  // Execute clean on non-existent version
  Success := FPCManager.CleanSources('nonexistent-version-999');

  if Success then
  begin
    WriteLn('FAIL: CleanSources should return False for non-existent version');
    Halt(1);
  end;

  WriteLn('PASS: Correctly handles non-existent version');
end;

procedure TestCleanEmptyDirectory;
var
  EmptySourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources handles empty directory');
  WriteLn('==================================================');

  // Create empty source directory (in correct location)
  EmptySourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-empty';
  ForceDirectories(EmptySourceDir);

  try
    // Execute clean
    Success := FPCManager.CleanSources('empty');

    if not Success then
    begin
      WriteLn('FAIL: CleanSources should return True for empty directory');
      Halt(1);
    end;

    // Directory should still exist
    if not DirectoryExists(EmptySourceDir) then
    begin
      WriteLn('FAIL: CleanSources should not delete the directory itself');
      Halt(1);
    end;

    WriteLn('PASS: Correctly handles empty directory');
  finally
    RemoveDir(EmptySourceDir);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  FPC Clean Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize config manager
    ConfigManager := TConfigManager.Create('');
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;

    // Setup test environment (before creating FPCManager)
    SetupTestEnvironment;
    try
      // Create FPC manager (will use updated config)
      FPCManager := TFPCManager.Create(ConfigManager);
      try
        // Test 1: Clean build artifacts
        TestCleanRemovesBuildArtifacts;

        // Test 2: Handle non-existent directory
        TestCleanNonExistentDirectory;

        // Test 3: Handle empty directory
        TestCleanEmptyDirectory;

        WriteLn;
        WriteLn('========================================');
        WriteLn('  All tests passed');
        WriteLn('========================================');
        ExitCode := 0;

      finally
        FPCManager.Free;
      end;
    finally
      TeardownTestEnvironment;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite failed');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
