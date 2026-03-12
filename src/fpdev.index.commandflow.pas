unit fpdev.index.commandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

procedure WriteIndexHelp(const Ctx: IContext);
procedure RunIndexStatus(const Ctx: IContext);
function RunIndexShow(const Ctx: IContext): Integer;
function RunIndexUpdate(const Ctx: IContext): Integer;

implementation

uses
  fpdev.help.details.system,
  fpdev.exitcodes,
  fpdev.index,
  fpdev.system.view;

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
  {$IFDEF MSWINDOWS}
  CacheDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
              '.fpdev' + PathDelim + 'cache';
  {$ELSE}
  CacheDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
              '.fpdev' + PathDelim + 'cache';
  {$ENDIF}
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
var
  Index: TFPDevIndex;
  RepoInfo: TRepoInfo;
  ChannelInfo: TChannelInfo;
  Versions: TStringArray;
  I: Integer;
  Lines: TStringArray;
  Line: string;
  BootstrapVersions: TStringArray;
  FPCVersions: TStringArray;
  LazarusVersions: TStringArray;
begin
  Result := EXIT_OK;
  Index := TFPDevIndex.Create('auto');
  try
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

    RepoInfo := Index.GetRepoInfo(rtBootstrap);
    ChannelInfo := Index.GetChannelInfo('stable');
    Versions := nil;
    RepoInfo := Index.GetRepoInfo(rtFPC);
    ChannelInfo := Index.GetChannelInfo('edge');
    RepoInfo := Index.GetRepoInfo(rtLazarus);

    RepoInfo := Index.GetRepoInfo(rtBootstrap);
    ChannelInfo := Index.GetChannelInfo('stable');
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
var
  Index: TFPDevIndex;
  Lines: TStringArray;
  Line: string;
  Success: Boolean;
begin
  Result := EXIT_OK;
  Index := TFPDevIndex.Create('auto');
  try
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
