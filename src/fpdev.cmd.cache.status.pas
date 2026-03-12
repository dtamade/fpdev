unit fpdev.cmd.cache.status;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TCacheStatusCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateCacheStatusCommand: ICommand;

implementation

uses
  fpdev.cache.commandflow;

function CreateCacheStatusCommand: ICommand;
begin
  Result := TCacheStatusCommand.Create;
end;

function TCacheStatusCommand.Name: string;
begin
  Result := 'status';
end;

function TCacheStatusCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCacheStatusCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TCacheStatusCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system cache status');
    Exit(EXIT_USAGE_ERROR);
  end;
  RunCacheStatus(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'cache', 'status'], @CreateCacheStatusCommand, []);

end.
