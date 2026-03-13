unit fpdev.cmd.index;

{
================================================================================
  fpdev.cmd.index - Index Management Command
================================================================================

  Provides commands for managing fpdev resource index:
  - fpdev system index status   - Show index status and cached info
  - fpdev system index update   - Force update index from remote
  - fpdev system index show     - Show index details (repositories, channels)

  Uses the two-level index architecture from fpdev.index.pas.

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
  { TIndexCommand - Index management command }
  TIndexCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowHelp(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateIndexCommand: ICommand;

implementation

uses
  fpdev.command.namespacehelp,
  fpdev.index.commandflow;

function CreateIndexCommand: ICommand;
begin
  Result := TIndexCommand.Create;
end;

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
  WriteIndexHelp(Ctx);
end;

function TIndexCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteNamespaceRootCommandCore(
    AParams,
    Ctx,
    'Usage: fpdev system index <command>',
    @ShowHelp,
    @ShowHelp
  );
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'index'], @CreateIndexCommand, []);

end.
