unit fpdev.cmd.cross;

{$codepage utf8}

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.cross

交叉编译工具链管理


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
  { TCrossTargetPlatform }
  TCrossTargetPlatform = (
    ctpWin32, ctpWin64, ctpLinux32, ctpLinux64, ctpLinuxARM, ctpLinuxARM64,
    ctpDarwin32, ctpDarwin64, ctpDarwinARM64, ctpAndroid, ctpiOS,
    ctpFreeBSD32, ctpFreeBSD64, ctpCustom
  );

  { TCrossTargetInfo }
  TCrossTargetInfo = record
    Platform: TCrossTargetPlatform;
    Name: string;
    DisplayName: string;
    CPU: string;
    OS: string;
    BinutilsPrefix: string;
    LibrariesURL: string;
    BinutilsURL: string;
    Available: Boolean;
    Installed: Boolean;
  end;

  TCrossTargetArray = array of TCrossTargetInfo;

  { TCrossCompilerManager }
  TCrossCompilerManager = class
  private
    FConfigManager: TFPDevConfigManager;
    FInstallRoot: string;

    function GetAvailableTargets: TCrossTargetArray;
    function GetInstalledTargets: TCrossTargetArray;
    function DownloadBinutils(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
    function DownloadLibraries(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
    function SetupCrossEnvironment(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
    function ValidateTarget(const ATarget: string): Boolean;
    function GetTargetInstallPath(const ATarget: string): string;
    function IsTargetInstalled(const ATarget: string): Boolean;
    function GetTargetInfo(const ATarget: string): TCrossTargetInfo;
    function PlatformToString(APlatform: TCrossTargetPlatform): string;
    function StringToPlatform(const AStr: string): TCrossTargetPlatform;

  public
    constructor Create(AConfigManager: TFPDevConfigManager);
    destructor Destroy; override;

    // 交叉编译目标管理
    function InstallTarget(const ATarget: string): Boolean;
    function UninstallTarget(const ATarget: string): Boolean;
    function ListTargets(const AShowAll: Boolean = False): Boolean;
    function EnableTarget(const ATarget: string): Boolean;
    function DisableTarget(const ATarget: string): Boolean;

    // 工具链操作
    function ShowTargetInfo(const ATarget: string): Boolean;
    function TestTarget(const ATarget: string): Boolean;
    function BuildTest(const ATarget: string; const ASourceFile: string = ''): Boolean;

    // 配置管理
    function ConfigureTarget(const ATarget: string; const ABinutilsPath, ALibrariesPath: string): Boolean;
    function UpdateTarget(const ATarget: string): Boolean;
    function CleanTarget(const ATarget: string): Boolean;
  end;

// 主要执行函数
procedure execute(const aParams: array of string);

implementation

const
  // 支持的交叉编译目标
  CROSS_TARGETS: array[0..11] of TCrossTargetInfo = (
    (Platform: ctpWin32; Name: 'win32'; DisplayName: 'Windows 32-bit'; CPU: 'i386'; OS: 'win32'; BinutilsPrefix: 'i686-w64-mingw32-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpWin64; Name: 'win64'; DisplayName: 'Windows 64-bit'; CPU: 'x86_64'; OS: 'win64'; BinutilsPrefix: 'x86_64-w64-mingw32-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinux32; Name: 'linux32'; DisplayName: 'Linux 32-bit'; CPU: 'i386'; OS: 'linux'; BinutilsPrefix: 'i686-linux-gnu-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinux64; Name: 'linux64'; DisplayName: 'Linux 64-bit'; CPU: 'x86_64'; OS: 'linux'; BinutilsPrefix: 'x86_64-linux-gnu-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinuxARM; Name: 'linuxarm'; DisplayName: 'Linux ARM'; CPU: 'arm'; OS: 'linux'; BinutilsPrefix: 'arm-linux-gnueabihf-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpLinuxARM64; Name: 'linuxarm64'; DisplayName: 'Linux ARM64'; CPU: 'aarch64'; OS: 'linux'; BinutilsPrefix: 'aarch64-linux-gnu-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpDarwin32; Name: 'darwin32'; DisplayName: 'macOS 32-bit'; CPU: 'i386'; OS: 'darwin'; BinutilsPrefix: 'i686-apple-darwin-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpDarwin64; Name: 'darwin64'; DisplayName: 'macOS 64-bit'; CPU: 'x86_64'; OS: 'darwin'; BinutilsPrefix: 'x86_64-apple-darwin-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpDarwinARM64; Name: 'darwinarm64'; DisplayName: 'macOS ARM64'; CPU: 'aarch64'; OS: 'darwin'; BinutilsPrefix: 'aarch64-apple-darwin-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpAndroid; Name: 'android'; DisplayName: 'Android'; CPU: 'arm'; OS: 'android'; BinutilsPrefix: 'arm-linux-androideabi-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpiOS; Name: 'ios'; DisplayName: 'iOS'; CPU: 'aarch64'; OS: 'ios'; BinutilsPrefix: 'aarch64-apple-ios-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False),
    (Platform: ctpFreeBSD64; Name: 'freebsd64'; DisplayName: 'FreeBSD 64-bit'; CPU: 'x86_64'; OS: 'freebsd'; BinutilsPrefix: 'x86_64-freebsd-'; LibrariesURL: ''; BinutilsURL: ''; Available: True; Installed: False)
  );

{ TCrossCompilerManager }

constructor TCrossCompilerManager.Create(AConfigManager: TFPDevConfigManager);
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

  // 确保安装目录存在
  if not DirectoryExists(FInstallRoot) then
    ForceDirectories(FInstallRoot);
end;

destructor TCrossCompilerManager.Destroy;
begin
  inherited Destroy;
end;

function TCrossCompilerManager.PlatformToString(APlatform: TCrossTargetPlatform): string;
begin
  case APlatform of
    ctpWin32: Result := 'win32';
    ctpWin64: Result := 'win64';
    ctpLinux32: Result := 'linux32';
    ctpLinux64: Result := 'linux64';
    ctpLinuxARM: Result := 'linuxarm';
    ctpLinuxARM64: Result := 'linuxarm64';
    ctpDarwin32: Result := 'darwin32';
    ctpDarwin64: Result := 'darwin64';
    ctpDarwinARM64: Result := 'darwinarm64';
    ctpAndroid: Result := 'android';
    ctpiOS: Result := 'ios';
    ctpFreeBSD64: Result := 'freebsd64';
    ctpCustom: Result := 'custom';
  else
    Result := 'unknown';
  end;
end;

function TCrossCompilerManager.StringToPlatform(const AStr: string): TCrossTargetPlatform;
begin
  if SameText(AStr, 'win32') then Result := ctpWin32
  else if SameText(AStr, 'win64') then Result := ctpWin64
  else if SameText(AStr, 'linux32') then Result := ctpLinux32
  else if SameText(AStr, 'linux64') then Result := ctpLinux64
  else if SameText(AStr, 'linuxarm') then Result := ctpLinuxARM
  else if SameText(AStr, 'linuxarm64') then Result := ctpLinuxARM64
  else if SameText(AStr, 'darwin32') then Result := ctpDarwin32
  else if SameText(AStr, 'darwin64') then Result := ctpDarwin64
  else if SameText(AStr, 'darwinarm64') then Result := ctpDarwinARM64
  else if SameText(AStr, 'android') then Result := ctpAndroid
  else if SameText(AStr, 'ios') then Result := ctpiOS
  else if SameText(AStr, 'freebsd64') then Result := ctpFreeBSD64
  else Result := ctpCustom;
end;

function TCrossCompilerManager.GetTargetInstallPath(const ATarget: string): string;
begin
  Result := FInstallRoot + PathDelim + 'cross' + PathDelim + ATarget;
end;

function TCrossCompilerManager.IsTargetInstalled(const ATarget: string): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := FConfigManager.GetCrossTarget(ATarget, CrossTarget) and CrossTarget.Enabled;
end;

function TCrossCompilerManager.ValidateTarget(const ATarget: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(CROSS_TARGETS) do
  begin
    if SameText(CROSS_TARGETS[i].Name, ATarget) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TCrossCompilerManager.GetTargetInfo(const ATarget: string): TCrossTargetInfo;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for i := 0 to High(CROSS_TARGETS) do
  begin
    if SameText(CROSS_TARGETS[i].Name, ATarget) then
    begin
      Result := CROSS_TARGETS[i];
      Result.Installed := IsTargetInstalled(ATarget);
      Break;
    end;
  end;
end;

function TCrossCompilerManager.GetAvailableTargets: TCrossTargetArray;
var
  i: Integer;
begin
  SetLength(Result, Length(CROSS_TARGETS));
  for i := 0 to High(CROSS_TARGETS) do
  begin
    Result[i] := CROSS_TARGETS[i];
    Result[i].Installed := IsTargetInstalled(Result[i].Name);
  end;
end;

function TCrossCompilerManager.GetInstalledTargets: TCrossTargetArray;
var
  AllTargets: TCrossTargetArray;
  i, Count: Integer;
begin
  AllTargets := GetAvailableTargets;
  Count := 0;

  // 计算已安装目标数量
  for i := 0 to High(AllTargets) do
    if AllTargets[i].Installed then
      Inc(Count);

  // 创建结果数组
  SetLength(Result, Count);
  Count := 0;

  for i := 0 to High(AllTargets) do
  begin
    if AllTargets[i].Installed then
    begin
      Result[Count] := AllTargets[i];
      Inc(Count);
    end;
  end;
end;

function TCrossCompilerManager.DownloadBinutils(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
begin
  Result := False;
  WriteLn('正在下载 ', ATarget, ' 的二进制工具...');

  // TODO: 实现实际的下载逻辑
  // 这里应该根据目标平台下载相应的binutils
  // 例如从官方源或第三方源下载预编译的工具链

  WriteLn('注意: 二进制工具下载功能暂未实现');
  WriteLn('请手动安装交叉编译工具链，然后使用 configure 命令配置路径');

  Result := True; // 暂时返回成功，允许手动配置
end;

function TCrossCompilerManager.DownloadLibraries(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
begin
  Result := False;
  WriteLn('正在下载 ', ATarget, ' 的库文件...');

  // TODO: 实现实际的下载逻辑
  // 这里应该根据目标平台下载相应的系统库

  WriteLn('注意: 库文件下载功能暂未实现');
  WriteLn('请手动安装目标平台的库文件，然后使用 configure 命令配置路径');

  Result := True; // 暂时返回成功，允许手动配置
end;

function TCrossCompilerManager.SetupCrossEnvironment(const ATarget: string; const ATargetInfo: TCrossTargetInfo): Boolean;
var
  CrossTarget: TCrossTarget;
  InstallPath: string;
begin
  Result := False;

  try
    InstallPath := GetTargetInstallPath(ATarget);

    // 创建交叉编译目标配置
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    CrossTarget.Enabled := True;
    CrossTarget.BinutilsPath := InstallPath + PathDelim + 'bin';
    CrossTarget.LibrariesPath := InstallPath + PathDelim + 'lib';

    // 添加到配置
    Result := FConfigManager.AddCrossTarget(ATarget, CrossTarget);
    if Result then
      WriteLn('✓ ', ATarget, ' 交叉编译环境配置完成');

  except
    on E: Exception do
    begin
      WriteLn('错误: 设置交叉编译环境时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.InstallTarget(const ATarget: string): Boolean;
var
  TargetInfo: TCrossTargetInfo;
  InstallPath: string;
begin
  Result := False;

  if not ValidateTarget(ATarget) then
  begin
    WriteLn('错误: 不支持的交叉编译目标: ', ATarget);
    Exit;
  end;

  if IsTargetInstalled(ATarget) then
  begin
    WriteLn('交叉编译目标 ', ATarget, ' 已经安装');
    Result := True;
    Exit;
  end;

  try
    TargetInfo := GetTargetInfo(ATarget);
    InstallPath := GetTargetInstallPath(ATarget);
    WriteLn('安装交叉编译目标 ', ATarget, ' 到: ', InstallPath);

    // 确保安装目录存在
    if not DirectoryExists(InstallPath) then
      ForceDirectories(InstallPath);

    WriteLn('步骤 1/3: 下载二进制工具');
    if not DownloadBinutils(ATarget, TargetInfo) then
    begin
      WriteLn('错误: 下载二进制工具失败');
      Exit;
    end;

    WriteLn('步骤 2/3: 下载库文件');
    if not DownloadLibraries(ATarget, TargetInfo) then
    begin
      WriteLn('错误: 下载库文件失败');
      Exit;
    end;

    WriteLn('步骤 3/3: 配置环境');
    Result := SetupCrossEnvironment(ATarget, TargetInfo);

    if Result then
      WriteLn('✓ 交叉编译目标 ', ATarget, ' 安装完成');

  except
    on E: Exception do
    begin
      WriteLn('错误: 安装过程中发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.UninstallTarget(const ATarget: string): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsTargetInstalled(ATarget) then
  begin
    WriteLn('交叉编译目标 ', ATarget, ' 未安装');
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetTargetInstallPath(ATarget);

    WriteLn('正在卸载交叉编译目标 ', ATarget, '...');

    // 删除安装目录
    if DirectoryExists(InstallPath) then
    begin
      try
        {$IFDEF MSWINDOWS}
        // Windows下使用rmdir命令
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
        // Unix下使用rm命令
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

    // 从配置中移除
    FConfigManager.RemoveCrossTarget(ATarget);

    WriteLn('✓ 交叉编译目标 ', ATarget, ' 卸载完成');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 卸载过程中发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.ListTargets(const AShowAll: Boolean): Boolean;
var
  Targets: TCrossTargetArray;
  i: Integer;
begin
  Result := True;

  try
    if AShowAll then
      Targets := GetAvailableTargets
    else
      Targets := GetInstalledTargets;

    if AShowAll then
      WriteLn('可用的交叉编译目标:')
    else
      WriteLn('已安装的交叉编译目标:');

    WriteLn('');
    WriteLn('目标        状态    显示名称                CPU       操作系统');
    WriteLn('------------------------------------------------------------');

    for i := 0 to High(Targets) do
    begin
      Write(Format('%-10s  ', [Targets[i].Name]));

      if Targets[i].Installed then
        Write('已安装  ')
      else
        Write('可用    ');

      Write(Format('%-20s  ', [Targets[i].DisplayName]));
      Write(Format('%-8s  ', [Targets[i].CPU]));
      WriteLn(Targets[i].OS);
    end;

    WriteLn('');
    WriteLn('总计: ', Length(Targets), ' 个目标');

  except
    on E: Exception do
    begin
      WriteLn('错误: 列出目标时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.EnableTarget(const ATarget: string): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := False;

  try
    if FConfigManager.GetCrossTarget(ATarget, CrossTarget) then
    begin
      CrossTarget.Enabled := True;
      Result := FConfigManager.AddCrossTarget(ATarget, CrossTarget);
      if Result then
        WriteLn('✓ 交叉编译目标 ', ATarget, ' 已启用')
      else
        WriteLn('错误: 启用目标失败');
    end else
    begin
      WriteLn('错误: 交叉编译目标 ', ATarget, ' 未配置');
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 启用目标时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.DisableTarget(const ATarget: string): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := False;

  try
    if FConfigManager.GetCrossTarget(ATarget, CrossTarget) then
    begin
      CrossTarget.Enabled := False;
      Result := FConfigManager.AddCrossTarget(ATarget, CrossTarget);
      if Result then
        WriteLn('✓ 交叉编译目标 ', ATarget, ' 已禁用')
      else
        WriteLn('错误: 禁用目标失败');
    end else
    begin
      WriteLn('错误: 交叉编译目标 ', ATarget, ' 未配置');
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 禁用目标时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.ShowTargetInfo(const ATarget: string): Boolean;
var
  TargetInfo: TCrossTargetInfo;
  CrossTarget: TCrossTarget;
  InstallPath: string;
begin
  Result := False;

  if not ValidateTarget(ATarget) then
  begin
    WriteLn('错误: 不支持的交叉编译目标: ', ATarget);
    Exit;
  end;

  try
    TargetInfo := GetTargetInfo(ATarget);
    WriteLn('交叉编译目标信息: ', ATarget);
    WriteLn('');
    WriteLn('显示名称: ', TargetInfo.DisplayName);
    WriteLn('CPU架构: ', TargetInfo.CPU);
    WriteLn('操作系统: ', TargetInfo.OS);
    WriteLn('二进制工具前缀: ', TargetInfo.BinutilsPrefix);

    if TargetInfo.Installed then
    begin
      InstallPath := GetTargetInstallPath(ATarget);
      WriteLn('状态: 已安装');
      WriteLn('安装路径: ', InstallPath);

      if FConfigManager.GetCrossTarget(ATarget, CrossTarget) then
      begin
        WriteLn('二进制工具路径: ', CrossTarget.BinutilsPath);
        WriteLn('库文件路径: ', CrossTarget.LibrariesPath);
        WriteLn('启用状态: ', CrossTarget.Enabled);
      end;
    end else
    begin
      WriteLn('状态: 未安装');
    end;

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 显示目标信息时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.TestTarget(const ATarget: string): Boolean;
var
  CrossTarget: TCrossTarget;
  Process: TProcess;
  GCCExe: string;
begin
  Result := False;

  if not IsTargetInstalled(ATarget) then
  begin
    WriteLn('错误: 交叉编译目标 ', ATarget, ' 未安装');
    Exit;
  end;

  try
    if not FConfigManager.GetCrossTarget(ATarget, CrossTarget) then
    begin
      WriteLn('错误: 无法获取交叉编译目标配置');
      Exit;
    end;

    WriteLn('测试交叉编译目标 ', ATarget, '...');

    // 查找交叉编译器
    GCCExe := CrossTarget.BinutilsPath + PathDelim + GetTargetInfo(ATarget).BinutilsPrefix + 'gcc';
    {$IFDEF MSWINDOWS}
    GCCExe := GCCExe + '.exe';
    {$ENDIF}

    if not FileExists(GCCExe) then
    begin
      WriteLn('错误: 找不到交叉编译器: ', GCCExe);
      Exit;
    end;

    Process := TProcess.Create(nil);
    try
      Process.Executable := GCCExe;
      Process.Parameters.Add('--version');
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      Process.Execute;

      Result := Process.ExitStatus = 0;
      if Result then
        WriteLn('✓ 交叉编译目标 ', ATarget, ' 测试通过')
      else
        WriteLn('✗ 交叉编译目标 ', ATarget, ' 测试失败');

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 测试目标时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.BuildTest(const ATarget: string; const ASourceFile: string): Boolean;
begin
  Result := False;
  WriteLn('构建测试功能暂未实现');
  // TODO: 实现交叉编译测试构建
  // - 创建简单的测试程序
  // - 使用交叉编译器编译
  // - 验证输出文件
end;

function TCrossCompilerManager.ConfigureTarget(const ATarget: string; const ABinutilsPath, ALibrariesPath: string): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := False;

  if not ValidateTarget(ATarget) then
  begin
    WriteLn('错误: 不支持的交叉编译目标: ', ATarget);
    Exit;
  end;

  try
    // 验证路径
    if not DirectoryExists(ABinutilsPath) then
    begin
      WriteLn('错误: 二进制工具路径不存在: ', ABinutilsPath);
      Exit;
    end;

    if not DirectoryExists(ALibrariesPath) then
    begin
      WriteLn('错误: 库文件路径不存在: ', ALibrariesPath);
      Exit;
    end;

    // 创建配置
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    CrossTarget.Enabled := True;
    CrossTarget.BinutilsPath := ABinutilsPath;
    CrossTarget.LibrariesPath := ALibrariesPath;

    Result := FConfigManager.AddCrossTarget(ATarget, CrossTarget);
    if Result then
      WriteLn('✓ 交叉编译目标 ', ATarget, ' 配置完成')
    else
      WriteLn('错误: 配置目标失败');

  except
    on E: Exception do
    begin
      WriteLn('错误: 配置目标时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TCrossCompilerManager.UpdateTarget(const ATarget: string): Boolean;
begin
  Result := False;
  WriteLn('更新目标功能暂未实现');
  // TODO: 实现目标更新功能
end;

function TCrossCompilerManager.CleanTarget(const ATarget: string): Boolean;
begin
  Result := False;
  WriteLn('清理目标功能暂未实现');
  // TODO: 实现目标清理功能
end;

// 主要执行函数
procedure execute(const aParams: array of string);
var
  ConfigManager: TFPDevConfigManager;
  CrossManager: TCrossCompilerManager;
  Command: string;
  Target: string;
  BinutilsPath, LibrariesPath: string;
  ShowAll: Boolean;
  i: Integer;
begin
  if Length(aParams) = 0 then
  begin
    WriteLn('交叉编译工具链管理');
    WriteLn('');
    WriteLn('用法:');
    WriteLn('  fpdev cross install <target>                           安装交叉编译目标');
    WriteLn('  fpdev cross uninstall <target>                         卸载交叉编译目标');
    WriteLn('  fpdev cross list [--all]                               列出交叉编译目标');
    WriteLn('  fpdev cross enable <target>                            启用交叉编译目标');
    WriteLn('  fpdev cross disable <target>                           禁用交叉编译目标');
    WriteLn('  fpdev cross info <target>                              显示目标信息');
    WriteLn('  fpdev cross test <target>                              测试交叉编译目标');
    WriteLn('  fpdev cross configure <target> --binutils=<path> --libraries=<path>  配置目标路径');
    WriteLn('  fpdev cross build <target> [source-file]               构建测试程序');
    WriteLn('');
    WriteLn('支持的目标:');
    WriteLn('  win32, win64          - Windows 32/64位');
    WriteLn('  linux32, linux64      - Linux 32/64位');
    WriteLn('  linuxarm, linuxarm64  - Linux ARM/ARM64');
    WriteLn('  darwin32, darwin64    - macOS 32/64位');
    WriteLn('  darwinarm64           - macOS ARM64');
    WriteLn('  android               - Android');
    WriteLn('  ios                   - iOS');
    WriteLn('  freebsd64             - FreeBSD 64位');
    WriteLn('');
    WriteLn('示例:');
    WriteLn('  fpdev cross install win64                              安装Windows 64位交叉编译');
    WriteLn('  fpdev cross configure win64 --binutils=/usr/bin --libraries=/usr/lib  手动配置路径');
    WriteLn('  fpdev cross list --all                                 列出所有可用目标');
    Exit;
  end;

  ConfigManager := TFPDevConfigManager.Create;
  try
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;

    CrossManager := TCrossCompilerManager.Create(ConfigManager);
    try
      Command := LowerCase(aParams[0]);

      case Command of
        'install':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要安装的目标');
            WriteLn('用法: fpdev cross install <target>');
            Exit;
          end;

          Target := aParams[1];
          CrossManager.InstallTarget(Target);
        end;

        'uninstall':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要卸载的目标');
            WriteLn('用法: fpdev cross uninstall <target>');
            Exit;
          end;

          Target := aParams[1];
          CrossManager.UninstallTarget(Target);
        end;

        'list':
        begin
          ShowAll := (Length(aParams) > 1) and SameText(aParams[1], '--all');
          CrossManager.ListTargets(ShowAll);
        end;

        'enable':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要启用的目标');
            WriteLn('用法: fpdev cross enable <target>');
            Exit;
          end;

          Target := aParams[1];
          CrossManager.EnableTarget(Target);
        end;

        'disable':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要禁用的目标');
            WriteLn('用法: fpdev cross disable <target>');
            Exit;
          end;

          Target := aParams[1];
          CrossManager.DisableTarget(Target);
        end;

        'info':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要查看信息的目标');
            WriteLn('用法: fpdev cross info <target>');
            Exit;
          end;

          Target := aParams[1];
          CrossManager.ShowTargetInfo(Target);
        end;

        'test':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要测试的目标');
            WriteLn('用法: fpdev cross test <target>');
            Exit;
          end;

          Target := aParams[1];
          CrossManager.TestTarget(Target);
        end;

        'configure':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要配置的目标');
            WriteLn('用法: fpdev cross configure <target> --binutils=<path> --libraries=<path>');
            Exit;
          end;

          Target := aParams[1];
          BinutilsPath := '';
          LibrariesPath := '';

          // 解析参数
          for i := 2 to High(aParams) do
          begin
            if Pos('--binutils=', LowerCase(aParams[i])) = 1 then
              BinutilsPath := Copy(aParams[i], 12, Length(aParams[i]))
            else if Pos('--libraries=', LowerCase(aParams[i])) = 1 then
              LibrariesPath := Copy(aParams[i], 13, Length(aParams[i]));
          end;

          if (BinutilsPath = '') or (LibrariesPath = '') then
          begin
            WriteLn('错误: 请指定二进制工具和库文件路径');
            WriteLn('用法: fpdev cross configure <target> --binutils=<path> --libraries=<path>');
            Exit;
          end;

          CrossManager.ConfigureTarget(Target, BinutilsPath, LibrariesPath);
        end;

        'build':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定要构建的目标');
            WriteLn('用法: fpdev cross build <target> [source-file]');
            Exit;
          end;

          Target := aParams[1];
          if Length(aParams) > 2 then
            CrossManager.BuildTest(Target, aParams[2])
          else
            CrossManager.BuildTest(Target, '');
        end;

        'update':
        begin
          if Length(aParams) > 1 then
            Target := aParams[1]
          else
            Target := '';
          CrossManager.UpdateTarget(Target);
        end;

        'clean':
        begin
          if Length(aParams) > 1 then
            Target := aParams[1]
          else
            Target := '';
          CrossManager.CleanTarget(Target);
        end;

      else
        WriteLn('错误: 未知的命令: ', Command);
        WriteLn('使用 "fpdev cross" 查看帮助信息');
      end;

    finally
      CrossManager.Free;
    end;

    ConfigManager.SaveConfig;

  finally
    ConfigManager.Free;
  end;
end;

end.
