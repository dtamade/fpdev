unit fpdev.cmd.index.status;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TIndexStatusCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateIndexStatusCommand: ICommand;

implementation

uses
  fpdev.index.commandflow;

function CreateIndexStatusCommand: ICommand;
begin
  Result := TIndexStatusCommand.Create;
end;

function TIndexStatusCommand.Name: string;
begin
  Result := 'status';
end;

function TIndexStatusCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TIndexStatusCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TIndexStatusCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system index status');
    Exit(EXIT_USAGE_ERROR);
  end;
  RunIndexStatus(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'index', 'status'], @CreateIndexStatusCommand, []);

end.
