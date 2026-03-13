unit fpdev.cmd.config;

{
================================================================================
  fpdev.cmd.config - Configuration Management Command
================================================================================

  Provides commands for managing fpdev configuration:
  - fpdev system config show           - Show current configuration
  - fpdev system config set <key> <value> - Set a configuration value
  - fpdev system config get <key>      - Get a configuration value

  Supported configuration keys:
  - mirror: 'auto', 'github', 'gitee', or custom URL
  - custom_repo_url: Custom repository URL (highest priority)
  - parallel_jobs: Number of parallel build jobs
  - auto_update: Enable/disable auto-update
  - keep_sources: Keep source files after build

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry;

type
  TConfigCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowHelp(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
    function GetHelp: string;
  end;

function CreateConfigCommand: ICommand;

implementation

uses
  fpdev.command.namespacehelp,
  fpdev.config.commandflow;

function CreateConfigCommand: ICommand;
begin
  Result := TConfigCommand.Create;
end;

function TConfigCommand.Name: string;
begin
  Result := 'config';
end;

function TConfigCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TConfigCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

procedure TConfigCommand.ShowHelp(const Ctx: IContext);
begin
  WriteConfigHelp(Ctx);
end;

function TConfigCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteNamespaceRootCommandCore(
    AParams,
    Ctx,
    'Usage: fpdev system config help',
    @ShowHelp,
    @ShowHelp
  );
end;

function TConfigCommand.GetHelp: string;
begin
  Result := 'Manage fpdev configuration settings';
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system','config'], @CreateConfigCommand, []);

end.
