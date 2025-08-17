unit fpdev.lazarus.source;

{$codepage utf8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TLazarusSourceManager }
  TLazarusSourceManager = class
  private
    FSourceRoot: string;
    FCurrentVersion: string;
    
    function GetSourcePath(const AVersion: string): string;
    function GetVersionFromBranch(const ABranch: string): string;
    function ExecuteGitCommand(const ACommand: string; const AWorkingDir: string = ''): Boolean;
    
  public
    constructor Create(const ASourceRoot: string = '');
    destructor Destroy; override;
    
    // 源码管理
    function CloneLazarusSource(const AVersion: string = 'main'): Boolean;
    function UpdateLazarusSource(const AVersion: string = ''): Boolean;
    function SwitchLazarusVersion(const AVersion: string): Boolean;
    function ListAvailableVersions: TStringArray;
    function ListLocalVersions: TStringArray;
    
    // 版本信息
    function GetCurrentVersion: string;
    function IsVersionAvailable(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;
    
    // 路径管理
    function GetLazarusSourcePath(const AVersion: string = ''): string;
    function GetLazarusBuildPath(const AVersion: string = ''): string;
    function GetLazarusExecutablePath(const AVersion: string = ''): string;
    
    // Lazarus特定功能
    function BuildLazarus(const AVersion: string = ''): Boolean;
    function LaunchLazarus(const AVersion: string = ''): Boolean;
    function GetLazarusVersion(const AVersion: string = ''): string;
    function InstallLazarusVersion(const AVersion: string): Boolean;
    
    // 属性
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property CurrentVersion: string read GetCurrentVersion;
  end;

const
  // Lazarus Git仓库信息
  LAZARUS_GIT_URL = 'https://gitlab.com/freepascal.org/lazarus/lazarus.git';
  
  // 支持的Lazarus版本分支
  LAZARUS_VERSIONS: array[0..8] of record
    Version: string;
    Branch: string;
    Description: string;
    FPCVersion: string;
  end = (
    (Version: 'main'; Branch: 'main'; Description: 'Development version (unstable)'; FPCVersion: '3.2.2'),
    (Version: '3.0'; Branch: 'lazarus_3_0'; Description: 'Lazarus 3.0 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.2.6'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.6 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.2.4'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.4 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.2.2'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.2 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.0.12'; Branch: 'lazarus_2_0'; Description: 'Lazarus 2.0.12 (legacy)'; FPCVersion: '3.2.0'),
    (Version: '2.0.10'; Branch: 'lazarus_2_0'; Description: 'Lazarus 2.0.10 (legacy)'; FPCVersion: '3.2.0'),
    (Version: '1.8.4'; Branch: 'lazarus_1_8'; Description: 'Lazarus 1.8.4 (legacy)'; FPCVersion: '3.0.4'),
    (Version: '1.8.2'; Branch: 'lazarus_1_8'; Description: 'Lazarus 1.8.2 (legacy)'; FPCVersion: '3.0.4')
  );

implementation

{ TLazarusSourceManager }

constructor TLazarusSourceManager.Create(const ASourceRoot: string);
begin
  inherited Create;
  
  if ASourceRoot <> '' then
    FSourceRoot := ASourceRoot
  else
    FSourceRoot := 'sources' + PathDelim + 'lazarus';
    
  FCurrentVersion := '';
  
  // 确保源码根目录存在
  if not DirectoryExists(FSourceRoot) then
    ForceDirectories(FSourceRoot);
end;

destructor TLazarusSourceManager.Destroy;
begin
  inherited Destroy;
end;

function TLazarusSourceManager.GetSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  if AVersion = '' then
    Version := 'main'
  else
    Version := AVersion;
    
  Result := FSourceRoot + PathDelim + 'lazarus-' + Version;
end;

function TLazarusSourceManager.GetVersionFromBranch(const ABranch: string): string;
var
  i: Integer;
begin
  Result := ABranch;
  
  // 从分支名推断版本
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Branch, ABranch) then
    begin
      Result := LAZARUS_VERSIONS[i].Version;
      Break;
    end;
  end;
end;

function TLazarusSourceManager.ExecuteGitCommand(const ACommand: string; const AWorkingDir: string): Boolean;
var
  ExitCode: Integer;
  OldDir: string;
begin
  Result := False;
  
  WriteLn('执行Git命令: ', ACommand);
  if AWorkingDir <> '' then
    WriteLn('工作目录: ', AWorkingDir);
  
  OldDir := GetCurrentDir;
  try
    if (AWorkingDir <> '') and DirectoryExists(AWorkingDir) then
      SetCurrentDir(AWorkingDir);
    
    ExitCode := ExecuteProcess('git', ACommand.Split(' '));
    Result := ExitCode = 0;
    
    if Result then
      WriteLn('✓ Git命令执行成功')
    else
      WriteLn('✗ Git命令执行失败，退出代码: ', ExitCode);
      
  finally
    SetCurrentDir(OldDir);
  end;
end;

function TLazarusSourceManager.CloneLazarusSource(const AVersion: string): Boolean;
var
  Version, Branch, SourcePath: string;
  i: Integer;
begin
  Result := False;
  
  Version := AVersion;
  if Version = '' then
    Version := 'main';
  
  // 查找对应的分支
  Branch := Version;
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Version, Version) then
    begin
      Branch := LAZARUS_VERSIONS[i].Branch;
      Break;
    end;
  end;
  
  SourcePath := GetSourcePath(Version);
  
  WriteLn('正在克隆Lazarus源码...');
  WriteLn('版本: ', Version);
  WriteLn('分支: ', Branch);
  WriteLn('目标路径: ', SourcePath);
  WriteLn('预计大小: ~500MB');
  WriteLn;
  
  // 如果目录已存在，先删除
  if DirectoryExists(SourcePath) then
  begin
    WriteLn('删除已存在的源码目录...');
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', SourcePath]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', SourcePath]);
    {$ENDIF}
  end;
  
  // 执行克隆（使用浅克隆减少下载时间）
  Result := ExecuteGitCommand('clone --depth 1 --branch ' + Branch + ' ' + LAZARUS_GIT_URL + ' ' + SourcePath);
  
  if Result then
  begin
    WriteLn('✓ Lazarus源码克隆成功');
    FCurrentVersion := Version;
  end
  else
  begin
    WriteLn('✗ Lazarus源码克隆失败');
  end;
end;

function TLazarusSourceManager.UpdateLazarusSource(const AVersion: string): Boolean;
var
  Version, SourcePath: string;
begin
  Result := False;
  
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';
  
  SourcePath := GetSourcePath(Version);
  
  if not DirectoryExists(SourcePath) then
  begin
    WriteLn('✗ 源码目录不存在: ', SourcePath);
    WriteLn('请先克隆源码: CloneLazarusSource');
    Exit;
  end;
  
  WriteLn('正在更新Lazarus源码...');
  WriteLn('版本: ', Version);
  WriteLn('路径: ', SourcePath);
  
  Result := ExecuteGitCommand('pull', SourcePath);
  
  if Result then
    WriteLn('✓ Lazarus源码更新成功')
  else
    WriteLn('✗ Lazarus源码更新失败');
end;

function TLazarusSourceManager.SwitchLazarusVersion(const AVersion: string): Boolean;
begin
  Result := False;
  
  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('版本 ', AVersion, ' 未安装，正在克隆...');
    Result := CloneLazarusSource(AVersion);
  end
  else
  begin
    WriteLn('切换到Lazarus版本: ', AVersion);
    FCurrentVersion := AVersion;
    Result := True;
  end;
end;

function TLazarusSourceManager.ListAvailableVersions: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, Length(LAZARUS_VERSIONS));
  for i := 0 to High(LAZARUS_VERSIONS) do
    Result[i] := LAZARUS_VERSIONS[i].Version;
end;

function TLazarusSourceManager.ListLocalVersions: TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName, Version: string;
  i: Integer;
begin
  VersionList := TStringList.Create;
  try
    if FindFirst(FSourceRoot + PathDelim + 'lazarus-*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          DirName := SearchRec.Name;
          if Pos('lazarus-', DirName) = 1 then
          begin
            Version := Copy(DirName, 9, Length(DirName) - 8);
            VersionList.Add(Version);
          end;
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;
    
    SetLength(Result, VersionList.Count);
    for i := 0 to VersionList.Count - 1 do
      Result[i] := VersionList[i];
      
  finally
    VersionList.Free;
  end;
end;

function TLazarusSourceManager.GetCurrentVersion: string;
begin
  Result := FCurrentVersion;
end;

function TLazarusSourceManager.IsVersionAvailable(const AVersion: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Version, AVersion) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TLazarusSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := DirectoryExists(GetSourcePath(AVersion));
end;

function TLazarusSourceManager.GetLazarusSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';
    
  Result := GetSourcePath(Version);
end;

function TLazarusSourceManager.GetLazarusBuildPath(const AVersion: string): string;
begin
  Result := GetLazarusSourcePath(AVersion);
end;

function TLazarusSourceManager.GetLazarusExecutablePath(const AVersion: string): string;
var
  SourcePath: string;
begin
  SourcePath := GetLazarusSourcePath(AVersion);
  {$IFDEF MSWINDOWS}
  Result := SourcePath + PathDelim + 'lazarus.exe';
  {$ELSE}
  Result := SourcePath + PathDelim + 'lazarus';
  {$ENDIF}
end;

function TLazarusSourceManager.BuildLazarus(const AVersion: string): Boolean;
var
  SourcePath: string;
  BuildCommand: string;
begin
  Result := False;
  SourcePath := GetLazarusSourcePath(AVersion);
  
  if not DirectoryExists(SourcePath) then
  begin
    WriteLn('✗ Lazarus源码目录不存在: ', SourcePath);
    Exit;
  end;
  
  WriteLn('正在构建Lazarus...');
  WriteLn('源码路径: ', SourcePath);
  WriteLn('注意: 构建过程可能需要10-30分钟');
  
  {$IFDEF MSWINDOWS}
  BuildCommand := 'make clean all';
  {$ELSE}
  BuildCommand := 'make clean all';
  {$ENDIF}
  
  Result := ExecuteGitCommand(BuildCommand, SourcePath);
  
  if Result then
    WriteLn('✓ Lazarus构建成功')
  else
    WriteLn('✗ Lazarus构建失败');
end;

function TLazarusSourceManager.LaunchLazarus(const AVersion: string): Boolean;
var
  ExecutablePath: string;
begin
  Result := False;
  ExecutablePath := GetLazarusExecutablePath(AVersion);
  
  if not FileExists(ExecutablePath) then
  begin
    WriteLn('✗ Lazarus可执行文件不存在: ', ExecutablePath);
    WriteLn('请先构建Lazarus: BuildLazarus');
    Exit;
  end;
  
  WriteLn('启动Lazarus: ', ExecutablePath);
  
  {$IFDEF MSWINDOWS}
  Result := ExecuteProcess('cmd', ['/c', 'start', ExecutablePath]) = 0;
  {$ELSE}
  Result := ExecuteProcess(ExecutablePath, []) = 0;
  {$ENDIF}
  
  if Result then
    WriteLn('✓ Lazarus启动成功')
  else
    WriteLn('✗ Lazarus启动失败');
end;

function TLazarusSourceManager.GetLazarusVersion(const AVersion: string): string;
var
  i: Integer;
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';
  
  Result := Version;
  
  // 查找详细版本信息
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Version, Version) then
    begin
      Result := LAZARUS_VERSIONS[i].Description;
      Break;
    end;
  end;
end;

function TLazarusSourceManager.InstallLazarusVersion(const AVersion: string): Boolean;
var
  Version: string;
begin
  Result := False;
  Version := AVersion;

  WriteLn('开始安装Lazarus版本: ', Version);
  WriteLn('步骤: 1. 克隆源码 -> 2. 构建编译 -> 3. 设置环境');
  WriteLn;

  // 步骤1: 克隆源码
  WriteLn('[1/3] 克隆Lazarus源码...');
  if not CloneLazarusSource(Version) then
  begin
    WriteLn('✗ 源码克隆失败，安装中止');
    Exit;
  end;

  // 步骤2: 构建编译
  WriteLn('[2/3] 构建Lazarus IDE...');
  if not BuildLazarus(Version) then
  begin
    WriteLn('✗ 构建失败，安装中止');
    Exit;
  end;

  // 步骤3: 设置为当前版本
  WriteLn('[3/3] 设置为当前环境...');
  if SwitchLazarusVersion(Version) then
  begin
    WriteLn('✓ Lazarus ', Version, ' 安装完成！');
    WriteLn('当前Lazarus版本: ', Version);
    WriteLn('IDE路径: ', GetLazarusExecutablePath(Version));
    Result := True;
  end
  else
  begin
    WriteLn('✗ 环境设置失败');
  end;
end;

end.
