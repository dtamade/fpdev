unit fpdev.cmd.system.toolchain.ensure_source;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry;

type
  TSystemToolchainEnsureSourceCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemToolchainEnsureSourceCommand: ICommand;

implementation

uses
  fpdev.toolchain.commandflow;

function CreateSystemToolchainEnsureSourceCommand: ICommand;
begin
  Result := TSystemToolchainEnsureSourceCommand.Create;
end;

function TSystemToolchainEnsureSourceCommand.Name: string;
begin
  Result := 'ensure-source';
end;

function TSystemToolchainEnsureSourceCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemToolchainEnsureSourceCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemToolchainEnsureSourceCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := RunToolchainEnsureSourceCommand(AParams, Ctx.Out, Ctx.Err);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'toolchain', 'ensure-source'], @CreateSystemToolchainEnsureSourceCommand, []);

end.
