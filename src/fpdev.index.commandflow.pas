unit fpdev.index.commandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.index;

type
  TIndexServiceFactory = function(const AMirrorPreference: string): TFPDevIndex;

procedure WriteIndexHelp(const Ctx: IContext);
procedure RunIndexStatus(const Ctx: IContext);
function RunIndexShow(const Ctx: IContext): Integer;
function RunIndexUpdate(const Ctx: IContext): Integer;
function RunIndexShowWithFactory(
  const Ctx: IContext;
  ACreateIndex: TIndexServiceFactory
): Integer;
function RunIndexUpdateWithFactory(
  const Ctx: IContext;
  ACreateIndex: TIndexServiceFactory
): Integer;

implementation

uses
  fpdev.help.details.system,
  fpdev.exitcodes,
  fpdev.paths,
  fpdev.system.view;

function CreateDefaultIndexService(const AMirrorPreference: string): TFPDevIndex;
begin
  Result := TFPDevIndex.Create(AMirrorPreference);
end;

procedure WriteIndexHelp(const Ctx: IContext);
begin
  WriteSystemIndexHelpCore(Ctx);
end;

procedure RunIndexStatus(const Ctx: IContext);
var
  CacheDir: string;
  IndexFile: string;
  Platform: string;
  Lines: TStringArray;
  Line: string;
begin
  Platform := GetPlatformIdentifier;
  CacheDir := IncludeTrailingPathDelimiter(GetDataRoot) + 'cache';
  IndexFile := CacheDir + PathDelim + 'index.json';
  Lines := BuildSystemIndexStatusLinesCore(
    Platform,
    CacheDir,
    IndexFile,
    DirectoryExists(CacheDir),
    FileExists(IndexFile)
  );
  for Line in Lines do
    Ctx.Out.WriteLn(Line);
end;

function RunIndexShow(const Ctx: IContext): Integer;
begin
  Result := RunIndexShowWithFactory(Ctx, @CreateDefaultIndexService);
end;

function RunIndexShowWithFactory(
  const Ctx: IContext;
  ACreateIndex: TIndexServiceFactory
): Integer;
var
  Index: TFPDevIndex;
  RepoInfo: TRepoInfo;
  Lines: TStringArray;
  Line: string;
  BootstrapVersions: TStringArray;
  FPCVersions: TStringArray;
  LazarusVersions: TStringArray;
begin
  Result := EXIT_OK;
  if Assigned(ACreateIndex) then
    Index := ACreateIndex('auto')
  else
    Index := CreateDefaultIndexService('auto');
  try
    Index.Output := Ctx.Out;
    Ctx.Out.WriteLn('Initializing index...');
    if not Index.Initialize then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Failed to initialize index.');
      Ctx.Out.WriteLn('Please check your network connection.');
      Result := EXIT_IO_ERROR;
      Exit;
    end;

    RepoInfo := Index.GetRepoInfo(rtBootstrap);
    BootstrapVersions := Index.ListBootstrapVersions;

    FPCVersions := Index.ListFPCVersions;

    LazarusVersions := Index.ListLazarusVersions;
    Lines := BuildSystemIndexShowLinesCore(
      RepoInfo.Name,
      RepoInfo.GitHubURL,
      RepoInfo.GiteeURL,
      Index.GetRepoInfo(rtFPC).Name,
      Index.GetRepoInfo(rtFPC).GitHubURL,
      Index.GetRepoInfo(rtFPC).GiteeURL,
      Index.GetRepoInfo(rtLazarus).Name,
      Index.GetRepoInfo(rtLazarus).GitHubURL,
      Index.GetRepoInfo(rtLazarus).GiteeURL,
      Index.GetChannelInfo('stable').BootstrapRef,
      Index.GetChannelInfo('stable').FPCRef,
      Index.GetChannelInfo('stable').LazarusRef,
      Index.GetChannelInfo('edge').BootstrapRef,
      Index.GetChannelInfo('edge').FPCRef,
      Index.GetChannelInfo('edge').LazarusRef,
      BootstrapVersions,
      FPCVersions,
      LazarusVersions
    );
    for Line in Lines do
      Ctx.Out.WriteLn(Line);
  finally
    Index.Free;
  end;
end;

function RunIndexUpdate(const Ctx: IContext): Integer;
begin
  Result := RunIndexUpdateWithFactory(Ctx, @CreateDefaultIndexService);
end;

function RunIndexUpdateWithFactory(
  const Ctx: IContext;
  ACreateIndex: TIndexServiceFactory
): Integer;
var
  Index: TFPDevIndex;
  Lines: TStringArray;
  Line: string;
  Success: Boolean;
begin
  Result := EXIT_OK;
  if Assigned(ACreateIndex) then
    Index := ACreateIndex('auto')
  else
    Index := CreateDefaultIndexService('auto');
  try
    Index.Output := Ctx.Out;
    Success := Index.Initialize;
    Lines := BuildSystemIndexUpdateResultLinesCore(Success);
    for Line in Lines do
      Ctx.Out.WriteLn(Line);
    if not Success then
      Result := EXIT_IO_ERROR;
  finally
    Index.Free;
  end;
end;

end.
