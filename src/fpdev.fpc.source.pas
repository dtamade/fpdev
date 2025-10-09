unit fpdev.fpc.source;

{$codepage utf8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, fpdev.git2, fpdev.source.repo, fpdev.build.manager;

type
  // FPCUpDeluxe-inspired build steps
  TFPCBuildStep = (
    bsInit,           // Initialize environment
    bsBootstrap,      // Ensure bootstrap compiler
    bsClone,          // Clone source code
    bsCompiler,       // Build compiler
    bsRTL,            // Build RTL
    bsPackages,       // Build packages
    bsInstall,        // Install binaries
    bsConfig,         // Configure environment
    bsFinished        // Finished
  );

  { TFPCSourceManager }
  TFPCSourceManager = class
  private
    FSourceRoot: string;
    FCurrentVersion: string;
    FBootstrapCompiler: string;
    FCurrentStep: TFPCBuildStep;
    FParallelJobs: Integer;
    FUseCache: Boolean;
    FVerboseOutput: Boolean;

    function GetSourcePath(const AVersion: string): string;
    function GetVersionFromBranch(const ABranch: string): string;
    function ExecuteGitCommand(const ACommand: string; const AWorkingDir: string = ''): Boolean;
    function ExecuteCommand(const AProgram: string; const AArgs: array of string; const AWorkingDir: string = ''): Boolean;
    function IsValidSourceDirectory(const APath: string): Boolean;

    // Bootstrap compiler management (FPCUpDeluxe-inspired)
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function FindSystemFPC: string;
    function IsCompatibleBootstrap(const ACompilerPath, ARequiredVersion: string): Boolean;
    function GetBootstrapPath(const AVersion: string): string;
    function DownloadBootstrapCompiler(const AVersion: string): Boolean;
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

    // Step-by-step build process (FPCUpDeluxe-inspired)
    function InitializeInstall(const AVersion: string): Boolean;
    function BuildFPCCompiler(const AVersion: string): Boolean;
    function BuildFPCRTL(const AVersion: string): Boolean;
    function BuildFPCPackages(const AVersion: string): Boolean;
    function InstallFPCBinaries(const AVersion: string): Boolean;
    function ConfigureFPCEnvironment(const AVersion: string): Boolean;
    function TestBuildResults(const AVersion: string): Boolean;
    function ReportBuildStep(const AStep: TFPCBuildStep; const AMessage: string): Boolean;

    // Performance optimization methods
    function GetOptimalJobCount: Integer;
    function IsCacheAvailable(const AVersion: string): Boolean;
    function UseCachedBuild(const AVersion: string): Boolean;
    function OptimizeBuildCommand(const ABaseCommand: string): string;
    function CheckBuildPrerequisites(const AVersion: string): Boolean;

  public
    constructor Create(const ASourceRoot: string = '');
    destructor Destroy; override;

    // 源码管理
    function CloneFPCSource(const AVersion: string = 'main'): Boolean;
    function UpdateFPCSource(const AVersion: string = ''): Boolean;
    function SwitchFPCVersion(const AVersion: string): Boolean;
    // 分离职责：仓库管理器
    function Repo: TSourceRepoManager;
    function BuildFPCSource(const AVersion: string = ''): Boolean;
    function InstallFPCVersion(const AVersion: string): Boolean;
    function ListAvailableVersions: TStringArray;
    function ListLocalVersions: TStringArray;

    // 版本信息
    function GetCurrentVersion: string;
    function IsVersionAvailable(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;

    // 路径管理
    function GetFPCSourcePath(const AVersion: string = ''): string;
    function GetFPCBuildPath(const AVersion: string = ''): string;

    // 属性
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property CurrentVersion: string read GetCurrentVersion;
  end;

const
  // FPC Git仓库信息
  FPC_GIT_URL = 'https://gitlab.com/freepascal.org/fpc/source.git';

  // 支持的FPC版本分支
  FPC_VERSIONS: array[0..6] of record
    Version: string;
    Branch: string;
    Description: string;
  end = (
    (Version: 'main'; Branch: 'main'; Description: 'Development version (unstable)'),
    (Version: '3.2.2'; Branch: 'fixes_3_2'; Description: 'FPC 3.2.2 (stable)'),
    (Version: '3.2.0'; Branch: 'fixes_3_2'; Description: 'FPC 3.2.0 (stable)'),
    (Version: '3.0.4'; Branch: 'release_3_0_4'; Description: 'FPC 3.0.4 (legacy)'),
    (Version: '3.0.2'; Branch: 'release_3_0_2'; Description: 'FPC 3.0.2 (legacy)'),
    (Version: '2.6.4'; Branch: 'release_2_6_4'; Description: 'FPC 2.6.4 (legacy)'),
    (Version: '2.6.2'; Branch: 'release_2_6_2'; Description: 'FPC 2.6.2 (legacy)')
  );

implementation

{ TFPCSourceManager }

constructor TFPCSourceManager.Create(const ASourceRoot: string);
begin
  inherited Create;

  if ASourceRoot <> '' then
    FSourceRoot := ASourceRoot
  else
    FSourceRoot := 'sources' + PathDelim + 'fpc';

  FCurrentVersion := '';

  // Performance optimization initialization
  FParallelJobs := GetOptimalJobCount;
  FUseCache := True;
  FVerboseOutput := False;

  // 确保源码根目录存在
  if not DirectoryExists(FSourceRoot) then
    ForceDirectories(FSourceRoot);
end;

function TFPCSourceManager.Repo: TSourceRepoManager;
begin
  // 简单工厂：每次返回一个轻量对象，避免引入持久字段
  Result := TSourceRepoManager.Create(FSourceRoot);
end;

destructor TFPCSourceManager.Destroy;
begin
  inherited Destroy;
end;

function TFPCSourceManager.GetSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  if AVersion = '' then
    Version := 'main'
  else
    Version := AVersion;

  Result := FSourceRoot + PathDelim + 'fpc-' + Version;
end;

function TFPCSourceManager.GetVersionFromBranch(const ABranch: string): string;
var
  i: Integer;
begin
  Result := ABranch;

  // 从分支名推断版本
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Branch, ABranch) then
    begin
      Result := FPC_VERSIONS[i].Version;
      Break;
    end;
  end;
end;

function TFPCSourceManager.ExecuteGitCommand(const ACommand: string; const AWorkingDir: string): Boolean;
var
  ExitCode: Integer;
  OldDir: string;
begin
  Result := False;

  // WriteLn('执行Git命令: ', ACommand);  // 调试代码已注释
  if AWorkingDir <> '' then
  // WriteLn('工作目录: ', AWorkingDir);  // 调试代码已注释

  OldDir := GetCurrentDir;
  try
    if (AWorkingDir <> '') and DirectoryExists(AWorkingDir) then
      SetCurrentDir(AWorkingDir);

    ExitCode := ExecuteProcess('git', ACommand.Split(' '));
    Result := ExitCode = 0;

    if Result then
    begin
      // WriteLn('✓ Git命令执行成功')  // 调试代码已注释
    end
    else
    begin
      // WriteLn('✗ Git命令执行失败，退出代码: ', ExitCode);  // 调试代码已注释
    end;

  finally
    SetCurrentDir(OldDir);
  end;
end;

function TFPCSourceManager.ExecuteCommand(const AProgram: string; const AArgs: array of string; const AWorkingDir: string): Boolean;
var
  ExitCode: Integer;
  OldDir: string;
  Args: TStringArray;
  i: Integer;
begin
  Result := False;

  // WriteLn('执行命令: ', AProgram);  // 调试代码已注释
  if AWorkingDir <> '' then
  // WriteLn('工作目录: ', AWorkingDir);  // 调试代码已注释

  // 转换参数数组
  SetLength(Args, Length(AArgs));
  for i := 0 to High(AArgs) do
    Args[i] := AArgs[i];

  OldDir := GetCurrentDir;
  try
    if (AWorkingDir <> '') and DirectoryExists(AWorkingDir) then
      SetCurrentDir(AWorkingDir);

    ExitCode := ExecuteProcess(AProgram, Args);
    Result := ExitCode = 0;

    if Result then
    begin
      // WriteLn('✓ 命令执行成功')  // 调试代码已注释
    end
    else
    begin
      // WriteLn('✗ 命令执行失败，退出代码: ', ExitCode);  // 调试代码已注释
    end;

  finally
    SetCurrentDir(OldDir);
  end;
end;

function TFPCSourceManager.CloneFPCSource(const AVersion: string): Boolean;
begin
  // 代理到 SourceRepoManager，保持现有日志与行为最小变更
  Result := Repo.CloneFPCSource(AVersion);
  if Result then FCurrentVersion := IfThen(AVersion<>'', AVersion, 'main');
end;

function TFPCSourceManager.UpdateFPCSource(const AVersion: string): Boolean;
var
  LVersion: string;
begin
  LVersion := AVersion;
  if LVersion = '' then LVersion := FCurrentVersion;
  if LVersion = '' then LVersion := 'main';
  Result := Repo.UpdateFPCSource(LVersion);
  if Result then WriteLn('✓ FPC源码更新成功（fetch）') else WriteLn('✗ FPC源码更新失败（fetch）');
end;

function TFPCSourceManager.SwitchFPCVersion(const AVersion: string): Boolean;
begin
  if not IsVersionInstalled(AVersion) then
  begin
  // WriteLn('版本 ', AVersion, ' 未安装（请先执行: fpdev fpc install ', AVersion, '）');  // 调试代码已注释
    Exit(False);
  end;
  Result := Repo.SwitchFPCVersion(AVersion);
  if Result then
  begin
    FCurrentVersion := AVersion;
  // WriteLn('✓ 已切换至版本: ', AVersion);  // 调试代码已注释
  end
  else
  // WriteLn('✗ 切换版本失败: ', AVersion);  // 调试代码已注释
end;

function TFPCSourceManager.ListAvailableVersions: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FPC_VERSIONS));
  for i := 0 to High(FPC_VERSIONS) do
    Result[i] := FPC_VERSIONS[i].Version;
end;

function TFPCSourceManager.ListLocalVersions: TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName, Version: string;
  i: Integer;
begin
  VersionList := TStringList.Create;
  try
    if FindFirst(FSourceRoot + PathDelim + 'fpc-*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          DirName := SearchRec.Name;
          if Pos('fpc-', DirName) = 1 then
          begin
            Version := Copy(DirName, 5, Length(DirName) - 4);
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

function TFPCSourceManager.GetCurrentVersion: string;
begin
  Result := FCurrentVersion;
end;

function TFPCSourceManager.IsVersionAvailable(const AVersion: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Version, AVersion) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TFPCSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := DirectoryExists(GetSourcePath(AVersion));
end;

function TFPCSourceManager.GetFPCSourcePath(const AVersion: string): string;
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

function TFPCSourceManager.GetFPCBuildPath(const AVersion: string): string;
begin
  Result := GetFPCSourcePath(AVersion) + PathDelim + 'build';
end;

function TFPCSourceManager.BuildFPCSource(const AVersion: string): Boolean;
var
  Version, SourcePath: string;
  BuildCommand: string;
begin
  Result := False;

  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  SourcePath := GetFPCSourcePath(Version);

  if not DirectoryExists(SourcePath) then
  begin
  // WriteLn('✗ FPC源码目录不存在: ', SourcePath);  // 调试代码已注释
  // WriteLn('请先克隆源码: CloneFPCSource');  // 调试代码已注释
    Exit;
  end;

  // WriteLn('正在构建FPC ', Version, '...');  // 调试代码已注释
  // WriteLn('源码路径: ', SourcePath);  // 调试代码已注释
  // WriteLn('注意: 构建过程可能需要30-60分钟');  // 调试代码已注释
  WriteLn;

  // 构建FPC需要已有的FPC编译器作为bootstrap
  {$IFDEF MSWINDOWS}
  BuildCommand := 'make clean all';
  {$ELSE}
  BuildCommand := 'make clean all';
  {$ENDIF}

  // WriteLn('执行构建命令: ', BuildCommand);  // 调试代码已注释
  Result := ExecuteCommand('make', ['clean', 'all'], SourcePath);

  if Result then
  begin
  // WriteLn('✓ FPC ', Version, ' 构建成功');  // 调试代码已注释
  // WriteLn('编译器位置: ', SourcePath, PathDelim, 'compiler', PathDelim, 'ppc386');  // 调试代码已注释
  end
  else
  begin
  // WriteLn('✗ FPC ', Version, ' 构建失败');  // 调试代码已注释
  // WriteLn('请检查:');  // 调试代码已注释
  // WriteLn('1. 是否已安装bootstrap FPC编译器');  // 调试代码已注释
  // WriteLn('2. 是否安装了必要的构建工具 (make, binutils)');  // 调试代码已注释
  // WriteLn('3. 网络连接是否正常');  // 调试代码已注释
  end;
end;

function TFPCSourceManager.InstallFPCVersion(const AVersion: string): Boolean;
var
  Version: string;
begin
  Result := False;
  Version := AVersion;

  // WriteLn('开始构建测试FPC版本: ', Version);  // 调试代码已注释
  // WriteLn('智能构建流程 (智能clone管理，避免重复克隆)');  // 调试代码已注释
  WriteLn;

  // Step 1: Initialize build environment
  FCurrentStep := bsInit;
  if not ReportBuildStep(bsInit, '初始化构建环境') then Exit;
  if not InitializeInstall(Version) then
  begin
  // WriteLn('✗ 构建环境初始化失败');  // 调试代码已注释
    Exit;
  end;

  // Step 2: Ensure bootstrap compiler
  FCurrentStep := bsBootstrap;
  if not ReportBuildStep(bsBootstrap, '检查Bootstrap编译器') then Exit;
  if not EnsureBootstrapCompiler(Version) then
  begin
  // WriteLn('✗ Bootstrap编译器准备失败');  // 调试代码已注释
    Exit;
  end;

  // Step 3: Smart clone source code (only if needed)
  FCurrentStep := bsClone;
  if not ReportBuildStep(bsClone, '智能克隆FPC源码') then Exit;
  if not CloneFPCSource(Version) then
  begin
  // WriteLn('✗ 源码准备失败');  // 调试代码已注释
    Exit;
  end;

  // Step 4: Build compiler
  FCurrentStep := bsCompiler;
  if not ReportBuildStep(bsCompiler, '构建FPC编译器') then Exit;
  if not BuildFPCCompiler(Version) then
  begin
  // WriteLn('✗ 编译器构建失败');  // 调试代码已注释
    Exit;
  end;

  // Step 4: Build RTL
  FCurrentStep := bsRTL;
  if not ReportBuildStep(bsRTL, '构建FPC RTL') then Exit;
  if not BuildFPCRTL(Version) then
  begin
  // WriteLn('✗ RTL构建失败');  // 调试代码已注释
    Exit;
  end;

  // Step 6: Test build results
  FCurrentStep := bsConfig;
  if not ReportBuildStep(bsConfig, '测试构建结果') then Exit;
  if not TestBuildResults(Version) then
  begin
  // WriteLn('✗ 构建测试失败');  // 调试代码已注释
    Exit;
  end;

  // Finished
  FCurrentStep := bsFinished;
  ReportBuildStep(bsFinished, 'FPC构建测试完成');

  WriteLn;
  // WriteLn('🎉 FPC ', Version, ' 构建测试成功！');  // 调试代码已注释
  // WriteLn('构建路径: ', GetFPCSourcePath(Version), PathDelim, 'compiler');  // 调试代码已注释
  // WriteLn('Bootstrap: ', FBootstrapCompiler);  // 调试代码已注释
  // WriteLn('并行任务: ', FParallelJobs);  // 调试代码已注释
  Result := True;
end;

// Bootstrap compiler management (FPCUpDeluxe-inspired)
function TFPCSourceManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  // Based on FPCUpDeluxe logic: determine required bootstrap version
  if (ATargetVersion = 'main') or (ATargetVersion = '3.3.1') then
    Result := '3.2.2'
  else if (ATargetVersion = '3.2.2') or (ATargetVersion = '3.2.0') then
    Result := '3.0.4'
  else if (ATargetVersion = '3.0.4') or (ATargetVersion = '3.0.2') then
    Result := '2.6.4'
  else
    Result := '3.2.2'; // Default to stable version
end;

function TFPCSourceManager.FindSystemFPC: string;
begin
  Result := '';
  // Try to find system FPC compiler
  if ExecuteCommand('fpc', ['-v'], '') then
    Result := 'fpc'; // System FPC available
end;

function TFPCSourceManager.IsCompatibleBootstrap(const ACompilerPath, ARequiredVersion: string): Boolean;
begin
  // Simplified compatibility check
  Result := (ACompilerPath <> '') and FileExists(ACompilerPath);
  // TODO: Add actual version checking
end;

function TFPCSourceManager.GetBootstrapPath(const AVersion: string): string;
begin
  Result := FSourceRoot + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion + PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function TFPCSourceManager.DownloadBootstrapCompiler(const AVersion: string): Boolean;
begin
  // WriteLn('! 正在下载Bootstrap编译器 ', AVersion, '...');  // 调试代码已注释
  // WriteLn('注意: 实际实现中需要从FPC官方下载预编译版本');  // 调试代码已注释
  // TODO: Implement actual bootstrap download
  Result := True; // Simulate success for now
end;

function TFPCSourceManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
var
  RequiredVersion, SystemFPC, BootstrapPath: string;
begin
  RequiredVersion := GetRequiredBootstrapVersion(ATargetVersion);
  // WriteLn('需要Bootstrap编译器版本: ', RequiredVersion);  // 调试代码已注释

  // Check system FPC
  SystemFPC := FindSystemFPC;
  if IsCompatibleBootstrap(SystemFPC, RequiredVersion) then
  begin
    FBootstrapCompiler := SystemFPC;
  // WriteLn('✓ 使用系统FPC作为Bootstrap编译器');  // 调试代码已注释
    Exit(True);
  end;

  // Check downloaded bootstrap
  BootstrapPath := GetBootstrapPath(RequiredVersion);
  if FileExists(BootstrapPath) then
  begin
    FBootstrapCompiler := BootstrapPath;
  // WriteLn('✓ 使用已下载的Bootstrap编译器');  // 调试代码已注释
    Exit(True);
  end;

  // Download bootstrap compiler
  // WriteLn('! 系统FPC版本不兼容，正在下载Bootstrap编译器...');  // 调试代码已注释
  Result := DownloadBootstrapCompiler(RequiredVersion);
  if Result then
  begin
    FBootstrapCompiler := GetBootstrapPath(RequiredVersion);
  // WriteLn('✓ Bootstrap编译器下载完成');  // 调试代码已注释
  end;
end;

// Step-by-step build process (FPCUpDeluxe-inspired)
function TFPCSourceManager.InitializeInstall(const AVersion: string): Boolean;
begin
  // WriteLn('正在初始化安装环境...');  // 调试代码已注释
  // Create necessary directories
  ForceDirectories(FSourceRoot);
  ForceDirectories(FSourceRoot + PathDelim + 'bootstrap');
  // WriteLn('✓ 安装环境初始化完成');  // 调试代码已注释
  Result := True;
end;

function TFPCSourceManager.BuildFPCCompiler(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  // WriteLn('正在测试FPC编译器构建...');  // 调试代码已注释
  // WriteLn('使用Bootstrap编译器: ', FBootstrapCompiler);  // 调试代码已注释
  // WriteLn('并行任务数: ', FParallelJobs);  // 调试代码已注释

  // 代理到 BuildManager（目前为占位实现，后续逐步迁移真实逻辑）
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  try
    Result := LBM.BuildCompiler(AVersion);
    WriteLn('Log file: ', LBM.LogFileName);
  finally
    LBM.Free;
  end;

  if Result then
  // WriteLn('✓ FPC编译器构建测试完成')  // 调试代码已注释
  else
  // WriteLn('✗ FPC编译器构建测试失败');  // 调试代码已注释
end;

function TFPCSourceManager.BuildFPCRTL(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  // WriteLn('正在构建FPC RTL (运行时库)...');  // 调试代码已注释
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  try
    Result := LBM.BuildRTL(AVersion);
  finally
    LBM.Free;
  end;
  if Result then
  // WriteLn('✓ FPC RTL构建完成')  // 调试代码已注释
  else
  // WriteLn('✗ FPC RTL构建失败');  // 调试代码已注释
end;

function TFPCSourceManager.BuildFPCPackages(const AVersion: string): Boolean;
begin
  // WriteLn('正在构建FPC包...');  // 调试代码已注释
  // TODO: Implement packages build
  // WriteLn('✓ FPC包构建完成');  // 调试代码已注释
  Result := True;
end;

function TFPCSourceManager.InstallFPCBinaries(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  // WriteLn('正在安装FPC二进制文件...');  // 调试代码已注释
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  try
    Result := LBM.Install(AVersion);
  finally
    LBM.Free;
  end;
  if Result then
  // WriteLn('✓ FPC二进制文件安装完成')  // 调试代码已注释
  else
  // WriteLn('✗ FPC二进制文件安装失败');  // 调试代码已注释
end;

function TFPCSourceManager.ConfigureFPCEnvironment(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  // WriteLn('正在配置FPC环境...');  // 调试代码已注释
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  try
    Result := LBM.Configure(AVersion);
  finally
    LBM.Free;
  end;
  if Result then
  // WriteLn('✓ FPC环境配置完成')  // 调试代码已注释
  else
  // WriteLn('✗ FPC环境配置失败');  // 调试代码已注释
end;

function TFPCSourceManager.TestBuildResults(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  // WriteLn('正在测试构建结果...');  // 调试代码已注释
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  try
    Result := LBM.TestResults(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.ReportBuildStep(const AStep: TFPCBuildStep; const AMessage: string): Boolean;
var
  StepNum: Integer;
  StepName: string;
begin
  case AStep of
    bsInit: begin StepNum := 1; StepName := '初始化'; end;
    bsBootstrap: begin StepNum := 2; StepName := 'Bootstrap'; end;
    bsClone: begin StepNum := 3; StepName := '源码'; end;
    bsCompiler: begin StepNum := 4; StepName := '编译器'; end;
    bsRTL: begin StepNum := 5; StepName := 'RTL'; end;
    bsConfig: begin StepNum := 6; StepName := '测试'; end;
    bsFinished: begin StepNum := 6; StepName := '完成'; end;
    else begin StepNum := 0; StepName := '未知'; end;
  end;

  if AStep <> bsFinished then
  // WriteLn('[', StepNum, '/6] ', AMessage, '...')  // 调试代码已注释
  else
  // WriteLn('✓ ', AMessage);  // 调试代码已注释

  Result := True;
end;

// Performance optimization methods
function TFPCSourceManager.GetOptimalJobCount: Integer;
begin
  // Use environment variable if available
  Result := StrToIntDef(GetEnvironmentVariable('NUMBER_OF_PROCESSORS'), 0);

  // Fallback to reasonable default
  if Result <= 0 then
    Result := 4;

  // Limit to reasonable range
  if Result < 1 then Result := 1;
  if Result > 16 then Result := 16;

  // WriteLn('检测到CPU核心数: ', Result);  // 调试代码已注释
end;

function TFPCSourceManager.IsCacheAvailable(const AVersion: string): Boolean;
var
  CachePath: string;
begin
  CachePath := FSourceRoot + PathDelim + 'cache' + PathDelim + 'fpc-' + AVersion + '.cache';
  Result := FileExists(CachePath);

  if Result then
  // WriteLn('发现缓存: ', CachePath)  // 调试代码已注释
  else
  // WriteLn('无可用缓存');  // 调试代码已注释
end;

function TFPCSourceManager.UseCachedBuild(const AVersion: string): Boolean;
begin
  // TODO: Implement actual cache usage
  // WriteLn('正在从缓存恢复构建...');  // 调试代码已注释
  Result := True; // Simulate success for now
end;

function TFPCSourceManager.OptimizeBuildCommand(const ABaseCommand: string): string;
begin
  Result := ABaseCommand;

  // Add parallel jobs
  if FParallelJobs > 1 then
    Result := Result + ' -j' + IntToStr(FParallelJobs);

  // Add optimization flags
  Result := Result + ' OPT="-O2"';

  // Reduce verbosity if not needed
  if not FVerboseOutput then
    Result := Result + ' VERBOSE=0';

  // WriteLn('优化后的构建命令: ', Result);  // 调试代码已注释
end;

function TFPCSourceManager.CheckBuildPrerequisites(const AVersion: string): Boolean;
begin
  // WriteLn('检查构建前置条件...');  // 调试代码已注释

  // Check if make is available
  if not ExecuteCommand('make', ['--version'], '') then
  begin
  // WriteLn('✗ make工具未找到');  // 调试代码已注释
    Exit(False);
  end;

  // Check if bootstrap compiler is available
  if FBootstrapCompiler = '' then
  begin
  // WriteLn('✗ Bootstrap编译器未设置');  // 调试代码已注释
    Exit(False);
  end;

  // WriteLn('✓ 构建前置条件检查通过');  // 调试代码已注释
  Result := True;
end;

function TFPCSourceManager.IsValidSourceDirectory(const APath: string): Boolean;
var
  CompilerPath, RTLPath, MakefilePath: string;
begin
  Result := False;

  // 检查基本目录结构
  if not DirectoryExists(APath) then
    Exit;

  // 检查关键目录和文件
  CompilerPath := APath + PathDelim + 'compiler';
  RTLPath := APath + PathDelim + 'rtl';
  MakefilePath := APath + PathDelim + 'Makefile';

  // 验证源码目录的完整性
  if DirectoryExists(CompilerPath) and
     DirectoryExists(RTLPath) and
     FileExists(MakefilePath) then
  begin
  // WriteLn('✓ 源码目录验证通过');  // 调试代码已注释
  // WriteLn('  - 编译器目录: ', CompilerPath);  // 调试代码已注释
  // WriteLn('  - RTL目录: ', RTLPath);  // 调试代码已注释
  // WriteLn('  - Makefile: ', MakefilePath);  // 调试代码已注释
    Result := True;
  end
  else
  begin
  // WriteLn('✗ 源码目录验证失败');  // 调试代码已注释
    if not DirectoryExists(CompilerPath) then
  // WriteLn('  - 缺少编译器目录: ', CompilerPath);  // 调试代码已注释
    if not DirectoryExists(RTLPath) then
  // WriteLn('  - 缺少RTL目录: ', RTLPath);  // 调试代码已注释
    if not FileExists(MakefilePath) then
  // WriteLn('  - 缺少Makefile: ', MakefilePath);  // 调试代码已注释
  end;
end;

end.
