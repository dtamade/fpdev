unit fpdev.toolchain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.utils, fpdev.utils.process
  {$IFDEF UNIX}
  , BaseUnix
  {$ENDIF}
  ;

type
  TStringDynArray = array of string;

  TToolStatus = record
    Name: string;
    Found: boolean;
    Version: string;
    Path: string;
    Notes: string;
  end;

  TToolStatusArray = array of TToolStatus;

  TToolchainReport = record
    HostOS: string;
    HostCPU: string;
    PathHead: TStringDynArray;
    Tools: TToolStatusArray;
    Issues: TStringDynArray;
    Level: string; // OK|WARN|FAIL
  end;

// Build a minimal health check report (HostReady scenario):
// fpc/make/lazbuild/lazarus_root/git/openssl
function BuildToolchainReportJSON: string;
// Get the current FPC version (fpc -iV); returns True on success and fills the version string
function GetFPCVersion(out AFPCVersion: string): boolean;
// Check whether the FPC version satisfies the policy for the given source version (e.g. main, 3.2.x)
// Return value: True means >= min (can proceed); AStatus = OK | WARN | FAIL;
//  - OK  : >= rec
//  - WARN: >= min and < rec
//  - FAIL: < min or FPC missing
function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;

implementation

uses
  fpdev.toolchain.policyflow;

function SplitPathHead(const APath: string; AMax: Integer): TStringDynArray;
var
  L: TStringList;
  i, N: Integer;
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
    N := L.Count; if (AMax>0) and (N>AMax) then N := AMax;
    SetLength(Result, N);
    for i := 0 to N-1 do Result[i] := L[i];
  finally
    L.Free;
  end;
end;

function RunAndCaptureFirstLine(const ACmd: string; const AArgs: array of string; out ALine: string): boolean;
var
  LResult: TProcessResult;
  LPos: SizeInt;
begin
  ALine := '';
  LResult := TProcessExecutor.Execute(ACmd, AArgs, '');
  if LResult.Success and (LResult.StdOut <> '') then
  begin
    // Get first line only
    LPos := Pos(LineEnding, LResult.StdOut);
    if LPos > 0 then
      ALine := Trim(Copy(LResult.StdOut, 1, LPos - 1))
    else
      ALine := Trim(LResult.StdOut);
  end;
  Result := LResult.Success;
end;

function ResolvePathOf(const ACmd: string): string;
begin
  Result := TProcessExecutor.FindExecutable(ACmd);
end;

function ResolveRealPath(const APath: string): string;
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

function IsLazarusRootDir(const APath: string): Boolean;
var
  NormalizedPath: string;
begin
  NormalizedPath := ExcludeTrailingPathDelimiter(ExpandFileName(Trim(APath)));
  Result := (NormalizedPath <> '') and
    DirectoryExists(IncludeTrailingPathDelimiter(NormalizedPath) + 'lcl');
end;

function DirIsWritableNoSideEffects(const APath: string): Boolean;
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

function ParentDirWritableNoSideEffects(const APath: string): Boolean;
var
  ParentDir: string;
begin
  ParentDir := ExcludeTrailingPathDelimiter(
    ExtractFileDir(ExcludeTrailingPathDelimiter(ExpandFileName(APath)))
  );
  Result := (ParentDir <> '') and DirIsWritableNoSideEffects(ParentDir);
end;

function FindRepoRootFromDir(const AStartDir: string): string;
var
  CurrentDir: string;
  ParentDir: string;
begin
  CurrentDir := ExcludeTrailingPathDelimiter(ExpandFileName(Trim(AStartDir)));
  if CurrentDir = '' then
    Exit('');

  while CurrentDir <> '' do
  begin
    if FileExists(IncludeTrailingPathDelimiter(CurrentDir) + 'fpdev.lpi') then
      Exit(CurrentDir);

    ParentDir := ExcludeTrailingPathDelimiter(ExtractFileDir(CurrentDir));
    if (ParentDir = '') or (ParentDir = CurrentDir) then
      Break;
    CurrentDir := ParentDir;
  end;

  Result := '';
end;

function ResolveRepoRootForToolchain: string;
var
  Candidate: string;
begin
  Candidate := Trim(get_env('FPDEV_TOOLCHAIN_REPO_ROOT'));
  if Candidate <> '' then
  begin
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Candidate));
    if FileExists(IncludeTrailingPathDelimiter(Candidate) + 'fpdev.lpi') then
      Exit(Candidate);
    Exit('');
  end;

  Result := FindRepoRootFromDir(GetCurrentDir);
end;

function ProbeRepoBuildOutput(
  const AName: string;
  const ARepoRoot: string;
  const ADirName: string
): TToolStatus;
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
    Result.Found := DirIsWritableNoSideEffects(Result.Path);
    if not Result.Found then
      Result.Notes := 'directory exists but is not writable';
    Exit;
  end;

  Result.Found := ParentDirWritableNoSideEffects(Result.Path);
  if Result.Found then
    Result.Notes := 'creatable'
  else
    Result.Notes := 'parent directory is not writable';
end;

function ProbeLazarusRoot: TToolStatus;
var
  Candidate: string;
  LazbuildPath: string;
begin
  Result.Name := 'lazarus_root';
  Result.Found := False;
  Result.Version := '';
  Result.Path := '';
  Result.Notes := '';

  Candidate := Trim(get_env('FPDEV_LAZARUSDIR'));
  if Candidate <> '' then
  begin
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Candidate));
    if IsLazarusRootDir(Candidate) then
    begin
      Result.Found := True;
      Result.Path := Candidate;
    end
    else
      Result.Notes := 'FPDEV_LAZARUSDIR does not contain lcl/';
    Exit;
  end;

  LazbuildPath := ResolvePathOf('lazbuild');
  if LazbuildPath <> '' then
  begin
    Candidate := ExtractFileDir(ResolveRealPath(LazbuildPath));
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Candidate));
    if IsLazarusRootDir(Candidate) then
    begin
      Result.Found := True;
      Result.Path := Candidate;
      Exit;
    end;
  end;

  Result.Notes := 'set FPDEV_LAZARUSDIR to a Lazarus root containing lcl/';
end;

procedure AddTool(var AArr: TToolStatusArray; const ATool: TToolStatus);
var
  N: Integer;
begin
  N := Length(AArr);
  SetLength(AArr, N+1);
  AArr[N] := ATool;
end;

procedure AddIssue(var AArr: TStringDynArray; const AItem: string);
var N: Integer;
begin
  N := Length(AArr); SetLength(AArr, N+1); AArr[N] := AItem;
end;

function HasIssueContaining(const AArr: TStringDynArray; const ANeedle: string): Boolean;
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

function ProbeOne(const AName: string; const AArgs: array of string): TToolStatus;
var
  LLine: string;
begin
  Result.Name := AName;
  Result.Found := RunAndCaptureFirstLine(AName, AArgs, LLine);
  if Result.Found then
  begin
    Result.Version := LLine;
    Result.Path := ResolvePathOf(AName);
  end
  else
  begin
    Result.Version := '';
    Result.Path := '';
  end;
end;

function ProbeFirstAvailable(
  const ANames: array of string;
  const AArgs: array of string;
  out Chosen: string
): TToolStatus;
var i: Integer;
begin
  Result := Default(TToolStatus);
  for i := Low(ANames) to High(ANames) do
  begin
    Result := ProbeOne(ANames[i], AArgs);
    if Result.Found then begin Chosen := ANames[i]; Exit; end;
  end;
  Chosen := '';
end;

function ReportToJSON(const R: TToolchainReport): string;
var
  i,j: Integer;
  Builder: TStringBuilder;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.Append('{');
    Builder.Append('"hostOS":"' + JsonEscape(R.HostOS) + '",');
    Builder.Append('"hostCPU":"' + JsonEscape(R.HostCPU) + '",');
    Builder.Append('"pathHead":[');
    for i := 0 to High(R.PathHead) do
    begin
      if i>0 then Builder.Append(',');
      Builder.Append('"' + JsonEscape(R.PathHead[i]) + '"');
    end;
    Builder.Append('],"tools":[');
    for i := 0 to High(R.Tools) do
    begin
      if i>0 then Builder.Append(',');
      Builder.Append('{"name":"'+JsonEscape(R.Tools[i].Name)+'",'+
                '"found":'+LowerCase(BoolToStr(R.Tools[i].Found, True))+','+
                '"version":"'+JsonEscape(R.Tools[i].Version)+'",'+
                '"path":"'+JsonEscape(R.Tools[i].Path)+'",'+
                '"notes":"'+JsonEscape(R.Tools[i].Notes)+'"}');
    end;
    Builder.Append('],"issues":[');
    for j := 0 to High(R.Issues) do
    begin
      if j>0 then Builder.Append(',');
      Builder.Append('"'+JsonEscape(R.Issues[j])+'"');
    end;
    Builder.Append('],"level":"'+JsonEscape(R.Level)+'"}');
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function GetFPCVersion(out AFPCVersion: string): boolean;
var LLine: string;
begin
  AFPCVersion := '';
  Result := RunAndCaptureFirstLine('fpc', ['-iV'], LLine);
  if Result then AFPCVersion := Trim(LLine);
end;

function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;
begin
  if not GetFPCVersion(AFPCVersion) then
  begin
    AStatus := 'FAIL';
    AReason := 'fpc not found';
    Exit(False);
  end;
  Result := EvaluateToolchainFPCVersionPolicyCore(
    ASourceVersion,
    AFPCVersion,
    AStatus,
    AReason,
    AMin,
    ARec
  );
end;

function BuildToolchainReportJSON: string;
var
  R: TToolchainReport;
  T: TToolStatus;
  Chosen: string;
  PathStr: string;
  RepoRoot: string;
begin
  {$IFDEF MSWINDOWS}
  R.HostOS := 'Windows';
  {$ELSE}
  R.HostOS := 'Unix-like';
  {$ENDIF}
  {$if defined(CPUX86_64)} R.HostCPU := 'x86_64'
  {$elseif defined(CPUX86)} R.HostCPU := 'i386'
  {$elseif defined(CPUAARCH64)} R.HostCPU := 'aarch64'
  {$elseif defined(CPUARM)} R.HostCPU := 'arm'
  {$else} R.HostCPU := 'unknown' {$endif};

  PathStr := get_env('PATH');
  R.PathHead := SplitPathHead(PathStr, 5);

  // fpc
  T := ProbeOne('fpc', ['-iV']); if not T.Found then AddIssue(R.Issues, 'missing fpc');
  AddTool(R.Tools, T);

  // make family
  {$IFDEF MSWINDOWS}
  T := ProbeFirstAvailable(['mingw32-make','make','gmake'], ['--version'], Chosen);
  {$ELSE}
  T := ProbeFirstAvailable(['gmake','make'], ['--version'], Chosen);
  {$ENDIF}
  if not T.Found then AddIssue(R.Issues, 'missing make-family');
  AddTool(R.Tools, T);

  // lazbuild (recommended)
  T := ProbeOne('lazbuild', ['--version']);
  if not T.Found then T.Notes := 'optional';
  AddTool(R.Tools, T);

  // lazarus_root (required for release-grade Lazarus builds)
  T := ProbeLazarusRoot;
  if not T.Found then AddIssue(R.Issues, 'missing lazarus_root');
  AddTool(R.Tools, T);

  RepoRoot := ResolveRepoRootForToolchain;
  if RepoRoot <> '' then
  begin
    T := ProbeRepoBuildOutput('repo_bin_writable', RepoRoot, 'bin');
    if not T.Found then
      AddIssue(R.Issues, 'repo build output not writable: bin');
    AddTool(R.Tools, T);

    T := ProbeRepoBuildOutput('repo_lib_writable', RepoRoot, 'lib');
    if not T.Found then
      AddIssue(R.Issues, 'repo build output not writable: lib');
    AddTool(R.Tools, T);
  end;

  // git (recommended)
  T := ProbeOne('git', ['--version']); if not T.Found then T.Notes := 'optional';
  AddTool(R.Tools, T);

  // openssl (recommended)
  T := ProbeOne('openssl', ['version']); if not T.Found then T.Notes := 'optional for HTTPS';
  AddTool(R.Tools, T);

  if Length(R.Issues) = 0 then
    R.Level := 'OK'
  else if HasIssueContaining(R.Issues, 'missing fpc') or
          HasIssueContaining(R.Issues, 'missing make-family') or
          HasIssueContaining(R.Issues, 'missing lazarus_root') or
          HasIssueContaining(R.Issues, 'repo build output not writable') then
    R.Level := 'FAIL'
  else
    R.Level := 'WARN';

  Result := ReportToJSON(R);
end;

end.
