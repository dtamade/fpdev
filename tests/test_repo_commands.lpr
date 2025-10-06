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

{ 🔴 测试1: repo.add - 添加新仓库应该成功 }
procedure TestRepoAdd;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('🔴 TEST: TestRepoAdd - 期望成功添加仓库');
  
  Cmd := TRepoAddCommand.Create;
  Ctx := TTestContext.Create;
  
  SetLength(Params, 2);
  Params[0] := 'test-repo';
  Params[1] := 'https://example.com/test.git';
  
  try
    Cmd.Execute(Params, Ctx);
    
    // 验证：仓库应该被添加到配置中
    if not Ctx.Config.HasRepository('test-repo') then
    begin
      WriteLn('FAIL: 仓库未添加到配置');
      Halt(1);
    end;
    
    // 验证：URL应该正确
    if Ctx.Config.GetRepository('test-repo') <> 'https://example.com/test.git' then
    begin
      WriteLn('FAIL: 仓库URL不正确');
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

{ 🔴 测试2: repo.add - 空参数应该失败 }
procedure TestRepoAddEmptyParams;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('🔴 TEST: TestRepoAddEmptyParams - 期望空参数时不添加');
  
  Cmd := TRepoAddCommand.Create;
  Ctx := TTestContext.Create;
  
  SetLength(Params, 0);
  
  try
    Cmd.Execute(Params, Ctx);
    
    // 空参数时不应添加仓库，此测试只确保不崩溃
    WriteLn('PASS: TestRepoAddEmptyParams');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end;

{ 🔴 测试3: repo.list - 列出所有仓库 }
procedure TestRepoList;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('🔴 TEST: TestRepoList - 期望列出仓库不崩溃');
  
  Cmd := TRepoListCommand.Create;
  Ctx := TTestContext.Create;
  
  // 先添加一个测试仓库
  Ctx.Config.AddRepository('test-repo1', 'https://example.com/test1.git');
  Ctx.Config.AddRepository('test-repo2', 'https://example.com/test2.git');
  
  SetLength(Params, 0);
  
  try
    // list命令应该只输出，不崩溃
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

{ 🔴 测试4: repo.default - 设置默认仓库 }
procedure TestRepoDefault;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('🔴 TEST: TestRepoDefault - 期望设置默认仓库成功');
  
  Cmd := TRepoDefaultCommand.Create;
  Ctx := TTestContext.Create;
  
  // 先添加测试仓库
  Ctx.Config.AddRepository('test-repo', 'https://example.com/test.git');
  
  SetLength(Params, 1);
  Params[0] := 'test-repo';
  
  try
    Cmd.Execute(Params, Ctx);
    
    // 验证：默认仓库应该被设置
    if Ctx.Config.GetDefaultRepository <> 'test-repo' then
    begin
      WriteLn('FAIL: 默认仓库未正确设置, 当前值: ', Ctx.Config.GetDefaultRepository);
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

{ 🔴 测试5: repo.remove - 删除仓库 }
procedure TestRepoRemove;
var
  Cmd: IFpdevCommand;
  Ctx: ICommandContext;
  Params: array of string;
begin
  WriteLn('🔴 TEST: TestRepoRemove - 期望删除仓库成功');
  
  Cmd := TRepoRemoveCommand.Create;
  Ctx := TTestContext.Create;
  
  // 先添加测试仓库
  Ctx.Config.AddRepository('test-repo', 'https://example.com/test.git');
  
  SetLength(Params, 1);
  Params[0] := 'test-repo';
  
  try
    Cmd.Execute(Params, Ctx);
    
    // 验证：仓库应该被删除
    if Ctx.Config.HasRepository('test-repo') then
    begin
      WriteLn('FAIL: 仓库未被删除');
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
  WriteLn('🔴 TDD 红阶段: Repo Commands Tests');
  WriteLn('========================================');
  WriteLn;
  
  TestRepoAdd;
  TestRepoAddEmptyParams;
  TestRepoList;
  TestRepoDefault;
  TestRepoRemove;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('✅ 所有测试通过！');
  WriteLn('========================================');
  
  Halt(0);
end.
