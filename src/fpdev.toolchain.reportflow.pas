unit fpdev.toolchain.reportflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TToolchainStringArray = array of string;

  TToolchainRunAndCaptureFirstLineFunc = function(
    const ACmd: string;
    const AArgs: array of string;
    out ALine: string
  ): Boolean;

  TToolchainResolvePathFunc = function(const ACmd: string): string;

function SplitToolchainPathHeadCore(
  const APath: string;
  AMax: Integer
): TToolchainStringArray;

function RunToolchainFirstLineCore(
  const ACmd: string;
  const AArgs: array of string;
  out ALine: string
): Boolean;

function GetToolchainFPCVersionCore(
  ARunAndCaptureFirstLine: TToolchainRunAndCaptureFirstLineFunc;
  out AFPCVersion: string
): Boolean;

function BuildToolchainReportJSONCore(
  const AHostOS, AHostCPU, APathValue, ARepoRootOverride, ACurrentDir,
    ALazarusDirOverride: string;
  ARunAndCaptureFirstLine: TToolchainRunAndCaptureFirstLineFunc;
  AResolvePath: TToolchainResolvePathFunc
): string;

function BuildDefaultToolchainReportJSONCore: string;

implementation

uses
  fpdev.utils, fpdev.utils.process
  {$IFDEF UNIX}
  , BaseUnix
  {$ENDIF}
  ;

const
  TOOLCHAIN_REPO_MARKER = 'fpdev.lpi';

type
  TToolchainStatusCore = record
    Name: string;
    Found: Boolean;
    Version: string;
    Path: string;
    Notes: string;
  end;

  TToolchainStatusArrayCore = array of TToolchainStatusCore;

  TToolchainReportCore = record
    HostOS: string;
    HostCPU: string;
    PathHead: TToolchainStringArray;
    Tools: TToolchainStatusArrayCore;
    Issues: TToolchainStringArray;
    Level: string;
  end;

function RunToolchainFirstLineCore(
  const ACmd: string;
  const AArgs: array of string;
  out ALine: string
): Boolean;
var
  LResult: TProcessResult;
  LPos: SizeInt;
begin
  ALine := '';
  LResult := TProcessExecutor.Execute(ACmd, AArgs, '');
  if LResult.Success and (LResult.StdOut <> '') then
  begin
    LPos := Pos(LineEnding, LResult.StdOut);
    if LPos > 0 then
      ALine := Trim(Copy(LResult.StdOut, 1, LPos - 1))
    else
      ALine := Trim(LResult.StdOut);
  end;
  Result := LResult.Success;
end;

function ResolveToolchainPathCore(const ACmd: string): string;
begin
  Result := TProcessExecutor.FindExecutable(ACmd);
end;

function SplitToolchainPathHeadCore(
  const APath: string;
  AMax: Integer
): TToolchainStringArray;
var
  L: TStringList;
  I: Integer;
  N: Integer;
begin
  Result := nil;
  L := TStringList.Create;
  try
    {$IFDEF MSWINDOWS}
    L.Delimiter := ';';
    {$ELSE}
    L.Delimiter := ':';
    {$ENDIF}
    L.StrictDelimiter := True;
    L.DelimitedText := APath;
    N := L.Count;
    if (AMax > 0) and (N > AMax) then
      N := AMax;
    SetLength(Result, N);
    for I := 0 to N - 1 do
      Result[I] := L[I];
  finally
    L.Free;
  end;
end;

function ResolveToolchainRealPathCore(const APath: string): string;
{$IFDEF UNIX}
var
  CurrentPath: string;
  LinkTarget: string;
  ParentDir: string;
  Hop: Integer;
begin
  CurrentPath := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
  for Hop := 0 to 7 do
  begin
    LinkTarget := fpReadLink(CurrentPath);
    if LinkTarget = '' then
      Break;

    if ExtractFileDrive(LinkTarget) = '' then
    begin
      ParentDir := ExtractFileDir(CurrentPath);
      LinkTarget := ExpandFileName(
        IncludeTrailingPathDelimiter(ParentDir) + LinkTarget
      );
    end;
    CurrentPath := ExcludeTrailingPathDelimiter(ExpandFileName(LinkTarget));
  end;
  Result := CurrentPath;
end;
{$ELSE}
begin
  Result := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
end;
{$ENDIF}

function IsToolchainLazarusRootDirCore(const APath: string): Boolean;
var
  NormalizedPath: string;
begin
  NormalizedPath := ExcludeTrailingPathDelimiter(ExpandFileName(Trim(APath)));
  Result := (NormalizedPath <> '') and
    DirectoryExists(IncludeTrailingPathDelimiter(NormalizedPath) + 'lcl');
end;

function DirWritableNoSideEffectsCore(const APath: string): Boolean;
{$IFNDEF UNIX}
var
  Attr: LongInt;
{$ENDIF}
begin
  Result := False;
  if not DirectoryExists(APath) then
    Exit(False);

  {$IFDEF UNIX}
  Result := fpAccess(PChar(APath), W_OK) = 0;
  {$ELSE}
  Attr := FileGetAttr(APath);
  Result := (Attr <> -1) and ((Attr and faReadOnly) = 0);
  {$ENDIF}
end;

function ParentDirWritableNoSideEffectsCore(const APath: string): Boolean;
var
  ParentDir: string;
begin
  ParentDir := ExcludeTrailingPathDelimiter(
    ExtractFileDir(ExcludeTrailingPathDelimiter(ExpandFileName(APath)))
  );
  Result := (ParentDir <> '') and DirWritableNoSideEffectsCore(ParentDir);
end;

function FindToolchainRepoRootFromDirCore(
  const AStartDir, AMarkerFile: string
): string;
var
  CurrentDir: string;
  ParentDir: string;
begin
  CurrentDir := ExcludeTrailingPathDelimiter(ExpandFileName(Trim(AStartDir)));
  if CurrentDir = '' then
    Exit('');

  while CurrentDir <> '' do
  begin
    if FileExists(IncludeTrailingPathDelimiter(CurrentDir) + AMarkerFile) then
      Exit(CurrentDir);

    ParentDir := ExcludeTrailingPathDelimiter(ExtractFileDir(CurrentDir));
    if (ParentDir = '') or (ParentDir = CurrentDir) then
      Break;
    CurrentDir := ParentDir;
  end;

  Result := '';
end;

function ResolveToolchainRepoRootCore(
  const ARepoRootOverride, ACurrentDir, AMarkerFile: string
): string;
var
  Candidate: string;
begin
  Candidate := Trim(ARepoRootOverride);
  if Candidate <> '' then
  begin
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Candidate));
    if FileExists(IncludeTrailingPathDelimiter(Candidate) + AMarkerFile) then
      Exit(Candidate);
    Exit('');
  end;

  Result := FindToolchainRepoRootFromDirCore(ACurrentDir, AMarkerFile);
end;

function ProbeToolchainRepoBuildOutputCore(
  const AName, ARepoRoot, ADirName: string
): TToolchainStatusCore;
var
  OutputDir: string;
begin
  Result.Name := AName;
  Result.Found := False;
  Result.Version := '';
  Result.Path := '';
  Result.Notes := '';

  if ARepoRoot = '' then
    Exit;

  OutputDir := IncludeTrailingPathDelimiter(ARepoRoot) + ADirName;
  Result.Path := ExcludeTrailingPathDelimiter(ExpandFileName(OutputDir));

  if DirectoryExists(Result.Path) then
  begin
    Result.Found := DirWritableNoSideEffectsCore(Result.Path);
    if not Result.Found then
      Result.Notes := 'directory exists but is not writable';
    Exit;
  end;

  Result.Found := ParentDirWritableNoSideEffectsCore(Result.Path);
  if Result.Found then
    Result.Notes := 'creatable'
  else
    Result.Notes := 'parent directory is not writable';
end;

function ProbeToolchainLazarusRootCore(
  const ALazarusDirOverride: string;
  AResolvePath: TToolchainResolvePathFunc
): TToolchainStatusCore;
var
  Candidate: string;
  LazbuildPath: string;
begin
  Result.Name := 'lazarus_root';
  Result.Found := False;
  Result.Version := '';
  Result.Path := '';
  Result.Notes := '';

  Candidate := Trim(ALazarusDirOverride);
  if Candidate <> '' then
  begin
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Candidate));
    if IsToolchainLazarusRootDirCore(Candidate) then
    begin
      Result.Found := True;
      Result.Path := Candidate;
    end
    else
      Result.Notes := 'FPDEV_LAZARUSDIR does not contain lcl/';
    Exit;
  end;

  LazbuildPath := '';
  if Assigned(AResolvePath) then
    LazbuildPath := AResolvePath('lazbuild');
  if LazbuildPath <> '' then
  begin
    Candidate := ExtractFileDir(ResolveToolchainRealPathCore(LazbuildPath));
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Candidate));
    if IsToolchainLazarusRootDirCore(Candidate) then
    begin
      Result.Found := True;
      Result.Path := Candidate;
      Exit;
    end;
  end;

  Result.Notes := 'set FPDEV_LAZARUSDIR to a Lazarus root containing lcl/';
end;

procedure AddToolCore(
  var AArr: TToolchainStatusArrayCore;
  const ATool: TToolchainStatusCore
);
var
  N: Integer;
begin
  N := Length(AArr);
  SetLength(AArr, N + 1);
  AArr[N] := ATool;
end;

procedure AddIssueCore(
  var AArr: TToolchainStringArray;
  const AItem: string
);
var
  N: Integer;
begin
  N := Length(AArr);
  SetLength(AArr, N + 1);
  AArr[N] := AItem;
end;

function HasIssueContainingCore(
  const AArr: TToolchainStringArray;
  const ANeedle: string
): Boolean;
var
  I: Integer;
  LowerNeedle: string;
begin
  LowerNeedle := LowerCase(Trim(ANeedle));
  for I := 0 to High(AArr) do
    if Pos(LowerNeedle, LowerCase(Trim(AArr[I]))) > 0 then
      Exit(True);
  Result := False;
end;

function ProbeToolchainOneCore(
  const AName: string;
  const AArgs: array of string;
  ARunAndCaptureFirstLine: TToolchainRunAndCaptureFirstLineFunc;
  AResolvePath: TToolchainResolvePathFunc
): TToolchainStatusCore;
var
  LLine: string;
begin
  Result.Name := AName;
  Result.Found := Assigned(ARunAndCaptureFirstLine) and
    ARunAndCaptureFirstLine(AName, AArgs, LLine);
  if Result.Found then
  begin
    Result.Version := LLine;
    if Assigned(AResolvePath) then
      Result.Path := AResolvePath(AName)
    else
      Result.Path := '';
  end
  else
  begin
    Result.Version := '';
    Result.Path := '';
  end;
  Result.Notes := '';
end;

function ProbeToolchainFirstAvailableCore(
  const ANames: array of string;
  const AArgs: array of string;
  ARunAndCaptureFirstLine: TToolchainRunAndCaptureFirstLineFunc;
  AResolvePath: TToolchainResolvePathFunc
): TToolchainStatusCore;
var
  I: Integer;
begin
  Result := Default(TToolchainStatusCore);
  for I := Low(ANames) to High(ANames) do
  begin
    Result := ProbeToolchainOneCore(
      ANames[I],
      AArgs,
      ARunAndCaptureFirstLine,
      AResolvePath
    );
    if Result.Found then
      Exit;
  end;
end;

function ReportToToolchainJSONCore(const R: TToolchainReportCore): string;
var
  I: Integer;
  J: Integer;
  Builder: TStringBuilder;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.Append('{');
    Builder.Append('"hostOS":"' + JsonEscape(R.HostOS) + '",');
    Builder.Append('"hostCPU":"' + JsonEscape(R.HostCPU) + '",');
    Builder.Append('"pathHead":[');
    for I := 0 to High(R.PathHead) do
    begin
      if I > 0 then
        Builder.Append(',');
      Builder.Append('"' + JsonEscape(R.PathHead[I]) + '"');
    end;
    Builder.Append('],"tools":[');
    for I := 0 to High(R.Tools) do
    begin
      if I > 0 then
        Builder.Append(',');
      Builder.Append(
        '{"name":"' + JsonEscape(R.Tools[I].Name) + '",' +
        '"found":' + LowerCase(BoolToStr(R.Tools[I].Found, True)) + ',' +
        '"version":"' + JsonEscape(R.Tools[I].Version) + '",' +
        '"path":"' + JsonEscape(R.Tools[I].Path) + '",' +
        '"notes":"' + JsonEscape(R.Tools[I].Notes) + '"}'
      );
    end;
    Builder.Append('],"issues":[');
    for J := 0 to High(R.Issues) do
    begin
      if J > 0 then
        Builder.Append(',');
      Builder.Append('"' + JsonEscape(R.Issues[J]) + '"');
    end;
    Builder.Append('],"level":"' + JsonEscape(R.Level) + '"}');
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function GetToolchainFPCVersionCore(
  ARunAndCaptureFirstLine: TToolchainRunAndCaptureFirstLineFunc;
  out AFPCVersion: string
): Boolean;
var
  LLine: string;
begin
  AFPCVersion := '';
  Result := Assigned(ARunAndCaptureFirstLine) and
    ARunAndCaptureFirstLine('fpc', ['-iV'], LLine);
  if Result then
    AFPCVersion := Trim(LLine);
end;

function BuildToolchainReportJSONCore(
  const AHostOS, AHostCPU, APathValue, ARepoRootOverride, ACurrentDir,
    ALazarusDirOverride: string;
  ARunAndCaptureFirstLine: TToolchainRunAndCaptureFirstLineFunc;
  AResolvePath: TToolchainResolvePathFunc
): string;
var
  Report: TToolchainReportCore;
  ToolStatus: TToolchainStatusCore;
  RepoRoot: string;
begin
  Report.HostOS := AHostOS;
  Report.HostCPU := AHostCPU;
  Report.PathHead := SplitToolchainPathHeadCore(APathValue, 5);

  ToolStatus := ProbeToolchainOneCore(
    'fpc',
    ['-iV'],
    ARunAndCaptureFirstLine,
    AResolvePath
  );
  if not ToolStatus.Found then
    AddIssueCore(Report.Issues, 'missing fpc');
  AddToolCore(Report.Tools, ToolStatus);

  {$IFDEF MSWINDOWS}
  ToolStatus := ProbeToolchainFirstAvailableCore(
    ['mingw32-make', 'make', 'gmake'],
    ['--version'],
    ARunAndCaptureFirstLine,
    AResolvePath
  );
  {$ELSE}
  ToolStatus := ProbeToolchainFirstAvailableCore(
    ['gmake', 'make'],
    ['--version'],
    ARunAndCaptureFirstLine,
    AResolvePath
  );
  {$ENDIF}
  if not ToolStatus.Found then
    AddIssueCore(Report.Issues, 'missing make-family');
  AddToolCore(Report.Tools, ToolStatus);

  ToolStatus := ProbeToolchainOneCore(
    'lazbuild',
    ['--version'],
    ARunAndCaptureFirstLine,
    AResolvePath
  );
  if not ToolStatus.Found then
    ToolStatus.Notes := 'optional';
  AddToolCore(Report.Tools, ToolStatus);

  ToolStatus := ProbeToolchainLazarusRootCore(ALazarusDirOverride, AResolvePath);
  if not ToolStatus.Found then
    AddIssueCore(Report.Issues, 'missing lazarus_root');
  AddToolCore(Report.Tools, ToolStatus);

  RepoRoot := ResolveToolchainRepoRootCore(
    ARepoRootOverride,
    ACurrentDir,
    TOOLCHAIN_REPO_MARKER
  );
  if RepoRoot <> '' then
  begin
    ToolStatus := ProbeToolchainRepoBuildOutputCore(
      'repo_bin_writable',
      RepoRoot,
      'bin'
    );
    if not ToolStatus.Found then
      AddIssueCore(Report.Issues, 'repo build output not writable: bin');
    AddToolCore(Report.Tools, ToolStatus);

    ToolStatus := ProbeToolchainRepoBuildOutputCore(
      'repo_lib_writable',
      RepoRoot,
      'lib'
    );
    if not ToolStatus.Found then
      AddIssueCore(Report.Issues, 'repo build output not writable: lib');
    AddToolCore(Report.Tools, ToolStatus);
  end;

  ToolStatus := ProbeToolchainOneCore(
    'git',
    ['--version'],
    ARunAndCaptureFirstLine,
    AResolvePath
  );
  if not ToolStatus.Found then
    ToolStatus.Notes := 'optional';
  AddToolCore(Report.Tools, ToolStatus);

  ToolStatus := ProbeToolchainOneCore(
    'openssl',
    ['version'],
    ARunAndCaptureFirstLine,
    AResolvePath
  );
  if not ToolStatus.Found then
    ToolStatus.Notes := 'optional for HTTPS';
  AddToolCore(Report.Tools, ToolStatus);

  if Length(Report.Issues) = 0 then
    Report.Level := 'OK'
  else if HasIssueContainingCore(Report.Issues, 'missing fpc') or
          HasIssueContainingCore(Report.Issues, 'missing make-family') or
          HasIssueContainingCore(Report.Issues, 'missing lazarus_root') or
          HasIssueContainingCore(Report.Issues, 'repo build output not writable') then
    Report.Level := 'FAIL'
  else
    Report.Level := 'WARN';

  Result := ReportToToolchainJSONCore(Report);
end;

function BuildDefaultToolchainReportJSONCore: string;
var
  HostOS: string;
  HostCPU: string;
begin
  {$IFDEF MSWINDOWS}
  HostOS := 'Windows';
  {$ELSE}
  HostOS := 'Unix-like';
  {$ENDIF}

  {$if defined(CPUX86_64)}
  HostCPU := 'x86_64';
  {$elseif defined(CPUX86)}
  HostCPU := 'i386';
  {$elseif defined(CPUAARCH64)}
  HostCPU := 'aarch64';
  {$elseif defined(CPUARM)}
  HostCPU := 'arm';
  {$else}
  HostCPU := 'unknown';
  {$endif}

  Result := BuildToolchainReportJSONCore(
    HostOS,
    HostCPU,
    get_env('PATH'),
    Trim(get_env('FPDEV_TOOLCHAIN_REPO_ROOT')),
    GetCurrentDir,
    Trim(get_env('FPDEV_LAZARUSDIR')),
    @RunToolchainFirstLineCore,
    @ResolveToolchainPathCore
  );
end;

end.
