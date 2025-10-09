program test_fpc_clean;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.cmd.fpc, fpdev.config;

var
  TestInstallRoot: string;
  TestSourceDir: string;
  ConfigManager: TFPDevConfigManager;
  FPCManager: TFPCManager;

procedure SetupTestEnvironment;
var
  TestFile: TextFile;
  BuildDir: string;
  Settings: TFPDevSettings;
begin
  // 创建临时安装根目录
  TestInstallRoot := 'test_install_root_' + IntToStr(GetTickCount64);
  ForceDirectories(TestInstallRoot);

  // 设置配置管理器使用测试目录
  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  ConfigManager.SetSettings(Settings);

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
  {$ELSE}
  AssignFile(TestFile, BuildDir + PathDelim + 'ppc386');
  {$ENDIF}
  Rewrite(TestFile);
  WriteLn(TestFile, 'dummy executable');
  CloseFile(TestFile);

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

  WriteLn('[Setup] 已创建测试FPC源码目录: ', TestSourceDir);
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
    WriteLn('[Teardown] 已删除测试目录: ', TestInstallRoot);
  end;
end;

procedure TestCleanRemovesBuildArtifacts;
var
  Success: Boolean;
  CompilerDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('测试: CleanSources 删除编译产物');
  WriteLn('==================================================');

  CompilerDir := TestSourceDir + PathDelim + 'compiler';

  // 执行清理
  Success := FPCManager.CleanSources('test');

  if not Success then
  begin
    WriteLn('失败: CleanSources 返回 False');
    Halt(1);
  end;

  // 断言：编译产物应该被删除
  if FileExists(CompilerDir + PathDelim + 'ppc386.o') then
  begin
    WriteLn('失败: Object文件 ppc386.o 未被删除');
    Halt(1);
  end;

  if FileExists(CompilerDir + PathDelim + 'system.ppu') then
  begin
    WriteLn('失败: Unit文件 system.ppu 未被删除');
    Halt(1);
  end;

  {$IFDEF MSWINDOWS}
  if FileExists(CompilerDir + PathDelim + 'ppc386.exe') then
  begin
    WriteLn('失败: 可执行文件 ppc386.exe 未被删除');
    Halt(1);
  end;
  {$ELSE}
  if FileExists(CompilerDir + PathDelim + 'ppc386') then
  begin
    WriteLn('失败: 可执行文件 ppc386 未被删除');
    Halt(1);
  end;
  {$ENDIF}

  // 断言：源代码文件应该被保留
  if not FileExists(CompilerDir + PathDelim + 'compiler.pas') then
  begin
    WriteLn('失败: 源代码文件 compiler.pas 被删除了（应该保留）');
    Halt(1);
  end;

  if not FileExists(TestSourceDir + PathDelim + 'Makefile') then
  begin
    WriteLn('失败: Makefile 被删除了（应该保留）');
    Halt(1);
  end;

  WriteLn('通过: 编译产物已删除，源代码已保留');
end;

procedure TestCleanNonExistentDirectory;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('测试: CleanSources 处理不存在的目录');
  WriteLn('==================================================');

  // 在不存在的版本上执行清理
  Success := FPCManager.CleanSources('nonexistent-version-999');

  if Success then
  begin
    WriteLn('失败: CleanSources 对不存在的版本应返回 False');
    Halt(1);
  end;

  WriteLn('通过: 正确处理不存在的版本');
end;

procedure TestCleanEmptyDirectory;
var
  EmptySourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('测试: CleanSources 处理空目录');
  WriteLn('==================================================');

  // 创建空的源码目录（在正确的位置）
  EmptySourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-empty';
  ForceDirectories(EmptySourceDir);

  try
    // 执行清理
    Success := FPCManager.CleanSources('empty');

    if not Success then
    begin
      WriteLn('失败: CleanSources 对空目录应返回 True');
      Halt(1);
    end;

    // 目录应该仍然存在
    if not DirectoryExists(EmptySourceDir) then
    begin
      WriteLn('失败: CleanSources 不应该删除目录本身');
      Halt(1);
    end;

    WriteLn('通过: 正确处理空目录');
  finally
    RemoveDir(EmptySourceDir);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  FPC清理功能测试套件');
  WriteLn('========================================');
  WriteLn;

  try
    // 初始化配置管理器
    ConfigManager := TFPDevConfigManager.Create;
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      // 设置测试环境（在创建FPCManager之前）
      SetupTestEnvironment;
      try
        // 创建FPC管理器（会使用更新后的配置）
        FPCManager := TFPCManager.Create(ConfigManager);
        try
          // 测试1: 清理编译产物
          TestCleanRemovesBuildArtifacts;

          // 测试2: 处理不存在的目录
          TestCleanNonExistentDirectory;

          // 测试3: 处理空目录
          TestCleanEmptyDirectory;

          WriteLn;
          WriteLn('========================================');
          WriteLn('  所有测试通过');
          WriteLn('========================================');
          ExitCode := 0;

        finally
          FPCManager.Free;
        end;
      finally
        TeardownTestEnvironment;
      end;
    finally
      ConfigManager.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  测试套件失败');
      WriteLn('========================================');
      WriteLn('异常: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
