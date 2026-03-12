program test_project_management;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, Classes,
  fpdev.config, test_temp_paths;

type
  { TProjectManagementTest }
  TProjectManagementTest = class
  private
    FTestConfigPath: string;
    FConfigManager: TFPDevConfigManager;
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    
    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure RunAllTests;
    
    // 测试方法
    procedure TestProjectConfigurationCreation;
    procedure TestProjectTemplateManagement;
    procedure TestProjectCreationFramework;
    procedure TestProjectCommandInterface;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TProjectManagementTest }

constructor TProjectManagementTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  FTestConfigPath := CreateUniqueTempDir('test_project_management')
    + PathDelim + 'test_project_config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TProjectManagementTest.Destroy;
begin
  FConfigManager.Free;
  if FTestConfigPath <> '' then
    CleanupTempDir(ExtractFileDir(FTestConfigPath));
  FTestConfigPath := '';
  inherited Destroy;
end;

procedure TProjectManagementTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(FTestsPassed);
    WriteLn('✓ PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('✗ FAIL: ', AMessage);
  end;
end;

procedure TProjectManagementTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TProjectManagementTest.RunAllTests;
begin
  WriteLn('=== Project Management Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  TestProjectConfigurationCreation;
  TestProjectTemplateManagement;
  TestProjectCreationFramework;
  TestProjectCommandInterface;
  
  WriteLn;
  WriteLn('=== Test Results ===');
  WriteLn('Tests Passed: ', FTestsPassed);
  WriteLn('Tests Failed: ', FTestsFailed);
  WriteLn('Total Tests: ', FTestsPassed + FTestsFailed);
  
  if FTestsFailed = 0 then
    WriteLn('✓ All tests passed!')
  else
    WriteLn('✗ Some tests failed!');
end;

procedure TProjectManagementTest.TestProjectConfigurationCreation;
begin
  WriteLn('--- Testing Project Configuration Creation ---');
  
  try
    // 创建配置管理器
    AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
    AssertTrue(FileExists(FTestConfigPath), 'Config file should exist after creation');
    
    // 测试加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should load config successfully');
    
    WriteLn('✓ Project configuration creation and loading successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during configuration creation: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TProjectManagementTest.TestProjectTemplateManagement;
var
  Settings: TFPDevSettings;
begin
  WriteLn('--- Testing Project Template Management ---');
  
  try
    // 测试设置项目模板根目录
    FillChar(Settings, SizeOf(Settings), 0);
    Settings.InstallRoot := '/test/fpdev/templates';
    Settings.AutoUpdate := True;
    Settings.ParallelJobs := 4;
    Settings.KeepSources := False;
    
    AssertTrue(FConfigManager.SetSettings(Settings), 'Should set template settings');
    
    // 验证设置
    Settings := FConfigManager.GetSettings;
    AssertEquals('/test/fpdev/templates', Settings.InstallRoot, 'Template root should match');
    AssertTrue(Settings.AutoUpdate = True, 'AutoUpdate should be enabled');
    AssertTrue(Settings.ParallelJobs = 4, 'ParallelJobs should match');
    AssertTrue(Settings.KeepSources = False, 'KeepSources should be disabled');
    
    WriteLn('✓ Project template management successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during template management: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TProjectManagementTest.TestProjectCreationFramework;
begin
  WriteLn('--- Testing Project Creation Framework ---');
  
  try
    // 测试项目创建框架的基础配置
    // 由于项目创建涉及文件系统操作，这里主要测试配置部分
    
    // 测试添加项目仓库
    AssertTrue(FConfigManager.AddRepository('project_templates', 'https://github.com/freepascal/templates.git'), 'Should add project template repository');
    AssertEquals('https://github.com/freepascal/templates.git', FConfigManager.GetRepository('project_templates'), 'Project template repository URL should match');
    
    WriteLn('✓ Project creation framework successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during creation framework test: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TProjectManagementTest.TestProjectCommandInterface;
var
  Settings: TFPDevSettings;
begin
  WriteLn('--- Testing Project Command Interface ---');
  
  try
    // 测试配置保存和加载
    AssertTrue(FConfigManager.SaveConfig, 'Should save configuration');
    
    // 重新加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should reload configuration');
    
    // 验证数据完整性
    AssertEquals('https://github.com/freepascal/templates.git', FConfigManager.GetRepository('project_templates'), 'Project template repository should persist');
    
    Settings := FConfigManager.GetSettings;
    AssertEquals('/test/fpdev/templates', Settings.InstallRoot, 'Template root should persist');
    
    WriteLn('✓ Project command interface successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during command interface test: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

// 全局测试函数
procedure RunProjectManagementTests;
var
  Test: TProjectManagementTest;
begin
  Test := TProjectManagementTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

begin
  try
    WriteLn('Project Management Test Suite');
    WriteLn('=============================');
    WriteLn;
    
    RunProjectManagementTests;
    
    WriteLn;
    WriteLn('Test suite completed.');
    
  except
    on E: Exception do
    begin
      WriteLn('Error running tests: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  PauseIfRequested('Press Enter to continue...');
end.
