unit fpdev.cmd.package;

{$codepage utf8}

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.package

FreePascal 包管理系统


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
  SysUtils, Classes, Process,
  fpdev.config, fpdev.utils, fpdev.terminal;

type
  { TPackageInfo }
  TPackageInfo = record
    Name: string;
    Version: string;
    Description: string;
    Author: string;
    License: string;
    Homepage: string;
    Repository: string;
    Dependencies: TStringArray;
    Installed: Boolean;
    InstallPath: string;
    InstallDate: TDateTime;
  end;

  TPackageArray = array of TPackageInfo;

  { TPackageManager }
  TPackageManager = class
  private
    FConfigManager: TFPDevConfigManager;
    FInstallRoot: string;
    FPackageRegistry: string;

    function GetAvailablePackages: TPackageArray;
    function GetInstalledPackages: TPackageArray;
    function DownloadPackage(const APackageName, AVersion: string): Boolean;
    function InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
    function ValidatePackage(const APackageName: string): Boolean;
    function GetPackageInstallPath(const APackageName: string): string;
    function IsPackageInstalled(const APackageName: string): Boolean;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
    function ResolveDependencies(const APackageName: string): TStringArray;
    function BuildPackage(const ASourcePath: string): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager);
    destructor Destroy; override;

    // 包管理
    function InstallPackage(const APackageName: string; const AVersion: string = ''): Boolean;
    function UninstallPackage(const APackageName: string): Boolean;
    function UpdatePackage(const APackageName: string): Boolean;
    function ListPackages(const AShowAll: Boolean = False): Boolean;
    function SearchPackages(const AQuery: string): Boolean;

    // 包信息
    function ShowPackageInfo(const APackageName: string): Boolean;
    function ShowPackageDependencies(const APackageName: string): Boolean;
    function VerifyPackage(const APackageName: string): Boolean;

    // 仓库管理
    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function UpdateRepositories: Boolean;
    function ListRepositories: Boolean;

    // 本地包管理
    function InstallFromLocal(const APackagePath: string): Boolean;
    function CreatePackage(const APackageName, APath: string): Boolean;
    function PublishPackage(const APackageName: string): Boolean;
  end;

// 主要执行函数
procedure execute(const aParams: array of string);

implementation

const
  // 默认包仓库
  DEFAULT_REPOSITORIES: array[0..2] of record
    Name: string;
    URL: string;
  end = (
    (Name: 'official'; URL: 'https://packages.freepascal.org/'),
    (Name: 'lazarus'; URL: 'https://packages.lazarus-ide.org/'),
    (Name: 'community'; URL: 'https://github.com/freepascal-packages/')
  );

{ TPackageManager }

constructor TPackageManager.Create(AConfigManager: TFPDevConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + '\.fpdev';
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + '/.fpdev';
    {$ENDIF}

    Settings.InstallRoot := FInstallRoot;
    FConfigManager.SetSettings(Settings);
  end;

  FPackageRegistry := FInstallRoot + PathDelim + 'packages';

  // 确保包目录存在
  if not DirectoryExists(FPackageRegistry) then
    ForceDirectories(FPackageRegistry);
end;

destructor TPackageManager.Destroy;
begin
  inherited Destroy;
end;

function TPackageManager.GetPackageInstallPath(const APackageName: string): string;
begin
  Result := FPackageRegistry + PathDelim + APackageName;
end;

function TPackageManager.IsPackageInstalled(const APackageName: string): Boolean;
var
  InstallPath: string;
begin
  InstallPath := GetPackageInstallPath(APackageName);
  Result := DirectoryExists(InstallPath);
end;

function TPackageManager.ValidatePackage(const APackageName: string): Boolean;
begin
  // 简单的包名验证
  Result := (APackageName <> '') and (Pos(' ', APackageName) = 0) and (Pos('/', APackageName) = 0);
end;

function TPackageManager.GetPackageInfo(const APackageName: string): TPackageInfo;
begin
  // 初始化包信息
  FillChar(Result, SizeOf(Result), 0);
  Result.Name := APackageName;
  Result.Installed := IsPackageInstalled(APackageName);

  if Result.Installed then
  begin
    Result.InstallPath := GetPackageInstallPath(APackageName);
    // TODO: 从包的元数据文件读取详细信息
    Result.Version := '1.0.0';
    Result.Description := 'Installed package';
  end;
end;

function TPackageManager.GetAvailablePackages: TPackageArray;
begin
  // TODO: 从仓库获取可用包列表
  SetLength(Result, 0);
  WriteLn('注意: 包仓库功能暂未实现');
end;

function TPackageManager.GetInstalledPackages: TPackageArray;
var
  SearchRec: TSearchRec;
  Count: Integer;
begin
  SetLength(Result, 0);
  Count := 0;

  if FindFirst(FPackageRegistry + PathDelim + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory <> 0) and
         (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        SetLength(Result, Count + 1);
        Result[Count] := GetPackageInfo(SearchRec.Name);
        Inc(Count);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

function TPackageManager.DownloadPackage(const APackageName, AVersion: string): Boolean;
begin
  Result := False;
  WriteLn('正在下载包 ', APackageName, ' 版本 ', AVersion, '...');

  // TODO: 实现实际的下载逻辑
  WriteLn('注意: 包下载功能暂未实现');
  WriteLn('请使用 install-local 命令安装本地包');

  Result := True; // 暂时返回成功，允许本地安装
end;

function TPackageManager.BuildPackage(const ASourcePath: string): Boolean;
var
  Process: TProcess;
  Settings: TFPDevSettings;
  FoundLPK: string;
  SR: TSearchRec;
begin
  Result := False;

  if not DirectoryExists(ASourcePath) then
  begin
    WriteLn('错误: 源码路径不存在: ', ASourcePath);
    Exit;
  end;

  try
    WriteLn('正在编译包...');

    Settings := FConfigManager.GetSettings;

    // 查找并编译包
    Process := TProcess.Create(nil);
    try
      Process.CurrentDirectory := ASourcePath;

      // 优先使用 lazbuild 编译 Lazarus 包：查找首个 .lpk
      FoundLPK := '';
      if FindFirst(ASourcePath + PathDelim + '*.lpk', faAnyFile, SR) = 0 then
      begin
        repeat
          if (SR.Attr and faDirectory) = 0 then
          begin
            FoundLPK := ASourcePath + PathDelim + SR.Name;
            Break;
          end;
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;

      if FoundLPK <> '' then
      begin
        Process.Executable := 'lazbuild';
        Process.Parameters.Add(FoundLPK);
      end
      else if FileExists(ASourcePath + PathDelim + 'Makefile') then
      begin
        // 否则回退使用 make
        Process.Executable := 'make';
        Process.Parameters.Add('install');
      end
      else
      begin
        WriteLn('错误: 找不到可编译的包文件（缺少 .lpk 或 Makefile）');
        Exit;
      end;

      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      WriteLn('执行命令: ', Process.Executable, ' ', Process.Parameters.Text);
      Process.Execute;

      Result := Process.ExitStatus = 0;
      if not Result then
        WriteLn('错误: 编译失败，退出代码: ', Process.ExitStatus);

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 编译包时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  try
    InstallPath := GetPackageInstallPath(APackageName);
    WriteLn('安装包 ', APackageName, ' 到: ', InstallPath);

    // 确保安装目录存在
    if not DirectoryExists(InstallPath) then
      ForceDirectories(InstallPath);

    // 复制源码到安装目录
    WriteLn('步骤 1/2: 复制源码');
    // TODO: 实现目录复制功能

    WriteLn('步骤 2/2: 编译包');
    if not BuildPackage(ASourcePath) then
    begin
      WriteLn('错误: 编译包失败');
      Exit;
    end;

    WriteLn('✓ 包 ', APackageName, ' 安装完成');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 安装包时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.ResolveDependencies(const APackageName: string): TStringArray;
begin
  // TODO: 实现依赖解析
  SetLength(Result, 0);
  WriteLn('注意: 依赖解析功能暂未实现');
end;

function TPackageManager.InstallPackage(const APackageName: string; const AVersion: string): Boolean;
var
  UseVersion: string;
begin
  Result := False;

  if not ValidatePackage(APackageName) then
  begin
    WriteLn('错误: 无效的包名: ', APackageName);
    Exit;
  end;

  if IsPackageInstalled(APackageName) then
  begin
    WriteLn('包 ', APackageName, ' 已经安装');
    Result := True;
    Exit;
  end;

  try
    if AVersion <> '' then
      UseVersion := AVersion
    else
      UseVersion := 'latest';

    WriteLn('安装包 ', APackageName, ' 版本 ', UseVersion);

    // 下载包
    if not DownloadPackage(APackageName, UseVersion) then
    begin
      WriteLn('错误: 下载包失败');
      Exit;
    end;

    // TODO: 安装下载的包
    WriteLn('注意: 自动安装功能暂未实现');
    WriteLn('请使用 install-local 命令安装本地包');

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 安装包时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.UninstallPackage(const APackageName: string): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsPackageInstalled(APackageName) then
  begin
    WriteLn('包 ', APackageName, ' 未安装');
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetPackageInstallPath(APackageName);

    WriteLn('正在卸载包 ', APackageName, '...');

    // 删除安装目录
    if DirectoryExists(InstallPath) then
    begin
      try
        {$IFDEF MSWINDOWS}
        with TProcess.Create(nil) do
        try
          Executable := 'cmd';
          Parameters.Add('/c');
          Parameters.Add('rmdir');
          Parameters.Add('/s');
          Parameters.Add('/q');
          Parameters.Add(InstallPath);
          Options := Options + [poWaitOnExit];
          Execute;
          if ExitStatus <> 0 then
            WriteLn('警告: 无法完全删除安装目录: ', InstallPath);
        finally
          Free;
        end;
        {$ELSE}
        with TProcess.Create(nil) do
        try
          Executable := 'rm';
          Parameters.Add('-rf');
          Parameters.Add(InstallPath);
          Options := Options + [poWaitOnExit];
          Execute;
          if ExitStatus <> 0 then
            WriteLn('警告: 无法完全删除安装目录: ', InstallPath);
        finally
          Free;
        end;
        {$ENDIF}
      except
        WriteLn('警告: 删除安装目录时发生异常: ', InstallPath);
      end;
    end;

    WriteLn('✓ 包 ', APackageName, ' 卸载完成');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 卸载包时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.UpdatePackage(const APackageName: string): Boolean;
begin
  Result := False;
  WriteLn('更新包功能暂未实现');
  // TODO: 实现包更新功能
end;

function TPackageManager.ListPackages(const AShowAll: Boolean): Boolean;
var
  Packages: TPackageArray;
  i: Integer;
begin
  Result := True;

  try
    if AShowAll then
      Packages := GetAvailablePackages
    else
      Packages := GetInstalledPackages;

    if AShowAll then
      WriteLn('可用的包:')
    else
      WriteLn('已安装的包:');

    WriteLn('');
    WriteLn('包名          版本      描述');
    WriteLn('----------------------------------------');

    for i := 0 to High(Packages) do
    begin
      Write(Format('%-12s  ', [Packages[i].Name]));
      Write(Format('%-8s  ', [Packages[i].Version]));
      WriteLn(Packages[i].Description);
    end;

    WriteLn('');
    WriteLn('总计: ', Length(Packages), ' 个包');

  except
    on E: Exception do
    begin
      WriteLn('错误: 列出包时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.SearchPackages(const AQuery: string): Boolean;
begin
  Result := False;
  WriteLn('搜索包功能暂未实现');
  // TODO: 实现包搜索功能
end;

function TPackageManager.ShowPackageInfo(const APackageName: string): Boolean;
var
  PackageInfo: TPackageInfo;
begin
  Result := False;

  try
    PackageInfo := GetPackageInfo(APackageName);

    WriteLn('包信息: ', APackageName);
    WriteLn('');
    WriteLn('名称: ', PackageInfo.Name);
    WriteLn('版本: ', PackageInfo.Version);
    WriteLn('描述: ', PackageInfo.Description);

    if PackageInfo.Installed then
    begin
      WriteLn('状态: 已安装');
      WriteLn('安装路径: ', PackageInfo.InstallPath);
    end else
    begin
      WriteLn('状态: 未安装');
    end;

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 显示包信息时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.ShowPackageDependencies(const APackageName: string): Boolean;
var
  Dependencies: TStringArray;
  i: Integer;
begin
  Result := False;

  try
    Dependencies := ResolveDependencies(APackageName);

    WriteLn('包 ', APackageName, ' 的依赖:');
    WriteLn('');

    if Length(Dependencies) = 0 then
      WriteLn('无依赖')
    else
    begin
      for i := 0 to High(Dependencies) do
        WriteLn('  - ', Dependencies[i]);
    end;

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 显示包依赖时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.VerifyPackage(const APackageName: string): Boolean;
begin
  Result := False;
  WriteLn('验证包功能暂未实现');
  // TODO: 实现包验证功能
end;

function TPackageManager.AddRepository(const AName, AURL: string): Boolean;
begin
  Result := False;

  try
    Result := FConfigManager.AddRepository(AName, AURL);
    if Result then
      WriteLn('✓ 仓库 ', AName, ' 添加成功')
    else
      WriteLn('错误: 添加仓库失败');

  except
    on E: Exception do
    begin
      WriteLn('错误: 添加仓库时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.RemoveRepository(const AName: string): Boolean;
begin
  Result := False;
  WriteLn('删除仓库功能暂未实现');
  // TODO: 实现删除仓库功能
end;

function TPackageManager.UpdateRepositories: Boolean;
begin
  Result := False;
  WriteLn('更新仓库功能暂未实现');
  // TODO: 实现更新仓库功能
end;

function TPackageManager.ListRepositories: Boolean;
begin
  Result := False;
  WriteLn('列出仓库功能暂未实现');
  // TODO: 实现列出仓库功能
end;

function TPackageManager.InstallFromLocal(const APackagePath: string): Boolean;
var
  PackageName: string;
begin
  Result := False;

  if not DirectoryExists(APackagePath) then
  begin
    WriteLn('错误: 包路径不存在: ', APackagePath);
    Exit;
  end;

  try
    // 从路径提取包名
    PackageName := ExtractFileName(APackagePath);
    if PackageName = '' then
      PackageName := 'local_package';

    WriteLn('从本地安装包: ', PackageName);
    Result := InstallPackageFromSource(PackageName, APackagePath);

  except
    on E: Exception do
    begin
      WriteLn('错误: 从本地安装包时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TPackageManager.CreatePackage(const APackageName, APath: string): Boolean;
begin
  Result := False;
  WriteLn('创建包功能暂未实现');
  // TODO: 实现创建包功能
end;

function TPackageManager.PublishPackage(const APackageName: string): Boolean;
begin
  Result := False;
  WriteLn('发布包功能暂未实现');
  // TODO: 实现发布包功能
end;

// 主要执行函数
procedure execute(const aParams: array of string);
var
  ConfigManager: TFPDevConfigManager;
  PackageManager: TPackageManager;
  Command: string;
  PackageName: string;
  Version: string;
  ShowAll: Boolean;
begin
  if Length(aParams) = 0 then
  begin
    WriteLn('FreePascal 包管理系统');
    WriteLn('');
    WriteLn('用法:');
    WriteLn('  fpdev package install <package> [version]       安装包');
    WriteLn('  fpdev package uninstall <package>               卸载包');
    WriteLn('  fpdev package update <package>                  更新包');
    WriteLn('  fpdev package list [--all]                      列出包');
    WriteLn('  fpdev package search <query>                    搜索包');
    WriteLn('  fpdev package info <package>                    显示包信息');
    WriteLn('  fpdev package deps <package>                    显示包依赖');
    WriteLn('  fpdev package verify <package>                  验证包');
    WriteLn('  fpdev package install-local <path>              从本地安装包');
    WriteLn('  fpdev package create <name> <path>              创建包');
    WriteLn('  fpdev package publish <package>                 发布包');
    WriteLn('  fpdev package repo add <name> <url>             添加仓库');
    WriteLn('  fpdev package repo remove <name>                删除仓库');
    WriteLn('  fpdev package repo update                       更新仓库');
    WriteLn('  fpdev package repo list                         列出仓库');
    WriteLn('');
    WriteLn('示例:');
    WriteLn('  fpdev package install synapse                   安装synapse包');
    WriteLn('  fpdev package install synapse 1.2.0             安装指定版本');
    WriteLn('  fpdev package list --all                        列出所有可用包');
    WriteLn('  fpdev package install-local ./mypackage         从本地安装包');
    Exit;
  end;

  ConfigManager := TFPDevConfigManager.Create;
  try
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;

    PackageManager := TPackageManager.Create(ConfigManager);
    try
      Command := LowerCase(aParams[0]);

      case Command of
        'install':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要安装的包名');
            WriteLn('用法: fpdev package install <package> [version]');
            Exit;
          end;

          PackageName := aParams[1];
          if Length(aParams) > 2 then
            Version := aParams[2]
          else
            Version := '';

          PackageManager.InstallPackage(PackageName, Version);
        end;

        'uninstall':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要卸载的包名');
            WriteLn('用法: fpdev package uninstall <package>');
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.UninstallPackage(PackageName);
        end;

        'update':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要更新的包名');
            WriteLn('用法: fpdev package update <package>');
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.UpdatePackage(PackageName);
        end;

        'list':
        begin
          ShowAll := (Length(aParams) > 1) and SameText(aParams[1], '--all');
          PackageManager.ListPackages(ShowAll);
        end;

        'search':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定搜索关键词');
            WriteLn('用法: fpdev package search <query>');
            Exit;
          end;

          PackageManager.SearchPackages(aParams[1]);
        end;

        'info':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要查看信息的包名');
            WriteLn('用法: fpdev package info <package>');
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.ShowPackageInfo(PackageName);
        end;

        'deps':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要查看依赖的包名');
            WriteLn('用法: fpdev package deps <package>');
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.ShowPackageDependencies(PackageName);
        end;

        'verify':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要验证的包名');
            WriteLn('用法: fpdev package verify <package>');
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.VerifyPackage(PackageName);
        end;

        'install-local':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定包的本地路径');
            WriteLn('用法: fpdev package install-local <path>');
            Exit;
          end;

          PackageManager.InstallFromLocal(aParams[1]);
        end;

        'create':
        begin
          if Length(aParams) < 3 then
          begin
            WriteLn('错误: 请指定包名和路径');
            WriteLn('用法: fpdev package create <name> <path>');
            Exit;
          end;

          PackageManager.CreatePackage(aParams[1], aParams[2]);
        end;

        'publish':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要发布的包名');
            WriteLn('用法: fpdev package publish <package>');
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.PublishPackage(PackageName);
        end;

        'repo':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定仓库操作');
            WriteLn('用法: fpdev package repo <add|remove|update|list> [args]');
            Exit;
          end;

          case LowerCase(aParams[1]) of
            'add':
            begin
              if Length(aParams) < 4 then
              begin
                WriteLn('错误: 请指定仓库名和URL');
                WriteLn('用法: fpdev package repo add <name> <url>');
                Exit;
              end;
              PackageManager.AddRepository(aParams[2], aParams[3]);
            end;

            'remove':
            begin
              if Length(aParams) < 3 then
              begin
                WriteLn('错误: 请指定要删除的仓库名');
                WriteLn('用法: fpdev package repo remove <name>');
                Exit;
              end;
              PackageManager.RemoveRepository(aParams[2]);
            end;

            'update':
              PackageManager.UpdateRepositories;

            'list':
              PackageManager.ListRepositories;

          else
            WriteLn('错误: 未知的仓库操作: ', aParams[1]);
          end;
        end;

      else
        WriteLn('错误: 未知的命令: ', Command);
        WriteLn('使用 "fpdev package" 查看帮助信息');
      end;

    finally
      PackageManager.Free;
    end;

    ConfigManager.SaveConfig;

  finally
    ConfigManager.Free;
  end;
end;

end.
