unit fpdev.cmd.config.list;

{
================================================================================
  fpdev.cmd.config.list - List Installed Toolchains
================================================================================

  Provides commands for listing all installed toolchains:
  - fpdev system config list           - List all installed FPC and Lazarus versions
  - fpdev system config list --fpc     - List only FPC versions
  - fpdev system config list --lazarus - List only Lazarus versions
  - fpdev system config list --active  - Show only the active (default) versions

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.output.intf, fpdev.paths, fpdev.exitcodes;

type
  { TConfigListCommand - List installed toolchains }
  TConfigListCommand = class(TInterfacedObject, ICommand)
  private
    FConfigManager: IConfigManager;
    FShowFPC: Boolean;
    FShowLazarus: Boolean;
    FShowActiveOnly: Boolean;

    function ParseOptions(const AParams: array of string; const Ctx: IContext): Boolean;
    procedure ListFPCVersions(const Ctx: IContext);
    procedure ListLazarusVersions(const Ctx: IContext);
    procedure ShowHelp(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateConfigListCommand: ICommand;

implementation

function CreateConfigListCommand: ICommand;
begin
  Result := TConfigListCommand.Create;
end;

{ TConfigListCommand }

function TConfigListCommand.Name: string;
begin
  Result := 'list';
end;

function TConfigListCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TConfigListCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TConfigListCommand.ParseOptions(const AParams: array of string; const Ctx: IContext): Boolean;
var
  I: Integer;
  Param: string;
begin
  Result := False;
  FShowFPC := False;
  FShowLazarus := False;
  FShowActiveOnly := False;

  for I := 0 to High(AParams) do
  begin
    Param := LowerCase(AParams[I]);
    if (Param = '--fpc') or (Param = '-f') then
      FShowFPC := True
    else if (Param = '--lazarus') or (Param = '-l') then
      FShowLazarus := True
    else if (Param = '--active') or (Param = '-a') then
      FShowActiveOnly := True
    else
    begin
      Ctx.Err.WriteLn('Usage: fpdev system config list [options]');
      Exit;
    end;
  end;

  // If no filter specified, show both
  if not FShowFPC and not FShowLazarus then
  begin
    FShowFPC := True;
    FShowLazarus := True;
  end;
  Result := True;
end;

procedure TConfigListCommand.ListFPCVersions(const Ctx: IContext);
var
  ToolchainMgr: IToolchainManager;
  Toolchains: TStringArray;
  DefaultVersion: string;
  I: Integer;
  Version, Status: string;
begin
  ToolchainMgr := FConfigManager.GetToolchainManager;
  DefaultVersion := ToolchainMgr.GetDefaultToolchain;

  if FShowActiveOnly then
  begin
    if DefaultVersion <> '' then
    begin
      Ctx.Out.WriteLn('FPC:');
      Ctx.Out.WriteLn('  * ' + DefaultVersion + ' (active)');
    end
    else
      Ctx.Out.WriteLn('FPC: (none active)');
    Exit;
  end;

  Toolchains := ToolchainMgr.ListToolchains;

  Ctx.Out.WriteLn('FPC Toolchains:');
  if Length(Toolchains) = 0 then
  begin
    Ctx.Out.WriteLn('  (none installed)');
    Exit;
  end;

  for I := 0 to High(Toolchains) do
  begin
    Version := Toolchains[I];
    if Version = DefaultVersion then
      Status := ' (active)'
    else
      Status := '';
    Ctx.Out.WriteLn('  - ' + Version + Status);
  end;
end;

procedure TConfigListCommand.ListLazarusVersions(const Ctx: IContext);
var
  LazarusMgr: ILazarusManager;
  Versions: TStringArray;
  DefaultVersion: string;
  I: Integer;
  Version, Status: string;
begin
  LazarusMgr := FConfigManager.GetLazarusManager;
  DefaultVersion := LazarusMgr.GetDefaultLazarusVersion;

  if FShowActiveOnly then
  begin
    if DefaultVersion <> '' then
    begin
      Ctx.Out.WriteLn('Lazarus:');
      Ctx.Out.WriteLn('  * ' + DefaultVersion + ' (active)');
    end
    else
      Ctx.Out.WriteLn('Lazarus: (none active)');
    Exit;
  end;

  Versions := LazarusMgr.ListLazarusVersions;

  Ctx.Out.WriteLn('Lazarus IDEs:');
  if Length(Versions) = 0 then
  begin
    Ctx.Out.WriteLn('  (none installed)');
    Exit;
  end;

  for I := 0 to High(Versions) do
  begin
    Version := Versions[I];
    if Version = DefaultVersion then
      Status := ' (active)'
    else
      Status := '';
    Ctx.Out.WriteLn('  - ' + Version + Status);
  end;
end;

procedure TConfigListCommand.ShowHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev system config list [options]');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('List installed FPC and Lazarus toolchains.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Options:');
  Ctx.Out.WriteLn('  --fpc, -f       Show only FPC versions');
  Ctx.Out.WriteLn('  --lazarus, -l   Show only Lazarus versions');
  Ctx.Out.WriteLn('  --active, -a    Show only active (default) versions');
  Ctx.Out.WriteLn('  --help, -h      Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev system config list');
  Ctx.Out.WriteLn('  fpdev system config list --fpc');
  Ctx.Out.WriteLn('  fpdev system config list --active');
end;

function TConfigListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  I: Integer;
begin
  Result := EXIT_OK;

  // Check for help flag
  for I := 0 to High(AParams) do
  begin
    if (AParams[I] = 'help') or (AParams[I] = '--help') or (AParams[I] = '-h') then
    begin
      ShowHelp(Ctx);
      Exit;
    end;
  end;

  // Load config
  FConfigManager := TConfigManager.Create(GetConfigPath);
  FConfigManager.LoadConfig;

  // Parse options
  if not ParseOptions(AParams, Ctx) then
  begin
    Result := EXIT_USAGE_ERROR;
    Exit;
  end;

  // List toolchains
  if FShowFPC then
    ListFPCVersions(Ctx);

  if FShowFPC and FShowLazarus then
    Ctx.Out.WriteLn('');

  if FShowLazarus then
    ListLazarusVersions(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'config', 'list'], @CreateConfigListCommand, []);

end.
