program test_repo_commands;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config,
  fpdev.cmd.repo.add,
  fpdev.cmd.repo.list,
  fpdev.cmd.repo.default,
  fpdev.cmd.repo.remove,
  fpdev.command.intf,
  fpdev.command.context;

const
  // Test data constants
  TEST_REPO_NAME = 'test-repo';
  TEST_REPO_NAME1 = 'test-repo1';
  TEST_REPO_NAME2 = 'test-repo2';
  TEST_REPO_URL = 'https://example.com/test.git';
  TEST_REPO_URL1 = 'https://example.com/test1.git';
  TEST_REPO_URL2 = 'https://example.com/test2.git';
  
  // Test output prefixes
  PREFIX_TEST = '[TEST]';
  PREFIX_PASS = 'PASS:';
  PREFIX_FAIL = 'FAIL:';

type
  { 简单的测试上下文实现 }
  TTestContext = class(TInterfacedObject, ICommandContext)
  private
    FConfig: TFPDevConfigManager;
  public
    constructor Create;
    destructor Destroy; override;
    function Config: TFPDevConfigManager;
    procedure SaveIfModified;
  end;

constructor TTestContext.Create;
begin
  inherited Create;
  // 使用当前目录的临时文件，但不加载也不保存
  FConfig := TFPDevConfigManager.Create('test_config_temp.json');
  // 不加载配置文件，直接使用默认配置
end;

destructor TTestContext.Destroy;
begin
  // 不保存配置，避免文件系统操作
  if Assigned(FConfig) then
    FConfig.Free;
  inherited Destroy;
end;

function TTestContext.Config: TFPDevConfigManager;
begin
  Result := FConfig;
end;

procedure TTestContext.SaveIfModified;
begin
  // No actual file save in test environment
  WriteLn('TEST: SaveIfModified called');
end;

{ Helper procedures }
procedure AssertTrue(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    WriteLn(PREFIX_FAIL, ' ', Msg);
    Halt(1);
  end;
end;

procedure AssertEquals(const Expected, Actual: string; const Msg: string);
begin
  if Expected <> Actual then
  begin
    WriteLn(PREFIX_FAIL, ' ', Msg);
    WriteLn('  Expected: ', Expected);
    WriteLn('  Actual:   ', Actual);
    Halt(1);
  end;
end;

procedure RunTest(const TestName: string; TestProc: TProcedure);
begin
  WriteLn(PREFIX_TEST, ' ', TestName);
  try
    TestProc();
    WriteLn(PREFIX_PASS, ' ', TestName);
  except
    on E: Exception do
    begin
      WriteLn(PREFIX_FAIL, ' ', TestName, ' - ', E.Message);
      Halt(1);
    end;
  end;
end;

{ Test 1: repo.add - add new repository should succeed }
procedure TestRepoAdd;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  Cmd := TRepoAddCommand.Create;
  Ctx := TTestContext.Create;
  
  SetLength(Params, 2);
  Params[0] := TEST_REPO_NAME;
  Params[1] := TEST_REPO_URL;
  
  Cmd.Execute(Params, Ctx);
  
  AssertTrue(Ctx.Config.HasRepository(TEST_REPO_NAME), 
    'Repository not added to config');
  AssertEquals(TEST_REPO_URL, Ctx.Config.GetRepository(TEST_REPO_NAME),
    'Repository URL is incorrect');
end;

{ Test 2: repo.add - empty parameters should not crash }
procedure TestRepoAddEmptyParams;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  Cmd := TRepoAddCommand.Create;
  Ctx := TTestContext.Create;
  SetLength(Params, 0);
  
  // Should not crash with empty params
  Cmd.Execute(Params, Ctx);
end;

{ Test 3: repo.list - list all repositories }
procedure TestRepoList;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  Cmd := TRepoListCommand.Create;
  Ctx := TTestContext.Create;
  
  // Setup: Add test repositories
  Ctx.Config.AddRepository(TEST_REPO_NAME1, TEST_REPO_URL1);
  Ctx.Config.AddRepository(TEST_REPO_NAME2, TEST_REPO_URL2);
  
  SetLength(Params, 0);
  
  // Should list repos without crash
  Cmd.Execute(Params, Ctx);
end;

{ Test 4: repo.default - set default repository }
procedure TestRepoDefault;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  Cmd := TRepoDefaultCommand.Create;
  Ctx := TTestContext.Create;
  
  // Setup: Add test repository
  Ctx.Config.AddRepository(TEST_REPO_NAME, TEST_REPO_URL);
  
  SetLength(Params, 1);
  Params[0] := TEST_REPO_NAME;
  
  Cmd.Execute(Params, Ctx);
  
  AssertEquals(TEST_REPO_NAME, Ctx.Config.GetDefaultRepository,
    'Default repository not set correctly');
end;

{ Test 5: repo.remove - delete repository }
procedure TestRepoRemove;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  Cmd := TRepoRemoveCommand.Create;
  Ctx := TTestContext.Create;
  
  // Setup: Add test repository
  Ctx.Config.AddRepository(TEST_REPO_NAME, TEST_REPO_URL);
  
  SetLength(Params, 1);
  Params[0] := TEST_REPO_NAME;
  
  Cmd.Execute(Params, Ctx);
  
  AssertTrue(not Ctx.Config.HasRepository(TEST_REPO_NAME),
    'Repository was not deleted');
end;

begin
  WriteLn('========================================');
  WriteLn('TDD Refactored: Repo Commands Tests');
  WriteLn('========================================');
  WriteLn;
  
  RunTest('TestRepoAdd', @TestRepoAdd);
  RunTest('TestRepoAddEmptyParams', @TestRepoAddEmptyParams);
  RunTest('TestRepoList', @TestRepoList);
  RunTest('TestRepoDefault', @TestRepoDefault);
  RunTest('TestRepoRemove', @TestRepoRemove);
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('SUCCESS: All 5 tests passed!');
  WriteLn('========================================');
  
  Halt(0);
end.
