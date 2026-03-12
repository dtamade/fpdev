unit fpdev.cmd.system.toolchain.fetch;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry;

type
  TSystemToolchainFetchCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemToolchainFetchCommand: ICommand;

implementation

uses
  fpdev.toolchain.commandflow;

function CreateSystemToolchainFetchCommand: ICommand;
begin
  Result := TSystemToolchainFetchCommand.Create;
end;

function TSystemToolchainFetchCommand.Name: string;
begin
  Result := 'fetch';
end;

function TSystemToolchainFetchCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemToolchainFetchCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemToolchainFetchCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := RunToolchainFetchCommand(AParams, Ctx.Out, Ctx.Err);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'toolchain', 'fetch'], @CreateSystemToolchainFetchCommand, []);

end.
