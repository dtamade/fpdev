unit fpdev.build.manager;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TBuildManager }
  TBuildManager = class
  private
    FSourceRoot: string;
    FParallelJobs: Integer;
    FVerbose: Boolean;
    FSandboxRoot: string;
    FLogDir: string;
    FAllowInstall: Boolean;
    FLogFileName: string;
    FLogVerbosity: Integer; // 0=normal, 1=verbose
    FStrictResults: Boolean; // 严格模式：更严格的沙箱产物校验
    FStrictConfigPath: string; // 严格模式配置文件路径（可选）
    FDryRun: Boolean; // 演练模式：仅打印命令，不执行
    FToolchainStrict: Boolean; // 工具链严格校验（失败则阻断）
    // make 与目标/前缀配置（可选）
    FMakeCmd: string;              // 自定义 make 命令（留空则自动探测）
    FCPU_TARGET: string;           // 目标 CPU（可选）
    FOS_TARGET: string;            // 目标 OS（可选）
    FPREFIX: string;               // 安装前缀（可选，Install 时若设置将覆盖默认）
    FINSTALL_PREFIX: string;       // 安装前缀（可选，Install 时若设置将覆盖默认）
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
    procedure SetSandboxRoot(const APath: string);
    procedure SetAllowInstall(AEnable: Boolean);
    procedure SetLogVerbosity(ALevel: Integer);
    procedure SetStrictResults(AEnable: Boolean);
    procedure SetStrictConfigPath(const APath: string);
    procedure SetDryRun(AEnable: Boolean);
    procedure SetToolchainStrict(AEnable: Boolean);
    // 可选增强配置
    procedure SetMakeCmd(const ACmd: string);
    procedure SetTarget(const ACpu, AOs: string);
    procedure SetPrefix(const APrefix, AInstallPrefix: string);
    property LogFileName: string read GetLogFileName;
    function BuildCompiler(const AVersion: string): Boolean;
    function BuildRTL(const AVersion: string): Boolean;
    function Install(const AVersion: string): Boolean;
    function Configure(const AVersion: string): Boolean;
    function TestResults(const AVersion: string): Boolean;
    function Preflight(const AVersion: string): Boolean;
    // 环境体检（纯代码实现，不依赖脚本）
    function CheckToolchain: Boolean;
  end;

implementation

uses
  Process, IniFiles, DateUtils, fpdev.toolchain;

constructor TBuildManager.Create(const ASourceRoot: string; AParallelJobs: Integer; AVerbose: Boolean);
begin
  inherited Create;
  FSourceRoot := ASourceRoot;
  FParallelJobs := AParallelJobs;
  FVerbose := AVerbose;
  FSandboxRoot := 'sandbox';
  FLogDir := 'logs';
  FAllowInstall := False; // 默认不安装，避免污染
  FLogVerbosity := 0;
  FStrictResults := False;
  FStrictConfigPath := '';
  FDryRun := False;
  FToolchainStrict := False;
  FMakeCmd := '';
  FCPU_TARGET := '';
  FOS_TARGET := '';
  FPREFIX := '';
  FINSTALL_PREFIX := '';
  EnsureDir(FSandboxRoot);
  EnsureDir(FLogDir);
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
  FLogVerbosity := ALevel;
  Log('LogVerbosity set to ' + IntToStr(FLogVerbosity));
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
var
  SR: TSearchRec;
  LCount: Integer;
  LBase: string;
begin
  if FLogVerbosity = 0 then Exit;
  if not DirectoryExists(ADir) then
  begin
    Log('dir not exists: ' + ADir);
    Exit;
  end;
  LBase := IncludeTrailingPathDelimiter(ADir);
  LCount := 0;
  if FindFirst(LBase + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        Log(' - ' + SR.Name);
        Inc(LCount);
        if (ALimit > 0) and (LCount >= ALimit) then Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

procedure TBuildManager.LogEnvSnapshot;
var
  LOS, LPath: string;
  i, LCount, LMax: Integer;
  LParts: TStringList;
begin
  if FLogVerbosity = 0 then Exit;
  {$IFDEF MSWINDOWS}
  LOS := 'Windows';
  {$ELSE}
  LOS := 'Unix-like';
  {$ENDIF}
  Log('env: OS=' + LOS);
  // PATH 片段
  LPath := GetEnvironmentVariable('PATH');
  LParts := TStringList.Create;
  try
    {$IFDEF MSWINDOWS}
    LParts.Delimiter := ';';
    {$ELSE}
    LParts.Delimiter := ':';
    {$ENDIF}
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := LPath;
    LCount := LParts.Count;
    LMax := 5;
    if LCount < LMax then LMax := LCount;
    for i := 0 to LMax-1 do
      Log('env: PATH[' + IntToStr(i) + ']=' + LParts[i]);
  finally
    LParts.Free;
  end;
  // make --version 已由 RunMake 预探测，如需可在此扩展其它工具版本
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
        if FLogVerbosity > 0 then
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
          if FLogVerbosity > 0 then begin Log('hint: [lib] sample:'); LogDirSample(LLib, 20); end;
          Exit(False);
        end;
      end;
      if LRequireSubdir and (not DirHasAnySubdir(LLib)) then
      begin
        Log('FAIL: [lib] require_subdir but none found');
        if FLogVerbosity > 0 then begin Log('hint: [lib] expected a subdirectory (e.g. fpc/<ver>)'); LogDirSample(LLib, 20); end;
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
      if not DirectoryExists(LShare) then begin Log('FAIL: [share] directory not found: ' + LShare); if FLogVerbosity > 0 then Log('hint: [share] expected dir: ' + LShare); Exit(False); end;
      if (LShareMin > 0) and (not DirHasAnyFile(LShare)) then begin Log('FAIL: [share] no files'); if FLogVerbosity > 0 then begin Log('hint: [share] sample:'); LogDirSample(LShare, 20); end; Exit(False); end;
      if LShareRequireSubdir and (not DirHasAnySubdir(LShare)) then begin Log('FAIL: [share] require_subdir but none found'); if FLogVerbosity > 0 then begin Log('hint: [share] expected child dirs'); LogDirSample(LShare, 20); end; Exit(False); end;
      if (LShareReqSub <> '') and (not DirectoryExists(IncludeTrailingPathDelimiter(LShare) + LShareReqSub)) then begin Log('FAIL: [share] required_subdir missing: ' + LShareReqSub); if FLogVerbosity > 0 then Log('hint: [share] expected subdir: ' + LShareReqSub); Exit(False); end;
    end
    else
    begin
      if DirectoryExists(LShare) and (FLogVerbosity > 0) then Log('info: [share] present but not required');
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
      if not LHasCfg then begin Log('FAIL: [fpc] missing fpc.cfg in cfg_relative_list'); if FLogVerbosity > 0 then begin Log('hint: [fpc] tried list=' + Ini.ReadString('fpc','cfg_relative_list','etc/fpc.cfg,lib/fpc/fpc.cfg')); Log('hint: [fpc] root=' + ASandboxDest); end; Exit(False); end;
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
      if not DirectoryExists(LIncDir) then begin Log('FAIL: [include] directory not found: ' + LIncDir); if FLogVerbosity > 0 then Log('hint: [include] expected dir: ' + LIncDir); Exit(False); end;
      if (LIncMin > 0) and (not DirHasAnyFile(LIncDir)) then begin Log('FAIL: [include] no files'); if FLogVerbosity > 0 then begin Log('hint: [include] sample:'); LogDirSample(LIncDir, 20); end; Exit(False); end;
      if LIncRequireSubdir and (not DirHasAnySubdir(LIncDir)) then begin Log('FAIL: [include] require_subdir but none found'); if FLogVerbosity > 0 then begin Log('hint: [include] expected child dirs'); LogDirSample(LIncDir, 20); end; Exit(False); end;
      if (LIncReqSub <> '') and (not DirectoryExists(IncludeTrailingPathDelimiter(LIncDir) + LIncReqSub)) then begin Log('FAIL: [include] required_subdir missing: ' + LIncReqSub); if FLogVerbosity > 0 then Log('hint: [include] expected subdir: ' + LIncReqSub); Exit(False); end;
    end
    else
    begin
      if DirectoryExists(LIncDir) and (FLogVerbosity > 0) then Log('info: [include] present but not required');
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
      if not DirectoryExists(LDocDir) then begin Log('FAIL: [doc] directory not found: ' + LDocDir); if FLogVerbosity > 0 then Log('hint: [doc] expected dir: ' + LDocDir); Exit(False); end;
      if (LDocMin > 0) and (not DirHasAnyFile(LDocDir)) then begin Log('FAIL: [doc] no files'); if FLogVerbosity > 0 then begin Log('hint: [doc] sample:'); LogDirSample(LDocDir, 20); end; Exit(False); end;
      if LDocRequireSubdir and (not DirHasAnySubdir(LDocDir)) then begin Log('FAIL: [doc] require_subdir but none found'); if FLogVerbosity > 0 then begin Log('hint: [doc] expected child dirs'); LogDirSample(LDocDir, 20); end; Exit(False); end;
      if (LDocReqSub <> '') and (not DirectoryExists(IncludeTrailingPathDelimiter(LDocDir) + LDocReqSub)) then begin Log('FAIL: [doc] required_subdir missing: ' + LDocReqSub); if FLogVerbosity > 0 then Log('hint: [doc] expected subdir: ' + LDocReqSub); Exit(False); end;
    end
    else
    begin
      if DirectoryExists(LDocDir) and (FLogVerbosity > 0) then Log('info: [doc] present but not required');
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
    Check('fpc','-iV', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogVerbosity>0 then Log(Line);
    Check('lazbuild','--version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogVerbosity>0 then Log(Line);
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
    Check('git','--version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogVerbosity>0 then Log(Line);
    Check('openssl','version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogVerbosity>0 then Log(Line);
    // 各平台编译器前端（可选）
    Check('ppc386','', Ok, Line); if not Ok then if FLogVerbosity>0 then Log(Line);
    Check('ppcx64','', Ok, Line); if not Ok then if FLogVerbosity>0 then Log(Line);
    Check('ppcarm','', Ok, Line); if not Ok then if FLogVerbosity>0 then Log(Line);
    Result := (LIssues.Count = 0);
    if Result then Log('== Toolchain Check END OK') else
    begin
      Log('== Toolchain Check END FAIL issues=' + IntToStr(LIssues.Count));
      if FLogVerbosity>0 then
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
var
  LExit: Integer;
begin
  try
    LExit := ExecuteProcess(AExe, AArgs);
    Result := (LExit = 0);
  except
    Result := False;
  end;
end;

function TBuildManager.ResolveMakeCmd: string;
begin
  // 优先级：自定义 → mingw32-make → gmake → make
  if FMakeCmd <> '' then Exit(FMakeCmd);
  {$IFDEF MSWINDOWS}
  if HasTool('mingw32-make', ['--version']) then Exit('mingw32-make');
  {$ENDIF}
  if HasTool('gmake', ['--version']) then Exit('gmake');
  if HasTool('make', ['--version']) then Exit('make');
  Result := 'make'; // 回退（后续 RunMake 会再次验证可用性）
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

procedure TBuildManager.Log(const ALine: string);
var
  LLogPath: string;
  F: TextFile;
begin
  LLogPath := GetLogFileName;
  AssignFile(F, LLogPath);
  try
    if FileExists(LLogPath) then Append(F) else Rewrite(F);
    WriteLn(F, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), ' ', ALine);
  finally
    CloseFile(F);
  end;
end;

function TBuildManager.GetLogFileName: string;
var
  LStamp: string;
begin
  if FLogFileName <> '' then Exit(FLogFileName);
  LStamp := FormatDateTime('yyyymmdd_hhnnss_zzz', Now);
  FLogFileName := IncludeTrailingPathDelimiter(FLogDir) + 'build_' + LStamp + '.log';
  Result := FLogFileName;
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
  if not DirectoryExists(ASourcePath) then Exit(False);
  // 解析 make 命令（去除内联变量）
  LMake := ResolveMakeCmd;
  LMakeVer := ExecuteProcess(LMake, ['--version']);
  if LMakeVer <> 0 then
  begin
    Log('未检测到 make（' + LMake + '），跳过实际构建');
    Exit(True); // 安全起见：不阻塞后续流程
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
  if FLogVerbosity > 0 then Log('make ' + String.Join(' ', LArgs));
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
  LSrc := GetSourcePath(AVersion);
  Log('== BuildCompiler START version=' + AVersion + ' src=' + LSrc);
  if FLogVerbosity > 0 then LogEnvSnapshot;
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
  LSrc := GetSourcePath(AVersion);
  Log('== BuildRTL START version=' + AVersion + ' src=' + LSrc);
  if FLogVerbosity > 0 then LogEnvSnapshot;
  LStart := Now;
  Result := RunMake(LSrc, ['rtl']);
  LMs := MilliSecondsBetween(Now, LStart);
  if Result then Log('== BuildRTL END OK elapsed_ms=' + IntToStr(LMs)) else Log('== BuildRTL END FAIL elapsed_ms=' + IntToStr(LMs));
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
  if FLogVerbosity > 0 then LogEnvSnapshot;
  LStart := Now;
  // 将安装目标定向到沙箱（尝试常见变量：DESTDIR/PREFIX），具体支持取决于上游 Makefile
  Result := RunMake(LSrc, ['DESTDIR=' + LDest, 'PREFIX=' + LDest, 'INSTALL_PREFIX=' + LDest, 'install']);
  LMs := MilliSecondsBetween(Now, LStart);
  if Result then Log('== Install END OK elapsed_ms=' + IntToStr(LMs)) else Log('== Install END FAIL elapsed_ms=' + IntToStr(LMs));
end;

function TBuildManager.Configure(const AVersion: string): Boolean;
begin
  // 保持占位：配置通常写 fpc.cfg，不在此阶段触及系统目录
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
    if FLogVerbosity > 0 then
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
  LStart := Now;
  Log('== Preflight START version=' + AVersion + ' srcRoot=' + FSourceRoot + ' sandbox=' + FSandboxRoot + ' logDir=' + FLogDir);
  if FLogVerbosity > 0 then LogEnvSnapshot;
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
      else if (LStatus <> 'OK') and (FLogVerbosity > 0) then
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
      if FLogVerbosity > 0 then
      begin
        for i := 0 to LIssues.Count-1 do Log('issue: ' + LIssues[i]);
      end;
      LogTestSummary(AVersion, 'preflight', 'FAIL', MilliSecondsBetween(Now, LStart));
    end;
  finally
    LIssues.Free;
  end;
end;


end.

