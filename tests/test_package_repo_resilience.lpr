program test_package_repo_resilience;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpjson, jsonparser,
  test_temp_paths,
  fpdev.config,
  fpdev.output.intf,
  fpdev.pkg.repository;

type
  TBufferOutput = class(TInterfacedObject, IOutput)
  private
    FBuf: string;
  public
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor;
      const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor;
      const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Text: string;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure TBufferOutput.Write(const S: string);
begin
  FBuf := FBuf + S;
end;

procedure TBufferOutput.WriteLn;
begin
  FBuf := FBuf + LineEnding;
end;

procedure TBufferOutput.WriteLn(const S: string);
begin
  FBuf := FBuf + S + LineEnding;
end;

procedure TBufferOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TBufferOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TBufferOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  if AColor = ccDefault then;
  Write(S);
end;

procedure TBufferOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  if AColor = ccDefault then;
  WriteLn(S);
end;

procedure TBufferOutput.WriteStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  if AColor = ccDefault then;
  if AStyle = csNone then;
  Write(S);
end;

procedure TBufferOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  if AColor = ccDefault then;
  if AStyle = csNone then;
  WriteLn(S);
end;

procedure TBufferOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TBufferOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

function TBufferOutput.Text: string;
begin
  Result := FBuf;
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean;
  const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure WriteTextFile(const APath, AContent: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

function ReadTextFile(const APath: string): string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(APath);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function ToFileURL(const APath: string): string;
begin
{$IFDEF MSWINDOWS}
  Result := 'file:///' + StringReplace(ExpandFileName(APath), '\', '/',
    [rfReplaceAll]);
{$ELSE}
  Result := 'file://' + ExpandFileName(APath);
{$ENDIF}
end;

procedure TestUpdateRepositoriesSkipsGitReposAndBadIndexes;
var
  TempRoot: string;
  CacheDir: string;
  ConfigPath: string;
  GoodIndexPath: string;
  BrokenIndexPath: string;
  GitRepoPath: string;
  IndexPath: string;
  Config: TFPDevConfigManager;
  Service: TPackageRepositoryService;
  OutBuf: TBufferOutput;
  ErrBuf: TBufferOutput;
  IndexJSON: TJSONData;
  Combined: TJSONArray;
  IndexText: string;
begin
  TempRoot := CreateUniqueTempDir('fpdev-package-repo-resilience');
  CacheDir := IncludeTrailingPathDelimiter(TempRoot) + 'cache';
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';
  GoodIndexPath := IncludeTrailingPathDelimiter(TempRoot) + 'good' + PathDelim +
    'index.json';
  BrokenIndexPath := IncludeTrailingPathDelimiter(TempRoot) + 'broken' +
    PathDelim + 'index.json';
  GitRepoPath := IncludeTrailingPathDelimiter(TempRoot) + 'source.git';
  IndexPath := CacheDir + PathDelim + 'index.json';
  Config := TFPDevConfigManager.Create(ConfigPath);
  OutBuf := TBufferOutput.Create;
  ErrBuf := TBufferOutput.Create;
  Service := nil;
  IndexJSON := nil;
  Combined := nil;
  try
    Check('create default config', Config.CreateDefaultConfig,
      'expected config bootstrap to succeed');
    Check('remove seeded official_fpc repository',
      Config.RemoveRepository('official_fpc'),
      'expected official_fpc to be removable');
    Check('remove seeded official_lazarus repository',
      Config.RemoveRepository('official_lazarus'),
      'expected official_lazarus to be removable');

    WriteTextFile(
      GoodIndexPath,
      '{"packages":[{"name":"kept","version":"1.0.0",' +
      '"url":["file:///tmp/kept.zip"]}]}'
    );
    WriteTextFile(BrokenIndexPath, '{"packages": [');
    WriteTextFile(
      GitRepoPath + PathDelim + 'index.json',
      '{"packages":[{"name":"ignored","version":"9.9.9",' +
      '"url":["file:///tmp/ignored.zip"]}]}'
    );

    Check('add good repository',
      Config.AddRepository('good', ToFileURL(GoodIndexPath)),
      'failed to add good repository');
    Check('add broken repository',
      Config.AddRepository('broken', ToFileURL(BrokenIndexPath)),
      'failed to add broken repository');
    Check('add gitlike repository',
      Config.AddRepository('gitlike', ToFileURL(GitRepoPath)),
      'failed to add gitlike repository');

    Service := TPackageRepositoryService.Create(
      Config.AsConfigManager,
      CacheDir
    );
    try
      Check('update repositories succeeds',
        Service.UpdateRepositories(OutBuf as IOutput, ErrBuf as IOutput),
        'repository refresh should tolerate broken indexes');
    finally
      Service.Free;
    end;

    Check('combined index is written', FileExists(IndexPath),
      'expected merged index to be created');
    Check('success output is emitted',
      Pos('Repository index updated:', OutBuf.Text) > 0,
      OutBuf.Text);
    Check('broken repository is reported',
      Pos('Skipping repository "broken":', ErrBuf.Text) > 0,
      ErrBuf.Text);
    Check('gitlike repository is skipped silently',
      Pos('gitlike', ErrBuf.Text) = 0,
      ErrBuf.Text);

    IndexText := ReadTextFile(IndexPath);
    IndexJSON := GetJSON(IndexText);
    Check('combined index is an array', IndexJSON.JSONType = jtArray,
      'expected array payload');
    if IndexJSON.JSONType = jtArray then
      Combined := TJSONArray(IndexJSON);

    if Combined <> nil then
    begin
      Check('only valid non-git package is retained', Combined.Count = 1,
        'count=' + IntToStr(Combined.Count) + sLineBreak + IndexText);
      if Combined.Count > 0 then
        Check('good package is preserved',
          TJSONObject(Combined.Items[0]).Get('name', '') = 'kept',
          IndexText);
    end;

    Check('git repository payload is not merged',
      Pos('ignored', IndexText) = 0, IndexText);
  finally
    if Assigned(IndexJSON) then
      IndexJSON.Free;
    Config.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  WriteLn('=== Package Repository Resilience Tests ===');
  TestUpdateRepositoriesSkipsGitReposAndBadIndexes;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
