unit fpdev.build.strict;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TBuildStrictLogProc = procedure(const ALine: string) of object;
  TBuildStrictDirSampleProc = procedure(const ADir: string; ALimit: Integer) of object;

  TBuildStrictDirRule = record
    SectionName: string;
    RelativeDir: string;
    Required: Boolean;
    MinCount: Integer;
    RequireSubdir: Boolean;
    RequiredSubdir: string;
  end;

function BuildManagerResolveStrictConfigPathCore(
  const AExplicitPath, ASandboxDest: string
): string;
function BuildManagerValidateDirRuleCore(
  const ASandboxDest: string;
  const ARule: TBuildStrictDirRule;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc;
  ALogDirSample: TBuildStrictDirSampleProc
): Boolean;
function BuildManagerValidateBinRuleCore(
  const ASandboxDest: string;
  AMinCount: Integer;
  const ARequiredPrefixCSV, ARequiredExtCSV: string;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc;
  ALogDirSample: TBuildStrictDirSampleProc
): Boolean;
function BuildManagerValidateFpcCfgRuleCore(
  const ASandboxDest: string;
  ARequireCfg: Boolean;
  const ACfgRelativeListCSV: string;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc
): Boolean;
function BuildManagerApplyStrictConfigCore(
  const AIniPath, ASandboxDest: string;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc;
  ALogDirSample: TBuildStrictDirSampleProc
): Boolean;

implementation

uses
  Classes, IniFiles, fpdev.build.probe;

function BuildStrictReadCSV(const S: string): TStringList;
var
  L: TStringList;
begin
  L := TStringList.Create;
  L.Delimiter := ',';
  L.StrictDelimiter := True;
  L.DelimitedText := StringReplace(S, ' ', '', [rfReplaceAll]);
  Result := L;
end;

function BuildManagerResolveStrictConfigPathCore(
  const AExplicitPath, ASandboxDest: string
): string;
var
  LDemoPath: string;
  LSandboxCfg: string;
begin
  Result := '';

  if (AExplicitPath <> '') and FileExists(AExplicitPath) then
    Exit(AExplicitPath);

  if FileExists('build-manager.strict.ini') then
    Exit('build-manager.strict.ini');

  LDemoPath := IncludeTrailingPathDelimiter('plays') +
    'fpdev.build.manager.demo' + PathDelim + 'build-manager.strict.ini';
  if FileExists(LDemoPath) then
    Exit(LDemoPath);

  if ASandboxDest <> '' then
  begin
    LSandboxCfg := IncludeTrailingPathDelimiter(ASandboxDest) +
      'build-manager.strict.ini';
    if FileExists(LSandboxCfg) then
      Exit(LSandboxCfg);
  end;
end;

function BuildManagerValidateDirRuleCore(
  const ASandboxDest: string;
  const ARule: TBuildStrictDirRule;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc;
  ALogDirSample: TBuildStrictDirSampleProc
): Boolean;
var
  LDir: string;

  procedure LogLine(const ALine: string);
  begin
    if Assigned(ALog) then
      ALog(ALine);
  end;

  procedure LogSample(const ADir: string; ALimit: Integer);
  begin
    if Assigned(ALogDirSample) then
      ALogDirSample(ADir, ALimit);
  end;
begin
  LDir := IncludeTrailingPathDelimiter(ASandboxDest) +
    StringReplace(ARule.RelativeDir, '/', PathDelim, [rfReplaceAll]);

  if ARule.Required then
  begin
    if not DirectoryExists(LDir) then
    begin
      LogLine('FAIL: [' + ARule.SectionName + '] directory not found: ' + LDir);
      if AVerbosity > 0 then
        LogLine('hint: [' + ARule.SectionName + '] expected dir: ' + LDir);
      Exit(False);
    end;

    if (ARule.MinCount > 0) and (not BuildManagerDirHasAnyEntry(LDir)) then
    begin
      LogLine('FAIL: [' + ARule.SectionName + '] no content');
      if AVerbosity > 0 then
      begin
        LogLine('hint: [' + ARule.SectionName + '] sample:');
        LogSample(LDir, 20);
      end;
      Exit(False);
    end;

    if ARule.RequireSubdir and (not BuildManagerDirHasAnySubdir(LDir)) then
    begin
      LogLine('FAIL: [' + ARule.SectionName + '] require_subdir but none found');
      if AVerbosity > 0 then
      begin
        LogLine('hint: [' + ARule.SectionName + '] expected child dirs');
        LogSample(LDir, 20);
      end;
      Exit(False);
    end;

    if (ARule.RequiredSubdir <> '') and
       (not DirectoryExists(IncludeTrailingPathDelimiter(LDir) + ARule.RequiredSubdir)) then
    begin
      LogLine('FAIL: [' + ARule.SectionName + '] required_subdir missing: ' + ARule.RequiredSubdir);
      if AVerbosity > 0 then
        LogLine('hint: [' + ARule.SectionName + '] expected subdir: ' + ARule.RequiredSubdir);
      Exit(False);
    end;

    Exit(True);
  end;

  if DirectoryExists(LDir) and (AVerbosity > 0) then
    LogLine('info: [' + ARule.SectionName + '] present but not required');

  Result := True;
end;

function BuildManagerValidateBinRuleCore(
  const ASandboxDest: string;
  AMinCount: Integer;
  const ARequiredPrefixCSV, ARequiredExtCSV: string;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc;
  ALogDirSample: TBuildStrictDirSampleProc
): Boolean;
var
  LBin: string;
  LReqPrefix: TStringList;
  LReqExt: TStringList;

  procedure LogLine(const ALine: string);
  begin
    if Assigned(ALog) then
      ALog(ALine);
  end;

  procedure LogSample(const ADir: string; ALimit: Integer);
  begin
    if Assigned(ALogDirSample) then
      ALogDirSample(ADir, ALimit);
  end;
begin
  Result := False;
  LReqPrefix := nil;
  LReqExt := nil;
  try
    LBin := IncludeTrailingPathDelimiter(ASandboxDest) + 'bin';
    LReqPrefix := BuildStrictReadCSV(ARequiredPrefixCSV);
    LReqExt := BuildStrictReadCSV(ARequiredExtCSV);

    if not DirectoryExists(LBin) then
    begin
      LogLine('FAIL: [bin] directory not found: ' + LBin);
      Exit;
    end;

    if (AMinCount > 0) and (not BuildManagerDirHasAnyFile(LBin)) then
    begin
      LogLine('FAIL: [bin] no files');
      Exit;
    end;

    if not BuildManagerHasFileLike(LBin, LReqPrefix.ToStringArray, LReqExt.ToStringArray) then
    begin
      LogLine('FAIL: [bin] missing required executable (prefix/ext)');
      if AVerbosity > 0 then
      begin
        LogLine('hint: [bin] required_prefix=' + StringReplace(ARequiredPrefixCSV, ' ', '', [rfReplaceAll]));
        LogLine('hint: [bin] required_ext=' + StringReplace(ARequiredExtCSV, ' ', '', [rfReplaceAll]));
        LogLine('hint: [bin] sample:');
        LogSample(LBin, 20);
      end;
      Exit;
    end;

    Result := True;
  finally
    LReqExt.Free;
    LReqPrefix.Free;
  end;
end;

function BuildManagerValidateFpcCfgRuleCore(
  const ASandboxDest: string;
  ARequireCfg: Boolean;
  const ACfgRelativeListCSV: string;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc
): Boolean;
var
  LCfgList: TStringList;
  LHasCfg: Boolean;
  LCfgFound: string;
  K: Integer;
  SR: TSearchRec;
  LRel: string;
  LFull: string;

  procedure LogLine(const ALine: string);
  begin
    if Assigned(ALog) then
      ALog(ALine);
  end;
begin
  Result := True;
  if not ARequireCfg then
    Exit;

  LCfgList := BuildStrictReadCSV(ACfgRelativeListCSV);
  try
    LHasCfg := False;
    LCfgFound := '';
    for K := 0 to LCfgList.Count - 1 do
    begin
      LRel := StringReplace(LCfgList[K], '/', PathDelim, [rfReplaceAll]);
      LFull := IncludeTrailingPathDelimiter(ASandboxDest) + LRel;
      if FileExists(LFull) then
      begin
        LHasCfg := True;
        LCfgFound := LFull;
        Break;
      end;
    end;

    if not LHasCfg then
    begin
      LogLine('FAIL: [fpc] missing fpc.cfg in cfg_relative_list');
      if AVerbosity > 0 then
      begin
        LogLine('hint: [fpc] tried list=' + ACfgRelativeListCSV);
        LogLine('hint: [fpc] root=' + ASandboxDest);
      end;
      Exit(False);
    end;

    if (LCfgFound <> '') and (FindFirst(LCfgFound, faAnyFile, SR) = 0) then
    begin
      try
        if SR.Size <= 0 then
        begin
          LogLine('FAIL: [fpc] fpc.cfg is empty: ' + LCfgFound);
          Exit(False);
        end;
      finally
        FindClose(SR);
      end;
    end;
  finally
    LCfgList.Free;
  end;
end;

function BuildManagerApplyStrictConfigCore(
  const AIniPath, ASandboxDest: string;
  AVerbosity: Integer;
  ALog: TBuildStrictLogProc;
  ALogDirSample: TBuildStrictDirSampleProc
): Boolean;
var
  Ini: TIniFile;
  DirRule: TBuildStrictDirRule;
begin
  Result := True;
  if AIniPath = '' then
    Exit(True);

  Ini := TIniFile.Create(AIniPath);
  try
    if not BuildManagerValidateBinRuleCore(
      ASandboxDest,
      Ini.ReadInteger('bin', 'min_count', 1),
      Ini.ReadString('bin', 'required_prefix', 'fpc,ppc'),
      Ini.ReadString('bin', 'required_ext', '.exe,.sh,'),
      AVerbosity,
      ALog,
      ALogDirSample
    ) then
      Exit(False);

    DirRule.SectionName := 'lib';
    DirRule.RelativeDir := 'lib';
    DirRule.Required := True;
    DirRule.MinCount := Ini.ReadInteger('lib', 'min_count', 1);
    DirRule.RequireSubdir := Ini.ReadBool('lib', 'require_subdir', True);
    DirRule.RequiredSubdir := '';
    if not BuildManagerValidateDirRuleCore(
      ASandboxDest,
      DirRule,
      AVerbosity,
      ALog,
      ALogDirSample
    ) then
      Exit(False);

    DirRule.SectionName := 'share';
    DirRule.RelativeDir := 'share';
    DirRule.Required := Ini.ReadBool('share', 'required', False);
    DirRule.MinCount := Ini.ReadInteger('share', 'min_count', 0);
    DirRule.RequireSubdir := Ini.ReadBool('share', 'require_subdir', False);
    DirRule.RequiredSubdir := Ini.ReadString('share', 'required_subdir', '');
    if not BuildManagerValidateDirRuleCore(
      ASandboxDest,
      DirRule,
      AVerbosity,
      ALog,
      ALogDirSample
    ) then
      Exit(False);

    if not BuildManagerValidateFpcCfgRuleCore(
      ASandboxDest,
      Ini.ReadBool('fpc', 'require_cfg', False),
      Ini.ReadString('fpc', 'cfg_relative_list', 'etc/fpc.cfg,lib/fpc/fpc.cfg'),
      AVerbosity,
      ALog
    ) then
      Exit(False);

    DirRule.SectionName := 'include';
    DirRule.RelativeDir := Ini.ReadString('include', 'relative_dir', 'include');
    DirRule.Required := Ini.ReadBool('include', 'required', False);
    DirRule.MinCount := Ini.ReadInteger('include', 'min_count', 0);
    DirRule.RequireSubdir := Ini.ReadBool('include', 'require_subdir', False);
    DirRule.RequiredSubdir := Ini.ReadString('include', 'required_subdir', '');
    if not BuildManagerValidateDirRuleCore(
      ASandboxDest,
      DirRule,
      AVerbosity,
      ALog,
      ALogDirSample
    ) then
      Exit(False);

    DirRule.SectionName := 'doc';
    DirRule.RelativeDir := Ini.ReadString('doc', 'relative_dir', 'doc');
    DirRule.Required := Ini.ReadBool('doc', 'required', False);
    DirRule.MinCount := Ini.ReadInteger('doc', 'min_count', 0);
    DirRule.RequireSubdir := Ini.ReadBool('doc', 'require_subdir', False);
    DirRule.RequiredSubdir := Ini.ReadString('doc', 'required_subdir', '');
    if not BuildManagerValidateDirRuleCore(
      ASandboxDest,
      DirRule,
      AVerbosity,
      ALog,
      ALogDirSample
    ) then
      Exit(False);
  finally
    Ini.Free;
  end;
end;

end.
