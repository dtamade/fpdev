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
  // 测试环境下不实际保存文件
  WriteLn('TEST: SaveIfModified called');
end;

{ Test 1: repo.add - add new repository should succeed }
procedure TestRepoAdd;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('[RED] TEST: TestRepoAdd - expect successful repository addition');
  
  Cmd := TRepoAddCommand.Create;
  Ctx := TTestContext.Create;
  
  SetLength(Params, 2);
  Params[0] := 'test-repo';
  Params[1] := 'https://example.com/test.git';
  
  try
    Cmd.Execute(Params, Ctx);
    
    // Verify: repository should be added to config
    if not Ctx.Config.HasRepository('test-repo') then
    begin
      WriteLn('FAIL: Repository not added to config');
      Halt(1);
    end;
    
    // Verify: URL should be correct
    if Ctx.Config.GetRepository('test-repo') <> 'https://example.com/test.git' then
    begin
      WriteLn('FAIL: Repository URL is incorrect');
      Halt(1);
    end;
    
    WriteLn('PASS: TestRepoAdd');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end;

{ Test 2: repo.add - empty parameters should fail }
procedure TestRepoAddEmptyParams;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('[RED] TEST: TestRepoAddEmptyParams - expect no addition with empty params');
  
  Cmd := TRepoAddCommand.Create;
  Ctx := TTestContext.Create;
  
  SetLength(Params, 0);
  
  try
    Cmd.Execute(Params, Ctx);
    
    // Empty params should not add repository, test ensures no crash
    WriteLn('PASS: TestRepoAddEmptyParams');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end;

{ Test 3: repo.list - list all repositories }
procedure TestRepoList;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('[RED] TEST: TestRepoList - expect listing repos without crash');
  
  Cmd := TRepoListCommand.Create;
  Ctx := TTestContext.Create;
  
  // Add test repositories first
  Ctx.Config.AddRepository('test-repo1', 'https://example.com/test1.git');
  Ctx.Config.AddRepository('test-repo2', 'https://example.com/test2.git');
  
  SetLength(Params, 0);
  
  try
    // list command should only output, not crash
    Cmd.Execute(Params, Ctx);
    WriteLn('PASS: TestRepoList');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end;

{ Test 4: repo.default - set default repository }
procedure TestRepoDefault;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('[RED] TEST: TestRepoDefault - expect setting default repo successfully');
  
  Cmd := TRepoDefaultCommand.Create;
  Ctx := TTestContext.Create;
  
  // Add test repository first
  Ctx.Config.AddRepository('test-repo', 'https://example.com/test.git');
  
  SetLength(Params, 1);
  Params[0] := 'test-repo';
  
  try
    Cmd.Execute(Params, Ctx);
    
    // Verify: default repository should be set
    if Ctx.Config.GetDefaultRepository <> 'test-repo' then
    begin
      WriteLn('FAIL: Default repository not set correctly, current value: ', Ctx.Config.GetDefaultRepository);
      Halt(1);
    end;
    
    WriteLn('PASS: TestRepoDefault');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end;

{ Test 5: repo.remove - delete repository }
procedure TestRepoRemove;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('[RED] TEST: TestRepoRemove - expect deleting repo successfully');
  
  Cmd := TRepoRemoveCommand.Create;
  Ctx := TTestContext.Create;
  
  // Add test repository first
  Ctx.Config.AddRepository('test-repo', 'https://example.com/test.git');
  
  SetLength(Params, 1);
  Params[0] := 'test-repo';
  
  try
    Cmd.Execute(Params, Ctx);
    
    // Verify: repository should be deleted
    if Ctx.Config.HasRepository('test-repo') then
    begin
      WriteLn('FAIL: Repository not deleted');
      Halt(1);
    end;
    
    WriteLn('PASS: TestRepoRemove');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('[RED PHASE] TDD: Repo Commands Tests');
  WriteLn('========================================');
  WriteLn;
  
  TestRepoAdd;
  TestRepoAddEmptyParams;
  TestRepoList;
  TestRepoDefault;
  TestRepoRemove;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('SUCCESS: All tests passed!');
  WriteLn('========================================');
  
  Halt(0);
end.
