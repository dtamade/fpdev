program test_project_test;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Process, test_temp_paths, fpdev.project.manager, fpdev.config;

var
  TempRootDir: string;
  TestProjectDir: string;
  FailingProjectDir: string;
  TestConfigPath: string;
  ConfigManager: TFPDevConfigManager;
  ProjectManager: TProjectManager;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('失败: ', AMessage);
    Halt(1);
  end;
end;

procedure AssertUsesSystemTemp(const APath, ALabel: string);
var
  ExpandedPath: string;
  TempPrefix: string;
begin
  ExpandedPath := ExpandFileName(APath);
  TempPrefix := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  AssertTrue(Pos(TempPrefix, ExpandedPath) = 1,
    ALabel + ' should live under system temp: ' + ExpandedPath);
end;

procedure SetupSuiteEnvironment;
begin
  TempRootDir := CreateUniqueTempDir('fpdev-project-test');
  TestConfigPath := IncludeTrailingPathDelimiter(TempRootDir) + 'config.json';
  AssertUsesSystemTemp(TempRootDir, 'suite temp root');
end;

procedure SetupTestEnvironment;
var
  TestProgram: TextFile;
  ExeName: string;
  P: TProcess;
  CompileExitCode: Integer;
begin
  // 创建临时测试项目目录
  TestProjectDir := IncludeTrailingPathDelimiter(TempRootDir) + 'project-pass';
  ForceDirectories(TestProjectDir);
  AssertUsesSystemTemp(TestProjectDir, 'passing project dir');

  // 创建一个简单的测试程序（模拟FPCUnit风格）
  AssignFile(TestProgram, TestProjectDir + PathDelim + 'test_example.lpr');
  Rewrite(TestProgram);
  WriteLn(TestProgram, 'program test_example;');
  WriteLn(TestProgram, '{$mode objfpc}{$H+}');
  WriteLn(TestProgram, 'uses SysUtils;');
  WriteLn(TestProgram, 'var');
  WriteLn(TestProgram, '  TestsPassed, TestsFailed: Integer;');
  WriteLn(TestProgram, 'begin');
  WriteLn(TestProgram, '  TestsPassed := 0;');
  WriteLn(TestProgram, '  TestsFailed := 0;');
  WriteLn(TestProgram, '  ');
  WriteLn(TestProgram, '  // 模拟测试执行');
  WriteLn(TestProgram, '  WriteLn(''Running tests...'');');
  WriteLn(TestProgram, '  WriteLn(''Test 1: PASS'');');
  WriteLn(TestProgram, '  Inc(TestsPassed);');
  WriteLn(TestProgram, '  WriteLn(''Test 2: PASS'');');
  WriteLn(TestProgram, '  Inc(TestsPassed);');
  WriteLn(TestProgram, '  ');
  WriteLn(TestProgram, '  WriteLn(''Tests passed: '', TestsPassed);');
  WriteLn(TestProgram, '  WriteLn(''Tests failed: '', TestsFailed);');
  WriteLn(TestProgram, '  ');
  WriteLn(TestProgram, '  if TestsFailed = 0 then');
  WriteLn(TestProgram, '    ExitCode := 0');
  WriteLn(TestProgram, '  else');
  WriteLn(TestProgram, '    ExitCode := 1;');
  WriteLn(TestProgram, 'end.');
  CloseFile(TestProgram);

  // 编译测试程序
  {$IFDEF MSWINDOWS}
  ExeName := TestProjectDir + PathDelim + 'test_example.exe';
  {$ELSE}
  ExeName := TestProjectDir + PathDelim + 'test_example';
  {$ENDIF}

  WriteLn('[Setup] 编译测试程序...');
  P := TProcess.Create(nil);
  try
    P.Executable := 'fpc';
    P.Parameters.Add('-o' + ExeName);
    P.Parameters.Add(TestProjectDir + PathDelim + 'test_example.lpr');
    P.Options := [poWaitOnExit];
    try
      P.Execute;
      CompileExitCode := P.ExitStatus;
    except
      on E: Exception do
      begin
        WriteLn('[Setup] 警告: 无法编译测试程序: ', E.Message);
        CompileExitCode := 1;
      end;
    end;
  finally
    P.Free;
  end;

  if CompileExitCode <> 0 then
  begin
    WriteLn('[Setup] 警告: 无法编译测试程序，某些测试将被跳过');
  end
  else
    WriteLn('[Setup] 测试程序编译成功: ', ExeName);
end;

procedure SetupFailingTestEnvironment;
var
  TestProgram: TextFile;
  ExeName: string;
  P: TProcess;
  CompileExitCode: Integer;
begin
  // 创建一个会失败的测试项目
  FailingProjectDir := IncludeTrailingPathDelimiter(TempRootDir) + 'project-fail';
  ForceDirectories(FailingProjectDir);
  AssertUsesSystemTemp(FailingProjectDir, 'failing project dir');

  AssignFile(TestProgram, FailingProjectDir + PathDelim + 'test_failing.lpr');
  Rewrite(TestProgram);
  WriteLn(TestProgram, 'program test_failing;');
  WriteLn(TestProgram, '{$mode objfpc}{$H+}');
  WriteLn(TestProgram, 'uses SysUtils;');
  WriteLn(TestProgram, 'begin');
  WriteLn(TestProgram, '  WriteLn(''Running tests...'');');
  WriteLn(TestProgram, '  WriteLn(''Test 1: FAIL'');');
  WriteLn(TestProgram, '  ExitCode := 1;  // 模拟测试失败');
  WriteLn(TestProgram, 'end.');
  CloseFile(TestProgram);

  {$IFDEF MSWINDOWS}
  ExeName := FailingProjectDir + PathDelim + 'test_failing.exe';
  {$ELSE}
  ExeName := FailingProjectDir + PathDelim + 'test_failing';
  {$ENDIF}

  P := TProcess.Create(nil);
  try
    P.Executable := 'fpc';
    P.Parameters.Add('-o' + ExeName);
    P.Parameters.Add(FailingProjectDir + PathDelim + 'test_failing.lpr');
    P.Options := [poWaitOnExit];
    try
      P.Execute;
      CompileExitCode := P.ExitStatus;
    except
      on E: Exception do
        CompileExitCode := 1;
    end;
  finally
    P.Free;
  end;

  if CompileExitCode = 0 then
    WriteLn('[Setup] 失败测试程序编译成功: ', ExeName);
end;

procedure TeardownTestEnvironment;
begin
  if (TempRootDir <> '') and DirectoryExists(TempRootDir) then
  begin
    CleanupTempDir(TempRootDir);
    WriteLn('[Teardown] 已删除测试目录: ', TempRootDir);
    TempRootDir := '';
  end;
end;

procedure TestRunTestsSuccessfully;
var
  Success: Boolean;
  ExeName: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('测试: TestProject 成功执行测试');
  WriteLn('==================================================');

  {$IFDEF MSWINDOWS}
  ExeName := TestProjectDir + PathDelim + 'test_example.exe';
  {$ELSE}
  ExeName := TestProjectDir + PathDelim + 'test_example';
  {$ENDIF}

  // 如果可执行文件不存在则跳过测试
  if not FileExists(ExeName) then
  begin
    WriteLn('跳过: 测试可执行文件不可用');
    Exit;
  end;

  // 执行测试
  Success := ProjectManager.TestProject(TestProjectDir);

  if not Success then
  begin
    WriteLn('失败: TestProject 返回 False');
    Halt(1);
  end;

  WriteLn('通过: 测试成功执行');
end;

procedure TestHandleFailingTests;
var
  Success: Boolean;
  ExeName: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('测试: TestProject 处理失败的测试');
  WriteLn('==================================================');

  // 设置失败测试环境
  SetupFailingTestEnvironment;

  {$IFDEF MSWINDOWS}
  ExeName := FailingProjectDir + PathDelim + 'test_failing.exe';
  {$ELSE}
  ExeName := FailingProjectDir + PathDelim + 'test_failing';
  {$ENDIF}

  if not FileExists(ExeName) then
  begin
    WriteLn('跳过: 失败测试可执行文件不可用');
    Exit;
  end;

  // 执行测试（应该失败）
  Success := ProjectManager.TestProject(FailingProjectDir);

  if Success then
  begin
    WriteLn('失败: TestProject 应该对失败的测试返回 False');
    Halt(1);
  end;

  WriteLn('通过: 正确处理失败的测试');
end;

procedure TestHandleNonExistentDirectory;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('测试: TestProject 处理不存在的目录');
  WriteLn('==================================================');

  // 在不存在的目录上执行测试
  Success := ProjectManager.TestProject('non_existent_test_dir_98765');

  if Success then
  begin
    WriteLn('失败: TestProject 对不存在的目录应返回 False');
    Halt(1);
  end;

  WriteLn('通过: 正确处理不存在的目录');
end;

procedure TestHandleNoTestExecutable;
var
  EmptyDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('测试: TestProject 处理没有测试可执行文件的目录');
  WriteLn('==================================================');

  // 创建空目录
  EmptyDir := IncludeTrailingPathDelimiter(TempRootDir) + 'project-empty';
  ForceDirectories(EmptyDir);
  AssertUsesSystemTemp(EmptyDir, 'empty project dir');

  try
    // 执行测试
    Success := ProjectManager.TestProject(EmptyDir);

    if Success then
    begin
      WriteLn('失败: TestProject 在找不到测试文件时应返回 False');
      Halt(1);
    end;

    WriteLn('通过: 正确处理缺少测试可执行文件的情况');
  finally
    RemoveDir(EmptyDir);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  项目测试功能测试套件');
  WriteLn('========================================');
  WriteLn;

  try
    SetupSuiteEnvironment;
    // 初始化管理器
    ConfigManager := TFPDevConfigManager.Create(TestConfigPath);
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      ProjectManager := TProjectManager.Create(ConfigManager);
      try
        // 设置测试环境
        SetupTestEnvironment;
        try
          // 测试1: 成功运行测试
          TestRunTestsSuccessfully;

          // 测试2: 处理失败的测试
          TestHandleFailingTests;

          // 测试3: 处理不存在的目录
          TestHandleNonExistentDirectory;

          // 测试4: 处理缺少测试可执行文件
          TestHandleNoTestExecutable;

          WriteLn;
          WriteLn('========================================');
          WriteLn('  所有测试通过');
          WriteLn('========================================');
          ExitCode := 0;

        finally
          TeardownTestEnvironment;
        end;
      finally
        ProjectManager.Free;
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
