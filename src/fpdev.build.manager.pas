unit fpdev.build.manager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.build.config, fpdev.build.logger, fpdev.build.toolchain,
  fpdev.build.cache, fpdev.build.interfaces;

type
  { TBuildManager }
  TBuildManager = class(TInterfacedObject, IBuildManager)
  private
    FSourceRoot: string;
    FParallelJobs: Integer;
    FVerbose: Boolean;
    FSandboxRoot: string;
    FLogDir: string;
    FAllowInstall: Boolean;
    FLastError: string;  // Last error message for IBuildManager interface
    FLogger: TBuildLogger;  // Logger service (Facade delegation)
    FToolchainChecker: TBuildToolchainChecker;  // Toolchain service (Facade delegation)
    FStrictResults: Boolean; // Strict mode for sandbox artifact validation
    FStrictConfigPath: string; // Strict mode config file path (optional)
    FDryRun: Boolean; // Dry run mode: only print commands, don't execute
    FToolchainStrict: Boolean; // Toolchain strict validation (fail blocks build)
    FCurrentStep: TBuildStep; // Current build stage
    // make and target/prefix configuration (optional)
    FMakeCmd: string;              // Custom make command (empty = auto-detect)
    FCPU_TARGET: string;           // Target CPU (optional)
    FOS_TARGET: string;            // Target OS (optional)
    FPREFIX: string;               // Install prefix (optional)
    FINSTALL_PREFIX: string;       // Install prefix (optional)
    // Package selection (Phase 4.3)
    FSelectedPackages: TStringArray; // Selective build package list
    FSkippedPackages: TStringArray;  // Packages to skip
    function GetSourcePath(const AVersion: string): string;
    function HasTool(const AExe: string; const AArgs: array of string): Boolean;
    function ResolveMakeCmd: string;
    function RunMake(const ASourcePath: string; const ATargets: array of string): Boolean;
    procedure Log(const ALine: string);
    procedure EnsureDir(const APath: string);
    function GetLogFileName: string;
    function DirHasAnyFile(const APath: string): Boolean;
    function DirHasAnySubdir(const APath: string): Boolean;
    function HasFileLike(const ADir: string; const APrefixes: array of string; const AExts: array of string): Boolean;
    procedure LogDirSample(const ADir: string; ALimit: Integer);
    procedure LogEnvSnapshot;
    function ApplyStrictConfig(const ASandboxDest: string): Boolean;
    function CanWriteDir(const APath: string): Boolean;
    procedure LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
  public
    constructor Create(const ASourceRoot: string; AParallelJobs: Integer; AVerbose: Boolean);
    destructor Destroy; override;
    procedure SetSandboxRoot(const APath: string);
    procedure SetAllowInstall(AEnable: Boolean);
    procedure SetLogVerbosity(ALevel: Integer);
    procedure SetStrictResults(AEnable: Boolean);
    procedure SetStrictConfigPath(const APath: string);
    procedure SetDryRun(AEnable: Boolean);
    procedure SetToolchainStrict(AEnable: Boolean);
    // Optional configuration
    procedure SetMakeCmd(const ACmd: string);
    procedure SetTarget(const ACpu, AOs: string);
    procedure SetPrefix(const APrefix, AInstallPrefix: string);
    { Apply configuration from TBuildConfig record (consolidates all SetXxx methods) }
    procedure ApplyConfig(const AConfig: TBuildConfig);
    property LogFileName: string read GetLogFileName;
    // 状态查询
    function GetBuildStep: Integer;
    function IsDryRun: Boolean;
    function GetParallelJobs: Integer;
    function GetCurrentStep: TBuildStep;
    // 构建方法
    { IBuildManager interface methods }
    function Preflight: Boolean; overload;  // Interface method (no version parameter)
    function GetLastError: string;
    
    { Legacy methods with version parameter }
    function BuildCompiler(const AVersion: string): Boolean;
    function BuildRTL(const AVersion: string): Boolean;
    function BuildPackages(const AVersion: string): Boolean;
    function InstallPackages(const AVersion: string): Boolean;
    function Install(const AVersion: string): Boolean;
    function Configure(const AVersion: string): Boolean;
    function TestResults(const AVersion: string): Boolean;
    function Preflight(const AVersion: string): Boolean; overload;  // Legacy method
    function FullBuild(const AVersion: string): Boolean;
    // 缓存支持
    procedure CreateBuildStamp(const AVersion: string);
    // 环境体检（纯代码实现，不依赖脚本）
    function CheckToolchain: Boolean;
    // Package selection (Phase 4.3)
    function ListPackages: TStringArray;
    procedure SetSelectedPackages(const APackages: TStringArray);
    function GetSelectedPackageCount: Integer;
    procedure SetSkippedPackages(const APackages: TStringArray);
    function GetSkippedPackageCount: Integer;
    function GetPackageBuildOrder: TStringArray;
  end;

implementation

uses
  Process, IniFiles, DateUtils, StrUtils, fpdev.toolchain;

constructor TBuildManager.Create(const ASourceRoot: string; AParallelJobs: Integer; AVerbose: Boolean);
begin
  inherited Create;
  FSourceRoot := ASourceRoot;
  FParallelJobs := AParallelJobs;
  FVerbose := AVerbose;
  FSandboxRoot := 'sandbox';
  FLogDir := 'logs';
  FAllowInstall := False; // Default: don't install to avoid pollution
  FStrictResults := False;
  FStrictConfigPath := '';
  FDryRun := False;
  FToolchainStrict := False;
  FCurrentStep := bsIdle;
  FMakeCmd := '';
  FCPU_TARGET := '';
  FOS_TARGET := '';
  FPREFIX := '';
  FINSTALL_PREFIX := '';
  // Initialize package selection arrays
  FSelectedPackages := nil;
  FSkippedPackages := nil;

  // Ensure directories exist
  EnsureDir(FSandboxRoot);
  EnsureDir(FLogDir);

  // Initialize logger service
  FLogger := TBuildLogger.Create(FLogDir);

  // Initialize toolchain checker service
  FToolchainChecker := TBuildToolchainChecker.Create(FVerbose);
end;

destructor TBuildManager.Destroy;
begin
  if Assigned(FToolchainChecker) then
    FToolchainChecker.Free;
  if Assigned(FLogger) then
    FLogger.Free;
  inherited Destroy;
end;

procedure TBuildManager.SetSandboxRoot(const APath: string);
begin
  if APath <> '' then FSandboxRoot := APath;
  EnsureDir(FSandboxRoot);
end;

procedure TBuildManager.SetAllowInstall(AEnable: Boolean);
begin
  FAllowInstall := AEnable;
end;

procedure TBuildManager.SetLogVerbosity(ALevel: Integer);
begin
  if ALevel < 0 then ALevel := 0;
  if ALevel > 1 then ALevel := 1;
  FLogger.Verbosity := ALevel;
  Log('LogVerbosity set to ' + IntToStr(ALevel));
end;

procedure TBuildManager.SetStrictResults(AEnable: Boolean);
begin
  FStrictResults := AEnable;
  Log('StrictResults set to ' + BoolToStr(FStrictResults, True));
end;

procedure TBuildManager.SetStrictConfigPath(const APath: string);
begin
  FStrictConfigPath := APath;
  Log('StrictConfigPath set to ' + FStrictConfigPath);
end;

procedure TBuildManager.SetDryRun(AEnable: Boolean);
begin
  FDryRun := AEnable;
  Log('DryRun set to ' + BoolToStr(FDryRun, True));
end;

procedure TBuildManager.SetToolchainStrict(AEnable: Boolean);
begin
  FToolchainStrict := AEnable;
  Log('ToolchainStrict set to ' + BoolToStr(FToolchainStrict, True));
end;

function TBuildManager.DirHasAnyFile(const APath: string): Boolean;
var
  SR: TSearchRec;
begin
  Result := False;
  if not DirectoryExists(APath) then Exit(False);
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*.*', faAnyFile - faDirectory, SR) = 0 then
  begin
    Result := True;
    FindClose(SR);
  end;
end;

function TBuildManager.DirHasAnySubdir(const APath: string): Boolean;
var
  SR: TSearchRec;
begin
  Result := False;
  if not DirectoryExists(APath) then Exit(False);
  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faDirectory, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
      begin
        Result := True;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function TBuildManager.HasFileLike(const ADir: string; const APrefixes: array of string; const AExts: array of string): Boolean;
var
  SR: TSearchRec;
  i, j: Integer;
  LName: string;
begin
  Result := False;
  if not DirectoryExists(ADir) then Exit(False);
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*.*', faAnyFile - faDirectory, SR) = 0 then
  begin
    repeat
      LName := LowerCase(SR.Name);
      for i := Low(APrefixes) to High(APrefixes) do
        for j := Low(AExts) to High(AExts) do
          if (Pos(LowerCase(APrefixes[i]), LName) = 1) and (ExtractFileExt(LName) = LowerCase(AExts[j])) then
          begin
            Result := True;
            Break;
          end;
    until Result or (FindNext(SR) <> 0);
    FindClose(SR);
  end;
end;

procedure TBuildManager.LogDirSample(const ADir: string; ALimit: Integer);
begin
  // Delegate to logger service
  FLogger.LogDirSample(ADir, ALimit);
end;

procedure TBuildManager.LogEnvSnapshot;
begin
  // Delegate to logger service
  FLogger.LogEnvSnapshot;
end;

function TBuildManager.ApplyStrictConfig(const ASandboxDest: string): Boolean;
var
  LIniPath: string;
  Ini: TIniFile;
  LBin, LLib: string;
  LReqPrefix, LReqExt: TStringList;
  LMinCountBin, LMinCountLib: Integer;
  LRequireSubdir: Boolean;
  // added non-inline locals
  LDemoPath: string;
  LSandboxCfg: string;
  LShareRequired: Boolean;
  LShareMin: Integer;
  LShareRequireSubdir: Boolean;
  LShareReqSub: string;
  LShare: string;
  LHasCfg: Boolean;
  LRequireCfg: Boolean;
  LCfgFound: string;
  k: Integer;
  SR: TSearchRec;
  LCfgList: TStringList;
  LRel, LFull: string;
  LIncRel: string;
  LIncRequired: Boolean;
  LIncMin: Integer;
  LIncRequireSubdir: Boolean;
  LIncReqSub: string;
  LIncDir: string;
  LDocRel: string;
  LDocRequired: Boolean;
  LDocMin: Integer;
  LDocRequireSubdir: Boolean;
  LDocReqSub: string;
  LDocDir: string;
  function ReadCSV(const S: string): TStringList;
  var L: TStringList;
  begin
    L := TStringList.Create;
    L.Delimiter := ',';
    L.StrictDelimiter := True;
    L.DelimitedText := StringReplace(S, ' ', '', [rfReplaceAll]);
    Result := L;
  end;
begin
  Result := True;
  // Resolve strict config path with first-match priority
  LIniPath := '';
  if (FStrictConfigPath <> '') and FileExists(FStrictConfigPath) then
    LIniPath := FStrictConfigPath;
  if (LIniPath = '') then
  begin
    if FileExists('build-manager.strict.ini') then
      LIniPath := 'build-manager.strict.ini';
  end;
  if (LIniPath = '') then
  begin
    LDemoPath := IncludeTrailingPathDelimiter('plays') + 'fpdev.build.manager.demo' + PathDelim + 'build-manager.strict.ini';
    if FileExists(LDemoPath) then
      LIniPath := LDemoPath;
  end;
  if (LIniPath = '') then
  begin
    LSandboxCfg := IncludeTrailingPathDelimiter(ASandboxDest) + 'build-manager.strict.ini';
    if FileExists(LSandboxCfg) then
      LIniPath := LSandboxCfg;
  end;
  if (LIniPath = '') then Exit(True);
  Log('Strict config detected: ' + LIniPath);
  Ini := TIniFile.Create(LIniPath);
  LReqPrefix := nil; LReqExt := nil;
  try
    LBin := IncludeTrailingPathDelimiter(ASandboxDest) + 'bin';
    LLib := IncludeTrailingPathDelimiter(ASandboxDest) + 'lib';
    // bin 规则
    LMinCountBin := Ini.ReadInteger('bin', 'min_count', 1);
    LReqPrefix := ReadCSV(Ini.ReadString('bin', 'required_prefix', 'fpc,ppc'));
    LReqExt := ReadCSV(Ini.ReadString('bin', 'required_ext', '.exe,.sh,'));
    if DirectoryExists(LBin) then
    begin
      if LMinCountBin > 0 then
      begin
        if not DirHasAnyFile(LBin) then begin Log('FAIL: [bin] no files'); Exit(False); end;
      end;
      if not HasFileLike(LBin, LReqPrefix.ToStringArray, LReqExt.ToStringArray) then
      begin
        Log('FAIL: [bin] missing required executable (prefix/ext)');
        if FLogger.Verbosity > 0 then
        begin
          Log('hint: [bin] required_prefix=' + StringReplace(Ini.ReadString('bin','required_prefix','fpc,ppc'), ' ', '', [rfReplaceAll]));
          Log('hint: [bin] required_ext=' + StringReplace(Ini.ReadString('bin','required_ext','.exe,.sh,'), ' ', '', [rfReplaceAll]));
          Log('hint: [bin] sample:');
          LogDirSample(LBin, 20);
        end;
        Exit(False);
      end;
    end
    else begin Log('FAIL: [bin] directory not found: ' + LBin); Exit(False); end;
    // lib 规则
    LMinCountLib := Ini.ReadInteger('lib', 'min_count', 1);
    LRequireSubdir := Ini.ReadBool('lib', 'require_subdir', True);
    if DirectoryExists(LLib) then
    begin
      if LMinCountLib > 0 then
      begin
        if not DirHasAnyFile(LLib) then
        begin
          Log('FAIL: [lib] no files');
          if FLogger.Verbosity > 0 then begin Log('hint: [lib] sample:'); LogDirSample(LLib, 20); end;
          Exit(False);
        end;
      end;
      if LRequireSubdir and (not DirHasAnySubdir(LLib)) then
      begin
        Log('FAIL: [lib] require_subdir but none found');
        if FLogger.Verbosity > 0 then begin Log('hint: [lib] expected a subdirectory (e.g. fpc/<ver>)'); LogDirSample(LLib, 20); end;
        Exit(False);
      end;
    end
    else begin Log('FAIL: [lib] directory not found: ' + LLib); Exit(False); end;

    // share 规则（可选）
    LShareRequired := Ini.ReadBool('share', 'required', False);
    LShareMin := Ini.ReadInteger('share', 'min_count', 0);
    LShareRequireSubdir := Ini.ReadBool('share', 'require_subdir', False);
    LShareReqSub := Ini.ReadString('share', 'required_subdir', '');
    LShare := IncludeTrailingPathDelimiter(ASandboxDest) + 'share';
    if LShareRequired then
    begin
      if not DirectoryExists(LShare) then begin Log('FAIL: [share] directory not found: ' + LShare); if FLogger.Verbosity > 0 then Log('hint: [share] expected dir: ' + LShare); Exit(False); end;
      if (LShareMin > 0) and (not DirHasAnyFile(LShare)) then begin Log('FAIL: [share] no files'); if FLogger.Verbosity > 0 then begin Log('hint: [share] sample:'); LogDirSample(LShare, 20); end; Exit(False); end;
      if LShareRequireSubdir and (not DirHasAnySubdir(LShare)) then begin Log('FAIL: [share] require_subdir but none found'); if FLogger.Verbosity > 0 then begin Log('hint: [share] expected child dirs'); LogDirSample(LShare, 20); end; Exit(False); end;
      if (LShareReqSub <> '') and (not DirectoryExists(IncludeTrailingPathDelimiter(LShare) + LShareReqSub)) then begin Log('FAIL: [share] required_subdir missing: ' + LShareReqSub); if FLogger.Verbosity > 0 then Log('hint: [share] expected subdir: ' + LShareReqSub); Exit(False); end;
    end
    else
    begin
      if DirectoryExists(LShare) and (FLogger.Verbosity > 0) then Log('info: [share] present but not required');
    end;

    // fpc.cfg 规则（可选）
    LRequireCfg := Ini.ReadBool('fpc', 'require_cfg', False);
    LCfgList := ReadCSV(Ini.ReadString('fpc', 'cfg_relative_list', 'etc/fpc.cfg,lib/fpc/fpc.cfg'));
    if LRequireCfg then
    begin
      LHasCfg := False;
      LCfgFound := '';
      for k := 0 to LCfgList.Count-1 do
      begin
        LRel := StringReplace(LCfgList[k], '/', PathDelim, [rfReplaceAll]);
        LFull := IncludeTrailingPathDelimiter(ASandboxDest) + LRel;
        if FileExists(LFull) then begin LHasCfg := True; LCfgFound := LFull; Break; end;
      end;
      if not LHasCfg then begin Log('FAIL: [fpc] missing fpc.cfg in cfg_relative_list'); if FLogger.Verbosity > 0 then begin Log('hint: [fpc] tried list=' + Ini.ReadString('fpc','cfg_relative_list','etc/fpc.cfg,lib/fpc/fpc.cfg')); Log('hint: [fpc] root=' + ASandboxDest); end; Exit(False); end;
      // 轻量内容检查：要求 fpc.cfg 非空
      if LCfgFound <> '' then
      begin
        if FindFirst(LCfgFound, faAnyFile, SR) = 0 then
        begin
          try
            if SR.Size <= 0 then begin Log('FAIL: [fpc] fpc.cfg is empty: ' + LCfgFound); Exit(False); end;
          finally
            FindClose(SR);
          end;
        end;
      end;
    end;

    // include 规则（可选，可配置相对目录）
    LIncRel := Ini.ReadString('include', 'relative_dir', 'include');
    LIncRequired := Ini.ReadBool('include', 'required', False);
    LIncMin := Ini.ReadInteger('include', 'min_count', 0);
    LIncRequireSubdir := Ini.ReadBool('include', 'require_subdir', False);
    LIncReqSub := Ini.ReadString('include', 'required_subdir', '');
    LIncDir := IncludeTrailingPathDelimiter(ASandboxDest) + StringReplace(LIncRel, '/', PathDelim, [rfReplaceAll]);
    if LIncRequired then
    begin
      if not DirectoryExists(LIncDir) then begin Log('FAIL: [include] directory not found: ' + LIncDir); if FLogger.Verbosity > 0 then Log('hint: [include] expected dir: ' + LIncDir); Exit(False); end;
      if (LIncMin > 0) and (not DirHasAnyFile(LIncDir)) then begin Log('FAIL: [include] no files'); if FLogger.Verbosity > 0 then begin Log('hint: [include] sample:'); LogDirSample(LIncDir, 20); end; Exit(False); end;
      if LIncRequireSubdir and (not DirHasAnySubdir(LIncDir)) then begin Log('FAIL: [include] require_subdir but none found'); if FLogger.Verbosity > 0 then begin Log('hint: [include] expected child dirs'); LogDirSample(LIncDir, 20); end; Exit(False); end;
      if (LIncReqSub <> '') and (not DirectoryExists(IncludeTrailingPathDelimiter(LIncDir) + LIncReqSub)) then begin Log('FAIL: [include] required_subdir missing: ' + LIncReqSub); if FLogger.Verbosity > 0 then Log('hint: [include] expected subdir: ' + LIncReqSub); Exit(False); end;
    end
    else
    begin
      if DirectoryExists(LIncDir) and (FLogger.Verbosity > 0) then Log('info: [include] present but not required');
    end;

    // doc 规则（可选，可配置相对目录）
    LDocRel := Ini.ReadString('doc', 'relative_dir', 'doc');
    LDocRequired := Ini.ReadBool('doc', 'required', False);
    LDocMin := Ini.ReadInteger('doc', 'min_count', 0);
    LDocRequireSubdir := Ini.ReadBool('doc', 'require_subdir', False);
    LDocReqSub := Ini.ReadString('doc', 'required_subdir', '');
    LDocDir := IncludeTrailingPathDelimiter(ASandboxDest) + StringReplace(LDocRel, '/', PathDelim, [rfReplaceAll]);
    if LDocRequired then
    begin
      if not DirectoryExists(LDocDir) then begin Log('FAIL: [doc] directory not found: ' + LDocDir); if FLogger.Verbosity > 0 then Log('hint: [doc] expected dir: ' + LDocDir); Exit(False); end;
      if (LDocMin > 0) and (not DirHasAnyFile(LDocDir)) then begin Log('FAIL: [doc] no files'); if FLogger.Verbosity > 0 then begin Log('hint: [doc] sample:'); LogDirSample(LDocDir, 20); end; Exit(False); end;
      if LDocRequireSubdir and (not DirHasAnySubdir(LDocDir)) then begin Log('FAIL: [doc] require_subdir but none found'); if FLogger.Verbosity > 0 then begin Log('hint: [doc] expected child dirs'); LogDirSample(LDocDir, 20); end; Exit(False); end;
      if (LDocReqSub <> '') and (not DirectoryExists(IncludeTrailingPathDelimiter(LDocDir) + LDocReqSub)) then begin Log('FAIL: [doc] required_subdir missing: ' + LDocReqSub); if FLogger.Verbosity > 0 then Log('hint: [doc] expected subdir: ' + LDocReqSub); Exit(False); end;
    end
    else
    begin
      if DirectoryExists(LDocDir) and (FLogger.Verbosity > 0) then Log('info: [doc] present but not required');
    end;
  finally
    if Assigned(LReqPrefix) then LReqPrefix.Free;
    if Assigned(LReqExt) then LReqExt.Free;
    Ini.Free;
  end;
end;

function TBuildManager.GetSourcePath(const AVersion: string): string;
var
  LVersion: string;
begin
  LVersion := AVersion;
  if LVersion = '' then LVersion := 'main';
  Result := IncludeTrailingPathDelimiter(FSourceRoot) + 'fpc-' + LVersion;
end;

function TBuildManager.CanWriteDir(const APath: string): Boolean;
var
  LTest: string;
  F: TextFile;
begin
  Result := False;
  if not DirectoryExists(APath) then Exit(False);
  LTest := IncludeTrailingPathDelimiter(APath) + '.write_test.tmp';
  try
    AssignFile(F, LTest);
    Rewrite(F);
    WriteLn(F, 'ok');
    CloseFile(F);
    Result := True;
  except
    on E: Exception do
    begin
      Log('cannot write to dir: ' + APath + ' err=' + E.Message);
      Result := False;
    end;
  end;
  if FileExists(LTest) then DeleteFile(LTest);
end;

procedure TBuildManager.LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
begin
  Log('Summary: version=' + AVersion + ' context=' + AContext + ' result=' + AResult + ' elapsed_ms=' + IntToStr(AElapsedMs));
end;

function TBuildManager.CheckToolchain: Boolean;
var
  LIssues: TStringList;
  LStart: TDateTime;
  Ok: Boolean;
  Line: string;
  i: Integer;
  LRes: string;
  function Check(const ACmd, AProbeArg: string; out AOk: Boolean; out ALine: string): Boolean;
  var ExitCode: Integer;
  begin
    try
      if AProbeArg <> '' then ExitCode := ExecuteProcess(ACmd, [AProbeArg])
      else ExitCode := ExecuteProcess(ACmd, []);
      AOk := (ExitCode = 0);
    except
      AOk := False;
    end;
    if AOk then ALine := '[ OK ] ' + ACmd else ALine := '[MISS] ' + ACmd;
    Result := AOk;
  end;
begin
  LStart := Now;
  LIssues := TStringList.Create;
  try
    Log('== Toolchain Check START');
    // 按平台尝试若干常见工具
    Ok := False; Line := '';
    // 构建工具
    Check('fpc','-iV', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    Check('lazbuild','--version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    // make 族
    {$IFDEF MSWINDOWS}
    if not Check('mingw32-make','--version', Ok, Line) then
      if not Check('make','--version', Ok, Line) then
        if not Check('gmake','--version', Ok, Line) then LIssues.Add('[MISS] make-family');
    {$ELSE}
    if not Check('gmake','--version', Ok, Line) then
      if not Check('make','--version', Ok, Line) then LIssues.Add('[MISS] make-family');
    {$ENDIF}
    // 版本控制/SSL（可选）
    Check('git','--version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    Check('openssl','version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    // 各平台编译器前端（可选）
    Check('ppc386','', Ok, Line); if not Ok then if FLogger.Verbosity>0 then Log(Line);
    Check('ppcx64','', Ok, Line); if not Ok then if FLogger.Verbosity>0 then Log(Line);
    Check('ppcarm','', Ok, Line); if not Ok then if FLogger.Verbosity>0 then Log(Line);
    Result := (LIssues.Count = 0);
    if Result then Log('== Toolchain Check END OK') else
    begin
      Log('== Toolchain Check END FAIL issues=' + IntToStr(LIssues.Count));
      if FLogger.Verbosity>0 then
      begin
        for i:=0 to LIssues.Count-1 do Log('issue: ' + LIssues[i]);
      end;
    end;
    if Result then LRes := 'OK' else LRes := 'FAIL';
    LogTestSummary('n/a','toolchain', LRes, MilliSecondsBetween(Now, LStart));
  finally
    LIssues.Free;
  end;
end;

function TBuildManager.HasTool(const AExe: string; const AArgs: array of string): Boolean;
begin
  // Delegate to toolchain checker service
  Result := FToolchainChecker.HasTool(AExe, AArgs);
end;

function TBuildManager.ResolveMakeCmd: string;
begin
  // Custom make command takes priority
  if FMakeCmd <> '' then
    Exit(FMakeCmd);

  // Windows: try mingw32-make first
  {$IFDEF MSWINDOWS}
  if FToolchainChecker.HasTool('mingw32-make', ['--version']) then
    Exit('mingw32-make');
  {$ENDIF}

  // Delegate to toolchain checker for gmake/make detection
  Result := FToolchainChecker.ResolveMakeCmd;
end;

procedure TBuildManager.SetMakeCmd(const ACmd: string);
begin
  FMakeCmd := Trim(ACmd);
end;

procedure TBuildManager.SetTarget(const ACpu, AOs: string);
begin
  FCPU_TARGET := Trim(ACpu);
  FOS_TARGET := Trim(AOs);
end;

procedure TBuildManager.SetPrefix(const APrefix, AInstallPrefix: string);
begin
  FPREFIX := Trim(APrefix);
  FINSTALL_PREFIX := Trim(AInstallPrefix);
end;

procedure TBuildManager.ApplyConfig(const AConfig: TBuildConfig);
var
  I: Integer;
begin
  // Apply execution configuration
  if AConfig.SourceRoot <> '' then
    FSourceRoot := AConfig.SourceRoot;
  if AConfig.SandboxRoot <> '' then
    FSandboxRoot := AConfig.SandboxRoot;
  if AConfig.LogDir <> '' then
    FLogDir := AConfig.LogDir;
  FParallelJobs := AConfig.ParallelJobs;
  FVerbose := AConfig.Verbose;

  // Apply control flags
  FAllowInstall := AConfig.AllowInstall;
  FDryRun := AConfig.DryRun;

  // Apply validation configuration
  FStrictResults := AConfig.StrictResults;
  FStrictConfigPath := AConfig.StrictConfigPath;
  FToolchainStrict := AConfig.ToolchainStrict;
  FLogger.Verbosity := AConfig.LogVerbosity;

  // Apply make configuration
  FMakeCmd := AConfig.MakeCmd;
  FCPU_TARGET := AConfig.CpuTarget;
  FOS_TARGET := AConfig.OsTarget;
  FPREFIX := AConfig.Prefix;
  FINSTALL_PREFIX := AConfig.InstallPrefix;

  // Apply package selection
  if Length(AConfig.SelectedPackages) > 0 then
  begin
    SetLength(FSelectedPackages, Length(AConfig.SelectedPackages));
    for I := 0 to High(AConfig.SelectedPackages) do
      FSelectedPackages[I] := AConfig.SelectedPackages[I];
  end;

  if Length(AConfig.SkippedPackages) > 0 then
  begin
    SetLength(FSkippedPackages, Length(AConfig.SkippedPackages));
    for I := 0 to High(AConfig.SkippedPackages) do
      FSkippedPackages[I] := AConfig.SkippedPackages[I];
  end;

  // Ensure directories exist
  EnsureDir(FSandboxRoot);
  EnsureDir(FLogDir);

  Log('Configuration applied from TBuildConfig');
end;

function TBuildManager.GetBuildStep: Integer;
begin
  Result := Ord(FCurrentStep);
end;

function TBuildManager.IsDryRun: Boolean;
begin
  Result := FDryRun;
end;

function TBuildManager.GetParallelJobs: Integer;
begin
  Result := FParallelJobs;
end;

function TBuildManager.GetCurrentStep: TBuildStep;
begin
  Result := FCurrentStep;
end;

procedure TBuildManager.Log(const ALine: string);
begin
  // Delegate to logger service
  FLogger.Log(ALine);
end;

function TBuildManager.GetLogFileName: string;
begin
  // Delegate to logger service
  Result := FLogger.LogFileName;
end;

procedure TBuildManager.EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

function TBuildManager.RunMake(const ASourcePath: string; const ATargets: array of string): Boolean;
var
  LArgs: array of string;
  i, LIdx: Integer;
  LJobs: string;
  LMake: string;
  LMakeVer: Integer;
begin
  Result := False;
  LArgs := nil;
  if not DirectoryExists(ASourcePath) then Exit(False);
  // 解析 make 命令（去除内联变量）
  LMake := ResolveMakeCmd;
  LMakeVer := ExecuteProcess(LMake, ['--version']);
  if LMakeVer <> 0 then
  begin
    Log('Make not detected (' + LMake + '), skipping actual build');
    Exit(True); // Safe: do not block subsequent processes
  end;
  // 组合参数：-C <dir> -jN <targets>
  if FParallelJobs <= 0 then FParallelJobs := 1;
  if FParallelJobs > 16 then FParallelJobs := 16;
  LJobs := IntToStr(FParallelJobs);
  // 预留 额外变量位：CPU_TARGET/OS_TARGET/PREFIX/INSTALL_PREFIX
  SetLength(LArgs, 2 + 2 + 4 + Length(ATargets));
  LArgs[0] := '-C'; LArgs[1] := ASourcePath;
  LArgs[2] := '-j' + LJobs;
  LIdx := 3;
  if FCPU_TARGET <> '' then begin LArgs[LIdx] := 'CPU_TARGET=' + FCPU_TARGET; Inc(LIdx); end;
  if FOS_TARGET <> '' then begin LArgs[LIdx] := 'OS_TARGET=' + FOS_TARGET; Inc(LIdx); end;
  // PREFIX/INSTALL_PREFIX 如设置则带入（Install 时仍会显式覆盖）
  if FPREFIX <> '' then begin LArgs[LIdx] := 'PREFIX=' + FPREFIX; Inc(LIdx); end;
  if FINSTALL_PREFIX <> '' then begin LArgs[LIdx] := 'INSTALL_PREFIX=' + FINSTALL_PREFIX; Inc(LIdx); end;
  for i := Low(ATargets) to High(ATargets) do
  begin
    LArgs[LIdx] := ATargets[i];
    Inc(LIdx);
  end;
  if FVerbose then
  begin
    SetLength(LArgs, Length(LArgs) + 2);
    LArgs[High(LArgs)-1] := 'VERBOSE=1';
    LArgs[High(LArgs)] := 'OPT="-O2"';
  end;
  if FLogger.Verbosity > 0 then Log('make ' + String.Join(' ', LArgs));
  if FDryRun then
  begin
    Log('dry-run: skipped make execution');
    Exit(True);
  end;
  Result := ExecuteProcess(ResolveMakeCmd, LArgs) = 0;
end;

function TBuildManager.BuildCompiler(const AVersion: string): Boolean;
var
  LSrc: string;
  LStart: TDateTime;
  LMs: Integer;
begin
  FCurrentStep := bsCompiler;
  LSrc := GetSourcePath(AVersion);
  Log('== BuildCompiler START version=' + AVersion + ' src=' + LSrc);
  if FLogger.Verbosity > 0 then LogEnvSnapshot;
  LStart := Now;
  Result := RunMake(LSrc, ['clean','compiler']);
  LMs := MilliSecondsBetween(Now, LStart);
  if Result then Log('== BuildCompiler END OK elapsed_ms=' + IntToStr(LMs)) else Log('== BuildCompiler END FAIL elapsed_ms=' + IntToStr(LMs));
end;

function TBuildManager.BuildRTL(const AVersion: string): Boolean;
var
  LSrc: string;
  LStart: TDateTime;
  LMs: Integer;
begin
  FCurrentStep := bsRTL;
  LSrc := GetSourcePath(AVersion);
  Log('== BuildRTL START version=' + AVersion + ' src=' + LSrc);
  if FLogger.Verbosity > 0 then LogEnvSnapshot;
  LStart := Now;
  Result := RunMake(LSrc, ['rtl']);
  LMs := MilliSecondsBetween(Now, LStart);
  if Result then Log('== BuildRTL END OK elapsed_ms=' + IntToStr(LMs)) else Log('== BuildRTL END FAIL elapsed_ms=' + IntToStr(LMs));
end;

function TBuildManager.BuildPackages(const AVersion: string): Boolean;
var
  LSrc: string;
  LStart: TDateTime;
  LMs: Integer;
begin
  FCurrentStep := bsPackages;
  LSrc := GetSourcePath(AVersion);
  Log('== BuildPackages START version=' + AVersion + ' src=' + LSrc);
  if FLogger.Verbosity > 0 then LogEnvSnapshot;
  LStart := Now;
  Result := RunMake(LSrc, ['packages']);
  LMs := MilliSecondsBetween(Now, LStart);
  if Result then
    Log('== BuildPackages END OK elapsed_ms=' + IntToStr(LMs))
  else
    Log('== BuildPackages END FAIL elapsed_ms=' + IntToStr(LMs));
end;

function TBuildManager.InstallPackages(const AVersion: string): Boolean;
var
  LSrc, LDest: string;
  LStart: TDateTime;
  LMs: Integer;
begin
  FCurrentStep := bsPackagesInstall;
  if not FAllowInstall then
  begin
    Log('InstallPackages skipped (FAllowInstall=False)');
    Exit(True);
  end;
  LSrc := GetSourcePath(AVersion);
  LDest := IncludeTrailingPathDelimiter(FSandboxRoot) + 'fpc-' + AVersion;
  EnsureDir(LDest);
  Log('== InstallPackages START version=' + AVersion + ' src=' + LSrc + ' dest=' + LDest);
  if FLogger.Verbosity > 0 then LogEnvSnapshot;
  LStart := Now;
  // 使用动态路径替换: INSTALL_UNITDIR=$$(packagename)
  Result := RunMake(LSrc, [
    'DESTDIR=' + LDest,
    'PREFIX=' + LDest,
    'INSTALL_PREFIX=' + LDest,
    'INSTALL_UNITDIR=' + LDest + PathDelim + 'units' + PathDelim + '$$(packagename)',
    'packages_install'
  ]);
  LMs := MilliSecondsBetween(Now, LStart);
  if Result then
    Log('== InstallPackages END OK elapsed_ms=' + IntToStr(LMs))
  else
    Log('== InstallPackages END FAIL elapsed_ms=' + IntToStr(LMs));
end;

function TBuildManager.Install(const AVersion: string): Boolean;
var
  LSrc, LDest: string;
  LStart: TDateTime;
  LMs: Integer;
begin
  if not FAllowInstall then
  begin
    Log('Install 被禁止（FAllowInstall=False），跳过');
    Exit(True);
  end;
  LSrc := GetSourcePath(AVersion);
  LDest := IncludeTrailingPathDelimiter(FSandboxRoot) + 'fpc-' + AVersion;
  EnsureDir(LDest);
  Log('== Install START version=' + AVersion + ' src=' + LSrc + ' dest=' + LDest);
  if FLogger.Verbosity > 0 then LogEnvSnapshot;
  LStart := Now;
  // 将安装目标定向到沙箱（尝试常见变量：DESTDIR/PREFIX），具体支持取决于上游 Makefile
  Result := RunMake(LSrc, ['DESTDIR=' + LDest, 'PREFIX=' + LDest, 'INSTALL_PREFIX=' + LDest, 'install']);
  LMs := MilliSecondsBetween(Now, LStart);
  if Result then Log('== Install END OK elapsed_ms=' + IntToStr(LMs)) else Log('== Install END FAIL elapsed_ms=' + IntToStr(LMs));
end;

function TBuildManager.Configure(const AVersion: string): Boolean;
begin
  // AVersion parameter reserved for future use
  // Configuration typically writes fpc.cfg, not touching system directories at this stage
  Result := True;
end;

function TBuildManager.TestResults(const AVersion: string): Boolean;
var
  LSrc, LCompilerPath, LRTLPath: string;
  LDest, LBin, LLib: string;
  LStart: TDateTime;
begin
  // 优先校验沙箱安装（仅在允许安装时）
  if FAllowInstall then
  begin
    // 耗时统计：去除内联变量
    LStart := Now;
    LDest := IncludeTrailingPathDelimiter(FSandboxRoot) + 'fpc-' + AVersion;
    LBin := IncludeTrailingPathDelimiter(LDest) + 'bin';
    LLib := IncludeTrailingPathDelimiter(LDest) + 'lib';
    if not DirectoryExists(LDest) then
    begin
      Log('TestResults: sandbox root missing: ' + LDest);
      LogTestSummary(AVersion, 'sandbox', 'FAIL', MilliSecondsBetween(Now, LStart));
      Exit(False);
    end;
    if (not DirectoryExists(LBin)) and (not DirectoryExists(LLib)) then
    begin
      Log('TestResults: sandbox missing bin/lib under: ' + LDest);
      LogTestSummary(AVersion, 'sandbox', 'FAIL', MilliSecondsBetween(Now, LStart));
      Exit(False);
    end;
    // Verbose: 输出目录样本，便于排查
    if FLogger.Verbosity > 0 then
    begin
      if DirectoryExists(LBin) then begin Log('sample of sandbox/bin:'); LogDirSample(LBin, 10); end;
      if DirectoryExists(LLib) then begin Log('sample of sandbox/lib:'); LogDirSample(LLib, 10); end;
    end;
    // 细化：若 bin 存在但为空，或 lib 存在但为空
    if DirectoryExists(LBin) and (not DirHasAnyFile(LBin)) then
    begin
      if FStrictResults then begin Log('FAIL: sandbox bin empty under strict mode: ' + LBin); LogTestSummary(AVersion, 'sandbox/bin', 'FAIL', MilliSecondsBetween(Now, LStart)); Exit(False); end
      else Log('WARN: sandbox bin is empty: ' + LBin);
    end;
    if DirectoryExists(LLib) and (not DirHasAnyFile(LLib)) then
    begin
      if FStrictResults then begin Log('FAIL: sandbox lib empty under strict mode: ' + LLib); LogTestSummary(AVersion, 'sandbox/lib', 'FAIL', MilliSecondsBetween(Now, LStart)); Exit(False); end
      else Log('WARN: sandbox lib is empty: ' + LLib);
    end;
    // 若存在严格模式配置，按清单执行进一步校验
    if FStrictResults then
    begin
      if not ApplyStrictConfig(LDest) then begin LogTestSummary(AVersion, 'sandbox/strict', 'FAIL', MilliSecondsBetween(Now, LStart)); Exit(False); end;
    end;
    Log('TestResults: sandbox OK at ' + LDest);
    LogTestSummary(AVersion, 'sandbox', 'OK', MilliSecondsBetween(Now, LStart));
    Exit(True);
  end;

  // 回退：校验源码树的关键目录（占位）
  LSrc := GetSourcePath(AVersion);
  LCompilerPath := LSrc + PathDelim + 'compiler';
  LRTLPath := LSrc + PathDelim + 'rtl';
  if not DirectoryExists(LCompilerPath) then begin Log('TestResults: missing compiler dir: ' + LCompilerPath); Exit(False); end;
  if not DirectoryExists(LRTLPath) then begin Log('TestResults: missing rtl dir: ' + LRTLPath); Exit(False); end;
  Log('TestResults: source tree OK at ' + LSrc);
  Result := True;
end;

function TBuildManager.Preflight(const AVersion: string): Boolean;
var
  LSrc, LDestRoot: string;
  LIssues: TStringList;
  LHasMake, LSrcOk, LSandOk, LLogOk: Boolean;
  LJson: string;
  LStatus, LReason, LMin, LRec, LFpcVer: string;
  LStart: TDateTime;
  i: integer;
begin
  FCurrentStep := bsPreflight;
  LStart := Now;
  Log('== Preflight START version=' + AVersion + ' srcRoot=' + FSourceRoot + ' sandbox=' + FSandboxRoot + ' logDir=' + FLogDir);
  if FLogger.Verbosity > 0 then LogEnvSnapshot;
  LIssues := TStringList.Create;
  try
    // 源码路径检查
    LSrc := GetSourcePath(AVersion);
    LSrcOk := DirectoryExists(LSrc);
    if not LSrcOk then LIssues.Add('source not found: ' + LSrc);

    // 工具链严格校验（可选）
    if FToolchainStrict then
    begin
      // 先做 FPC 版本策略校验：不满足直接加入问题
      if not CheckFPCVersionPolicy(AVersion, LStatus, LReason, LMin, LRec, LFpcVer) then
        LIssues.Add(Format('fpc policy FAIL: src=%s current=%s min=%s rec=%s reason=%s',[AVersion, LFpcVer, LMin, LRec, LReason]))
      else if (LStatus <> 'OK') and (FLogger.Verbosity > 0) then
        Log(Format('fpc policy %s: current=%s min=%s rec=%s',[LStatus, LFpcVer, LMin, LRec]));

      // 再做 HostReady 工具链体检
      LJson := BuildToolchainReportJSON; // 仅构建 JSON；若要写文件，可在外层处理
      if Pos('"level":"FAIL"', LJson) > 0 then
        LIssues.Add('toolchain check failed');
    end
    else
    begin
      // 宽松：仅检查 make 存在
      LHasMake := HasTool('make', ['--version']);
      if not LHasMake then LIssues.Add('make not available');
    end;

    // 目标与日志目录可写
    EnsureDir(FSandboxRoot);
    EnsureDir(FLogDir);
    LSandOk := CanWriteDir(FSandboxRoot);
    if not LSandOk then LIssues.Add('sandbox not writable: ' + FSandboxRoot);
    LLogOk := CanWriteDir(FLogDir);
    if not LLogOk then LIssues.Add('logs not writable: ' + FLogDir);

    // 若允许安装，进一步检查版本安装根是否可创建
    if FAllowInstall then
    begin
      LDestRoot := IncludeTrailingPathDelimiter(FSandboxRoot) + 'fpc-' + AVersion;
      if not DirectoryExists(LDestRoot) then
      begin
        EnsureDir(LDestRoot);
        if not DirectoryExists(LDestRoot) then
          LIssues.Add('cannot create sandbox dest: ' + LDestRoot)
        else if not CanWriteDir(LDestRoot) then
          LIssues.Add('sandbox dest not writable: ' + LDestRoot);
      end
      else if not CanWriteDir(LDestRoot) then
        LIssues.Add('sandbox dest not writable: ' + LDestRoot);
    end;

    // 结果
    Result := (LIssues.Count = 0);
    if Result then
    begin
      Log('== Preflight END OK');
      LogTestSummary(AVersion, 'preflight', 'OK', MilliSecondsBetween(Now, LStart));
    end
    else
    begin
      // 输出所有问题
      Log('== Preflight END FAIL issues=' + IntToStr(LIssues.Count));
      if FLogger.Verbosity > 0 then
      begin
        for i := 0 to LIssues.Count-1 do Log('issue: ' + LIssues[i]);
      end;
      LogTestSummary(AVersion, 'preflight', 'FAIL', MilliSecondsBetween(Now, LStart));
    end;
  finally
    LIssues.Free;
  end;
end;

function TBuildManager.FullBuild(const AVersion: string): Boolean;
var
  LStart: TDateTime;
  LMs: Integer;
begin
  LStart := Now;
  Log('== FullBuild START version=' + AVersion);

  // 1. Preflight
  if not Preflight(AVersion) then
  begin
    Log('== FullBuild ABORT at Preflight');
    FCurrentStep := bsIdle;
    Exit(False);
  end;

  // 2. Build Compiler
  if not BuildCompiler(AVersion) then
  begin
    Log('== FullBuild ABORT at BuildCompiler');
    FCurrentStep := bsIdle;
    Exit(False);
  end;

  // 3. Install Compiler (via Install for now)
  FCurrentStep := bsCompilerInstall;

  // 4. Build RTL
  if not BuildRTL(AVersion) then
  begin
    Log('== FullBuild ABORT at BuildRTL');
    FCurrentStep := bsIdle;
    Exit(False);
  end;

  // 5. Install RTL (via Install for now)
  FCurrentStep := bsRTLInstall;

  // 6. Build Packages
  if not BuildPackages(AVersion) then
  begin
    Log('== FullBuild ABORT at BuildPackages');
    FCurrentStep := bsIdle;
    Exit(False);
  end;

  // 7. Install Packages
  if not InstallPackages(AVersion) then
  begin
    Log('== FullBuild ABORT at InstallPackages');
    FCurrentStep := bsIdle;
    Exit(False);
  end;

  // 8. Install (final)
  if not Install(AVersion) then
  begin
    Log('== FullBuild ABORT at Install');
    FCurrentStep := bsIdle;
    Exit(False);
  end;

  // 9. Verify
  FCurrentStep := bsVerify;
  if not TestResults(AVersion) then
  begin
    Log('== FullBuild ABORT at TestResults');
    FCurrentStep := bsIdle;
    Exit(False);
  end;

  // 10. Complete
  FCurrentStep := bsComplete;
  LMs := MilliSecondsBetween(Now, LStart);
  Log('== FullBuild END OK elapsed_ms=' + IntToStr(LMs));
  LogTestSummary(AVersion, 'fullbuild', 'OK', LMs);
  Result := True;
end;

procedure TBuildManager.CreateBuildStamp(const AVersion: string);
var
  StampFile: string;
  F: TextFile;
  LCpu, LOs: string;
begin
  {$IFDEF CPUX86_64}
  LCpu := 'x86_64';
  {$ELSE}
  {$IFDEF CPUI386}
  LCpu := 'i386';
  {$ELSE}
  {$IFDEF CPUARM}
  LCpu := 'arm';
  {$ELSE}
  {$IFDEF CPUAARCH64}
  LCpu := 'aarch64';
  {$ELSE}
  LCpu := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}

  {$IFDEF LINUX}
  LOs := 'linux';
  {$ELSE}
  {$IFDEF MSWINDOWS}
  LOs := 'win64';
  {$ELSE}
  {$IFDEF DARWIN}
  LOs := 'darwin';
  {$ELSE}
  LOs := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}

  StampFile := IncludeTrailingPathDelimiter(FSandboxRoot) + 'build-stamp.' + LCpu + '-' + LOs;
  EnsureDir(FSandboxRoot);

  AssignFile(F, StampFile);
  try
    Rewrite(F);
    WriteLn(F, 'version=', AVersion);
    WriteLn(F, 'timestamp=', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn(F, 'cpu=', LCpu);
    WriteLn(F, 'os=', LOs);
    CloseFile(F);
    Log('Created build stamp: ' + StampFile);
  except
    on E: Exception do
      Log('Failed to create build stamp: ' + E.Message);
  end;
end;

{ Package Selection Methods (Phase 4.3) }

function TBuildManager.ListPackages: TStringArray;
begin
  // Default FPC package list (can be extended by reading from source)
  Result := nil;
  SetLength(Result, 15);
  Result[0] := 'rtl';
  Result[1] := 'rtl-extra';
  Result[2] := 'rtl-unicode';
  Result[3] := 'rtl-objpas';
  Result[4] := 'fcl-base';
  Result[5] := 'fcl-db';
  Result[6] := 'fcl-fpcunit';
  Result[7] := 'fcl-image';
  Result[8] := 'fcl-json';
  Result[9] := 'fcl-net';
  Result[10] := 'fcl-passrc';
  Result[11] := 'fcl-process';
  Result[12] := 'fcl-registry';
  Result[13] := 'fcl-xml';
  Result[14] := 'paszlib';
end;

procedure TBuildManager.SetSelectedPackages(const APackages: TStringArray);
var
  i: Integer;
begin
  SetLength(FSelectedPackages, Length(APackages));
  for i := 0 to High(APackages) do
    FSelectedPackages[i] := APackages[i];
end;

function TBuildManager.GetSelectedPackageCount: Integer;
begin
  Result := Length(FSelectedPackages);
end;

procedure TBuildManager.SetSkippedPackages(const APackages: TStringArray);
var
  i: Integer;
begin
  SetLength(FSkippedPackages, Length(APackages));
  for i := 0 to High(APackages) do
    FSkippedPackages[i] := APackages[i];
end;

function TBuildManager.GetSkippedPackageCount: Integer;
begin
  Result := Length(FSkippedPackages);
end;

function TBuildManager.GetPackageBuildOrder: TStringArray;
begin
  // Return packages in dependency order (RTL first, then FCL)
  // If selected packages specified, filter to those
  if Length(FSelectedPackages) > 0 then
    Result := FSelectedPackages
  else
    Result := ListPackages;
end;

{ IBuildManager interface implementation }

function TBuildManager.Preflight: Boolean;
begin
  // Interface method without version parameter
  // Use empty string as default version
  Result := Preflight('');
end;

function TBuildManager.GetLastError: string;
begin
  Result := FLastError;
end;

end.

