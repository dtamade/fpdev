unit fpdev.config.test;
// acq:allow-hardcoded-constants-file

{$codepage utf8}

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.config.test

Configuration management system test unit


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config;

type
  { TFPDevConfigTest }
  TFPDevConfigTest = class
  private
    FTestConfigPath: string;
    FConfigManager: TFPDevConfigManager;
    FTestsPassed: Integer;
    FTestsFailed: Integer;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: Boolean; const AMessage: string);

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods
    procedure TestCreateDefaultConfig;
    procedure TestLoadSaveConfig;
    procedure TestToolchainManagement;
    procedure TestLazarusManagement;
    procedure TestCrossTargetManagement;
    procedure TestRepositoryManagement;
    procedure TestSettingsManagement;

    // Properties
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

// Global test function
procedure RunConfigTests;

implementation

{ TFPDevConfigTest }

constructor TFPDevConfigTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  // Create temporary test config file path
  FTestConfigPath := 'fpdev_test_config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TFPDevConfigTest.Destroy;
begin
  // Clean up test files
  if FileExists(FTestConfigPath) then
    DeleteFile(FTestConfigPath);

  FConfigManager.Free;
  inherited Destroy;
end;

procedure TFPDevConfigTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(FTestsPassed);
  // WriteLn('[OK] PASS: ', AMessage);  // debug code commented out
  end
  else
  begin
    Inc(FTestsFailed);
  // WriteLn('[FAIL] FAIL: ', AMessage);  // debug code commented out
  end;
end;

procedure TFPDevConfigTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TFPDevConfigTest.AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(
    AExpected = AActual,
    AMessage + ' (Expected: ' + IntToStr(AExpected) +
      ', Actual: ' + IntToStr(AActual) + ')'
  );
end;

procedure TFPDevConfigTest.AssertEquals(const AExpected, AActual: Boolean; const AMessage: string);
begin
  AssertTrue(
    AExpected = AActual,
    AMessage + ' (Expected: ' + BoolToStr(AExpected, True) +
      ', Actual: ' + BoolToStr(AActual, True) + ')'
  );
end;

procedure TFPDevConfigTest.RunAllTests;
begin
  // WriteLn('=== FPDev Configuration Management Tests ===');  // debug code commented out
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestCreateDefaultConfig;
  TestLoadSaveConfig;
  TestToolchainManagement;
  TestLazarusManagement;
  TestCrossTargetManagement;
  TestRepositoryManagement;
  TestSettingsManagement;

  WriteLn;
  // WriteLn('=== Test Results ===');  // debug code commented out
  // WriteLn('Tests Passed: ', FTestsPassed);  // debug code commented out
  // WriteLn('Tests Failed: ', FTestsFailed);  // debug code commented out
  // WriteLn('Total Tests: ', FTestsPassed + FTestsFailed);  // debug code commented out

  if FTestsFailed = 0 then
  // WriteLn('[OK] All tests passed!')  // debug code commented out
  else
  // WriteLn('[FAIL] Some tests failed!');  // debug code commented out
end;

procedure TFPDevConfigTest.TestCreateDefaultConfig;
begin
  // WriteLn('--- Testing Default Config Creation ---');  // debug code commented out

  // Ensure test file does not exist
  if FileExists(FTestConfigPath) then
    DeleteFile(FTestConfigPath);

  AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
  AssertTrue(FileExists(FTestConfigPath), 'Config file should exist after creation');

  WriteLn;
end;

procedure TFPDevConfigTest.TestLoadSaveConfig;
begin
  // WriteLn('--- Testing Load/Save Config ---');  // debug code commented out

  // Create default config
  AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');

  // Test loading
  AssertTrue(FConfigManager.LoadConfig, 'Should load config successfully');

  // Test saving
  AssertTrue(FConfigManager.SaveConfig, 'Should save config successfully');

  WriteLn;
end;

procedure TFPDevConfigTest.TestToolchainManagement;
var
  ToolchainInfo: TToolchainInfo;
  Toolchains: TStringArray;
begin
  // WriteLn('--- Testing Toolchain Management ---');  // debug code commented out

  // Prepare test data
  FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
  ToolchainInfo.ToolchainType := ttRelease;
  ToolchainInfo.Version := '3.2.2';
  ToolchainInfo.InstallPath := '/test/fpc/3.2.2';
  ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
  ToolchainInfo.Branch := 'fixes_3_2';
  ToolchainInfo.Installed := True;
  ToolchainInfo.InstallDate := Now;

  // Test adding toolchain
  AssertTrue(FConfigManager.AddToolchain('fpc-3.2.2', ToolchainInfo), 'Should add toolchain');

  // Test getting toolchain
  FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
  AssertTrue(FConfigManager.GetToolchain('fpc-3.2.2', ToolchainInfo), 'Should get toolchain');
  AssertEquals('3.2.2', ToolchainInfo.Version, 'Toolchain version should match');

  // Test setting default toolchain
  AssertTrue(FConfigManager.SetDefaultToolchain('fpc-3.2.2'), 'Should set default toolchain');
  AssertEquals('fpc-3.2.2', FConfigManager.GetDefaultToolchain, 'Default toolchain should match');

  // Test listing toolchains
  Toolchains := FConfigManager.ListToolchains;
  AssertTrue(Length(Toolchains) > 0, 'Should have at least one toolchain');

  // Test removing toolchain
  AssertTrue(FConfigManager.RemoveToolchain('fpc-3.2.2'), 'Should remove toolchain');
  AssertTrue(not FConfigManager.GetToolchain('fpc-3.2.2', ToolchainInfo), 'Toolchain should not exist after removal');

  WriteLn;
end;

procedure TFPDevConfigTest.TestLazarusManagement;
var
  LazarusInfo: TLazarusInfo;
  Versions: TStringArray;
begin
  // WriteLn('--- Testing Lazarus Management ---');  // debug code commented out

  // Prepare test data
  FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
  LazarusInfo.Version := '3.0';
  LazarusInfo.FPCVersion := 'fpc-3.2.2';
  LazarusInfo.InstallPath := '/test/lazarus/3.0';
  LazarusInfo.SourceURL := 'https://gitlab.com/freepascal.org/lazarus.git';
  LazarusInfo.Branch := 'lazarus_3_0';
  LazarusInfo.Installed := True;

  // Test adding Lazarus version
  AssertTrue(FConfigManager.AddLazarusVersion('lazarus-3.0', LazarusInfo), 'Should add Lazarus version');

  // Test getting Lazarus version
  FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
  AssertTrue(FConfigManager.GetLazarusVersion('lazarus-3.0', LazarusInfo), 'Should get Lazarus version');
  AssertEquals('3.0', LazarusInfo.Version, 'Lazarus version should match');

  // Test setting default Lazarus version
  AssertTrue(FConfigManager.SetDefaultLazarusVersion('lazarus-3.0'), 'Should set default Lazarus version');
  AssertEquals('lazarus-3.0', FConfigManager.GetDefaultLazarusVersion, 'Default Lazarus version should match');

  // Test listing Lazarus versions
  Versions := FConfigManager.ListLazarusVersions;
  AssertTrue(Length(Versions) > 0, 'Should have at least one Lazarus version');

  // Test removing Lazarus version
  AssertTrue(FConfigManager.RemoveLazarusVersion('lazarus-3.0'), 'Should remove Lazarus version');
  AssertTrue(
    not FConfigManager.GetLazarusVersion('lazarus-3.0', LazarusInfo),
    'Lazarus version should not exist after removal'
  );

  WriteLn;
end;

procedure TFPDevConfigTest.TestCrossTargetManagement;
var
  CrossTarget: TCrossTarget;
  Targets: TStringArray;
begin
  // WriteLn('--- Testing Cross Target Management ---');  // debug code commented out

  // Prepare test data
  FillChar(CrossTarget, SizeOf(CrossTarget), 0);
  CrossTarget.Enabled := True;
  CrossTarget.BinutilsPath := '/test/binutils/win64';
  CrossTarget.LibrariesPath := '/test/libs/win64';

  // Test adding cross-compilation target
  AssertTrue(FConfigManager.AddCrossTarget('win64', CrossTarget), 'Should add cross target');

  // Test getting cross-compilation target
  FillChar(CrossTarget, SizeOf(CrossTarget), 0);
  AssertTrue(FConfigManager.GetCrossTarget('win64', CrossTarget), 'Should get cross target');
  AssertEquals(True, CrossTarget.Enabled, 'Cross target should be enabled');

  // Test listing cross-compilation targets
  Targets := FConfigManager.ListCrossTargets;
  AssertTrue(Length(Targets) > 0, 'Should have at least one cross target');

  // Test removing cross-compilation target
  AssertTrue(FConfigManager.RemoveCrossTarget('win64'), 'Should remove cross target');
  AssertTrue(not FConfigManager.GetCrossTarget('win64', CrossTarget), 'Cross target should not exist after removal');

  WriteLn;
end;

procedure TFPDevConfigTest.TestRepositoryManagement;
var
  Repositories: TStringArray;
begin
  // WriteLn('--- Testing Repository Management ---');  // debug code commented out

  // Test adding repository
  AssertTrue(FConfigManager.AddRepository('test_repo', 'https://example.com/test.git'), 'Should add repository');

  // Test getting repository
  AssertEquals(
    'https://example.com/test.git',
    FConfigManager.GetRepository('test_repo'),
    'Repository URL should match'
  );

  // Test listing repositories
  Repositories := FConfigManager.ListRepositories;
  AssertTrue(Length(Repositories) > 0, 'Should have at least one repository');

  // Test removing repository
  AssertTrue(FConfigManager.RemoveRepository('test_repo'), 'Should remove repository');
  AssertEquals('', FConfigManager.GetRepository('test_repo'), 'Repository should not exist after removal');

  WriteLn;
end;

procedure TFPDevConfigTest.TestSettingsManagement;
var
  Settings: TFPDevSettings;
begin
  // WriteLn('--- Testing Settings Management ---');  // debug code commented out

  // Prepare test data
  FillChar(Settings, SizeOf(Settings), 0);
  Settings.AutoUpdate := True;
  Settings.ParallelJobs := 8;
  Settings.KeepSources := False;
  Settings.InstallRoot := '/test/fpdev';

  // Test setting configuration
  AssertTrue(FConfigManager.SetSettings(Settings), 'Should set settings');

  // Test getting configuration
  Settings := FConfigManager.GetSettings;
  AssertEquals(True, Settings.AutoUpdate, 'AutoUpdate should match');
  AssertEquals(8, Settings.ParallelJobs, 'ParallelJobs should match');
  AssertEquals(False, Settings.KeepSources, 'KeepSources should match');
  AssertEquals('/test/fpdev', Settings.InstallRoot, 'InstallRoot should match');

  WriteLn;
end;

// Global test function
procedure RunConfigTests;
var
  Test: TFPDevConfigTest;
begin
  Test := TFPDevConfigTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

end.
