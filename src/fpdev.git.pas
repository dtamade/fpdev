unit fpdev.git;

{$codepage utf8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process;

type
  { TGitManager }
  TGitManager = class
  private
    function ExecuteGitCommand(const ACommand: string; const AWorkingDir: string = ''): Boolean;
    function GetGitOutput(const ACommand: string; const AWorkingDir: string = ''): string;
    function IsGitInstalled: Boolean;
    function IsGitRepository(const APath: string): Boolean;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // 基本Git操作
    function CloneRepository(const AURL, ATargetDir: string; const ABranch: string = ''): Boolean;
    function UpdateRepository(const ARepoDir: string): Boolean;
    function CheckoutBranch(const ARepoDir, ABranch: string): Boolean;
    function GetCurrentBranch(const ARepoDir: string): string;
    function ListBranches(const ARepoDir: string): TStringArray;
    function GetLastCommitHash(const ARepoDir: string): string;
    
    // 验证和检查
    function ValidateGitEnvironment: Boolean;
    function GetGitVersion: string;
  end;

implementation

{ TGitManager }

constructor TGitManager.Create;
begin
  inherited Create;
end;

destructor TGitManager.Destroy;
begin
  inherited Destroy;
end;

function TGitManager.IsGitInstalled: Boolean;
var
  Process: TProcess;
begin
  Result := False;
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'git';
    Process.Parameters.Add('--version');
    Process.Options := Process.Options + [poWaitOnExit, poUsePipes, poNoConsole];
    
    try
      Process.Execute;
      Result := Process.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    Process.Free;
  end;
end;

function TGitManager.GetGitVersion: string;
begin
  Result := GetGitOutput('--version');
  if Result <> '' then
    Result := Trim(Result)
  else
    Result := 'Git not found';
end;

function TGitManager.ValidateGitEnvironment: Boolean;
begin
  Result := IsGitInstalled;
  if Result then
    WriteLn('✓ Git found: ', GetGitVersion)
  else
    WriteLn('✗ Git not found. Please install Git first.');
end;

function TGitManager.ExecuteGitCommand(const ACommand: string; const AWorkingDir: string): Boolean;
var
  Process: TProcess;
  CommandParts: TStringArray;
  i: Integer;
begin
  Result := False;
  
  if not IsGitInstalled then
  begin
    WriteLn('错误: Git未安装');
    Exit;
  end;
  
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'git';
    
    // 解析命令参数
    CommandParts := ACommand.Split(' ');
    for i := 0 to High(CommandParts) do
      if Trim(CommandParts[i]) <> '' then
        Process.Parameters.Add(Trim(CommandParts[i]));
    
    if AWorkingDir <> '' then
      Process.CurrentDirectory := AWorkingDir;
      
    Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
    
    WriteLn('执行: git ', ACommand);
    if AWorkingDir <> '' then
      WriteLn('工作目录: ', AWorkingDir);
    
    try
      Process.Execute;
      Result := Process.ExitStatus = 0;
      
      if not Result then
        WriteLn('Git命令执行失败，退出代码: ', Process.ExitStatus);
        
    except
      on E: Exception do
      begin
        WriteLn('执行Git命令时发生异常: ', E.Message);
        Result := False;
      end;
    end;
  finally
    Process.Free;
  end;
end;

function TGitManager.GetGitOutput(const ACommand: string; const AWorkingDir: string): string;
var
  Process: TProcess;
  CommandParts: TStringArray;
  i: Integer;
  OutputStream: TStringList;
begin
  Result := '';
  
  if not IsGitInstalled then
    Exit;
  
  Process := TProcess.Create(nil);
  OutputStream := TStringList.Create;
  try
    Process.Executable := 'git';
    
    // 解析命令参数
    CommandParts := ACommand.Split(' ');
    for i := 0 to High(CommandParts) do
      if Trim(CommandParts[i]) <> '' then
        Process.Parameters.Add(Trim(CommandParts[i]));
    
    if AWorkingDir <> '' then
      Process.CurrentDirectory := AWorkingDir;
      
    Process.Options := Process.Options + [poWaitOnExit, poUsePipes, poNoConsole];
    
    try
      Process.Execute;
      
      if Process.ExitStatus = 0 then
      begin
        OutputStream.LoadFromStream(Process.Output);
        Result := OutputStream.Text;
      end;
      
    except
      on E: Exception do
        Result := '';
    end;
  finally
    OutputStream.Free;
    Process.Free;
  end;
end;

function TGitManager.IsGitRepository(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath + PathDelim + '.git');
end;

function TGitManager.CloneRepository(const AURL, ATargetDir: string; const ABranch: string): Boolean;
var
  Command: string;
  ParentDir: string;
begin
  Result := False;
  
  WriteLn('正在克隆仓库...');
  WriteLn('URL: ', AURL);
  WriteLn('目标目录: ', ATargetDir);
  if ABranch <> '' then
    WriteLn('分支: ', ABranch);
  
  // 确保父目录存在
  ParentDir := ExtractFileDir(ATargetDir);
  if not DirectoryExists(ParentDir) then
  begin
    WriteLn('创建目录: ', ParentDir);
    if not ForceDirectories(ParentDir) then
    begin
      WriteLn('错误: 无法创建目录 ', ParentDir);
      Exit;
    end;
  end;
  
  // 如果目标目录已存在且是Git仓库，则更新而不是克隆
  if IsGitRepository(ATargetDir) then
  begin
    WriteLn('目标目录已存在Git仓库，尝试更新...');
    Result := UpdateRepository(ATargetDir);
    Exit;
  end;
  
  // 构建克隆命令
  Command := 'clone';
  if ABranch <> '' then
    Command := Command + ' --branch ' + ABranch;
  Command := Command + ' ' + AURL + ' ' + ATargetDir;
  
  Result := ExecuteGitCommand(Command);
  
  if Result then
    WriteLn('✓ 仓库克隆成功')
  else
    WriteLn('✗ 仓库克隆失败');
end;

function TGitManager.UpdateRepository(const ARepoDir: string): Boolean;
begin
  Result := False;
  
  if not IsGitRepository(ARepoDir) then
  begin
    WriteLn('错误: ', ARepoDir, ' 不是Git仓库');
    Exit;
  end;
  
  WriteLn('正在更新仓库: ', ARepoDir);
  
  // 执行 git pull
  Result := ExecuteGitCommand('pull', ARepoDir);
  
  if Result then
    WriteLn('✓ 仓库更新成功')
  else
    WriteLn('✗ 仓库更新失败');
end;

function TGitManager.CheckoutBranch(const ARepoDir, ABranch: string): Boolean;
begin
  Result := False;
  
  if not IsGitRepository(ARepoDir) then
  begin
    WriteLn('错误: ', ARepoDir, ' 不是Git仓库');
    Exit;
  end;
  
  WriteLn('切换到分支: ', ABranch);
  Result := ExecuteGitCommand('checkout ' + ABranch, ARepoDir);
  
  if Result then
    WriteLn('✓ 分支切换成功')
  else
    WriteLn('✗ 分支切换失败');
end;

function TGitManager.GetCurrentBranch(const ARepoDir: string): string;
begin
  Result := Trim(GetGitOutput('rev-parse --abbrev-ref HEAD', ARepoDir));
end;

function TGitManager.ListBranches(const ARepoDir: string): TStringArray;
var
  Output: string;
  Lines: TStringArray;
  i: Integer;
  Branch: string;
begin
  SetLength(Result, 0);
  
  Output := GetGitOutput('branch -r', ARepoDir);
  if Output = '' then
    Exit;
  
  Lines := Output.Split([#10, #13]);
  for i := 0 to High(Lines) do
  begin
    Branch := Trim(Lines[i]);
    if (Branch <> '') and (Pos('origin/', Branch) > 0) then
    begin
      Branch := StringReplace(Branch, 'origin/', '', []);
      if Branch <> 'HEAD' then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Branch;
      end;
    end;
  end;
end;

function TGitManager.GetLastCommitHash(const ARepoDir: string): string;
begin
  Result := Trim(GetGitOutput('rev-parse HEAD', ARepoDir));
end;

end.
