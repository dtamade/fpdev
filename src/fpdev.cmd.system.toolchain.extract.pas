unit fpdev.cmd.system.toolchain.extract;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry;

type
  TSystemToolchainExtractCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemToolchainExtractCommand: ICommand;

implementation

uses
  fpdev.toolchain.commandflow;

function CreateSystemToolchainExtractCommand: ICommand;
begin
  Result := TSystemToolchainExtractCommand.Create;
end;

function TSystemToolchainExtractCommand.Name: string;
begin
  Result := 'extract';
end;

function TSystemToolchainExtractCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemToolchainExtractCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemToolchainExtractCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := RunToolchainExtractCommand(AParams, Ctx.Out, Ctx.Err);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'toolchain', 'extract'], @CreateSystemToolchainExtractCommand, []);

end.
