unit fpdev.cmd.index;

{
================================================================================
  fpdev.cmd.index - Index Management Command
================================================================================

  Provides commands for managing fpdev resource index:
  - fpdev index status   - Show index status and cached info
  - fpdev index update   - Force update index from remote
  - fpdev index show     - Show index details (repositories, channels)

  Uses the two-level index architecture from fpdev.index.pas.

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.output.intf, fpdev.paths, fpdev.exitcodes,
  fpdev.index;

type
  { TIndexCommand - Index management command }
  TIndexCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowStatus(const Ctx: IContext);
    procedure ShowDetails(const Ctx: IContext);
    procedure UpdateIndex(const Ctx: IContext);
    procedure ShowHelp(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateIndexCommand: ICommand;

implementation

function CreateIndexCommand: ICommand;
begin
  Result := TIndexCommand.Create;
end;

{ TIndexCommand }

function TIndexCommand.Name: string;
begin
  Result := 'index';
end;

function TIndexCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TIndexCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

procedure TIndexCommand.ShowHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev index <command>');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Manage fpdev resource index.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Commands:');
  Ctx.Out.WriteLn('  status    Show index status');
  Ctx.Out.WriteLn('  show      Show index details (repositories, channels)');
  Ctx.Out.WriteLn('  update    Force update index from remote');
  Ctx.Out.WriteLn('  help      Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev index status');
  Ctx.Out.WriteLn('  fpdev index show');
  Ctx.Out.WriteLn('  fpdev index update');
end;

procedure TIndexCommand.ShowStatus(const Ctx: IContext);
var
  CacheDir: string;
  IndexFile: string;
  Platform: string;
begin
  Ctx.Out.WriteLn('Index Status');
  Ctx.Out.WriteLn('============');
  Ctx.Out.WriteLn('');

  // Show platform
  Platform := GetPlatformIdentifier;
  Ctx.Out.WriteLn('Platform: ' + Platform);
  Ctx.Out.WriteLn('');

  // Show cache directory
  {$IFDEF MSWINDOWS}
  CacheDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
              '.fpdev' + PathDelim + 'cache';
  {$ELSE}
  CacheDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
              '.fpdev' + PathDelim + 'cache';
  {$ENDIF}

  Ctx.Out.WriteLn('Cache Directory: ' + CacheDir);

  // Check if cache directory exists
  if DirectoryExists(CacheDir) then
    Ctx.Out.WriteLn('  Status: exists')
  else
    Ctx.Out.WriteLn('  Status: not created yet');

  // Show index file status
  IndexFile := CacheDir + PathDelim + 'index.json';
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Index File: ' + IndexFile);
  if FileExists(IndexFile) then
    Ctx.Out.WriteLn('  Status: cached')
  else
    Ctx.Out.WriteLn('  Status: not cached (will fetch on first use)');
end;

procedure TIndexCommand.ShowDetails(const Ctx: IContext);
var
  Index: TFPDevIndex;
  RepoInfo: TRepoInfo;
  ChannelInfo: TChannelInfo;
  Versions: TStringArray;
  I: Integer;
begin
  Ctx.Out.WriteLn('Index Details');
  Ctx.Out.WriteLn('=============');
  Ctx.Out.WriteLn('');

  Index := TFPDevIndex.Create('auto');
  try
    Ctx.Out.WriteLn('Initializing index...');
    if not Index.Initialize then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Failed to initialize index.');
      Ctx.Out.WriteLn('Please check your network connection.');
      Exit;
    end;

    Ctx.Out.WriteLn('');

    // Show repositories
    Ctx.Out.WriteLn('Repositories:');
    Ctx.Out.WriteLn('-------------');

    RepoInfo := Index.GetRepoInfo(rtBootstrap);
    Ctx.Out.WriteLn('  Bootstrap:');
    Ctx.Out.WriteLn('    Name: ' + RepoInfo.Name);
    Ctx.Out.WriteLn('    GitHub: ' + RepoInfo.GitHubURL);
    Ctx.Out.WriteLn('    Gitee: ' + RepoInfo.GiteeURL);

    RepoInfo := Index.GetRepoInfo(rtFPC);
    Ctx.Out.WriteLn('  FPC:');
    Ctx.Out.WriteLn('    Name: ' + RepoInfo.Name);
    Ctx.Out.WriteLn('    GitHub: ' + RepoInfo.GitHubURL);
    Ctx.Out.WriteLn('    Gitee: ' + RepoInfo.GiteeURL);

    RepoInfo := Index.GetRepoInfo(rtLazarus);
    Ctx.Out.WriteLn('  Lazarus:');
    Ctx.Out.WriteLn('    Name: ' + RepoInfo.Name);
    Ctx.Out.WriteLn('    GitHub: ' + RepoInfo.GitHubURL);
    Ctx.Out.WriteLn('    Gitee: ' + RepoInfo.GiteeURL);

    Ctx.Out.WriteLn('');

    // Show channels
    Ctx.Out.WriteLn('Channels:');
    Ctx.Out.WriteLn('---------');

    ChannelInfo := Index.GetChannelInfo('stable');
    Ctx.Out.WriteLn('  stable:');
    Ctx.Out.WriteLn('    Bootstrap: ' + ChannelInfo.BootstrapRef);
    Ctx.Out.WriteLn('    FPC: ' + ChannelInfo.FPCRef);
    Ctx.Out.WriteLn('    Lazarus: ' + ChannelInfo.LazarusRef);

    ChannelInfo := Index.GetChannelInfo('edge');
    Ctx.Out.WriteLn('  edge:');
    Ctx.Out.WriteLn('    Bootstrap: ' + ChannelInfo.BootstrapRef);
    Ctx.Out.WriteLn('    FPC: ' + ChannelInfo.FPCRef);
    Ctx.Out.WriteLn('    Lazarus: ' + ChannelInfo.LazarusRef);

    Ctx.Out.WriteLn('');

    // Show available versions
    Ctx.Out.WriteLn('Available Versions:');
    Ctx.Out.WriteLn('-------------------');

    Versions := Index.ListBootstrapVersions;
    if Length(Versions) > 0 then
    begin
      Ctx.Out.WriteLn('  Bootstrap:');
      for I := 0 to High(Versions) do
        Ctx.Out.WriteLn('    - ' + Versions[I]);
    end;

    Versions := Index.ListFPCVersions;
    if Length(Versions) > 0 then
    begin
      Ctx.Out.WriteLn('  FPC:');
      for I := 0 to High(Versions) do
        Ctx.Out.WriteLn('    - ' + Versions[I]);
    end;

    Versions := Index.ListLazarusVersions;
    if Length(Versions) > 0 then
    begin
      Ctx.Out.WriteLn('  Lazarus:');
      for I := 0 to High(Versions) do
        Ctx.Out.WriteLn('    - ' + Versions[I]);
    end;

  finally
    Index.Free;
  end;
end;

procedure TIndexCommand.UpdateIndex(const Ctx: IContext);
var
  Index: TFPDevIndex;
begin
  Ctx.Out.WriteLn('Updating index...');
  Ctx.Out.WriteLn('');

  Index := TFPDevIndex.Create('auto');
  try
    if Index.Initialize then
    begin
      Ctx.Out.WriteLn('Index updated successfully.');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Run "fpdev index show" to see available versions.');
    end
    else
    begin
      Ctx.Out.WriteLn('Failed to update index.');
      Ctx.Out.WriteLn('Please check your network connection.');
    end;
  finally
    Index.Free;
  end;
end;

function TIndexCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  SubCmd: string;
begin
  Result := EXIT_OK;

  if Length(AParams) = 0 then
  begin
    ShowHelp(Ctx);
    Exit;
  end;

  SubCmd := LowerCase(AParams[0]);

  if (SubCmd = 'help') or (SubCmd = '--help') or (SubCmd = '-h') then
    ShowHelp(Ctx)
  else if SubCmd = 'status' then
    ShowStatus(Ctx)
  else if SubCmd = 'show' then
    ShowDetails(Ctx)
  else if SubCmd = 'update' then
    UpdateIndex(Ctx)
  else
  begin
    Ctx.Err.WriteLn('Error: Unknown subcommand: ' + SubCmd);
    ShowHelp(Ctx);
    Result := EXIT_USAGE_ERROR;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['index'], @CreateIndexCommand, []);

end.
