unit fpdev.cmd.fpc.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TFPCHelpCommand }
  TFPCHelpCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.help.catalog,
  fpdev.help.commandflow,
  fpdev.help.details.fpc;

function TFPCHelpCommand.Name: string; begin Result := 'help'; end;

function TFPCHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;
end;

function TFPCHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteDomainHelpCommandCore(
    AParams,
    Ctx,
    _(HELP_FPC_USAGE),
    _(HELP_FPC_SUBCOMMANDS),
    _(HELP_USE_HELP_CMD_FPC),
    @BuildFPCHelpItems,
    @WriteFPCHelpDetailsCore
  );
end;

function FPCHelpFactory: ICommand;
begin
  Result := TFPCHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'help'], @FPCHelpFactory, []);

end.
