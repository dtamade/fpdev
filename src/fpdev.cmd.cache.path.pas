unit fpdev.cmd.cache.path;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TCachePathCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateCachePathCommand: ICommand;

implementation

uses
  fpdev.cache.commandflow;

function CreateCachePathCommand: ICommand;
begin
  Result := TCachePathCommand.Create;
end;

function TCachePathCommand.Name: string;
begin
  Result := 'path';
end;

function TCachePathCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCachePathCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TCachePathCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system cache path');
    Exit(EXIT_USAGE_ERROR);
  end;
  RunCachePath(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'cache', 'path'], @CreateCachePathCommand, []);

end.
