unit fpdev.cmd.cache.stats;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TCacheStatsCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateCacheStatsCommand: ICommand;

implementation

uses
  fpdev.cache.commandflow;

function CreateCacheStatsCommand: ICommand;
begin
  Result := TCacheStatsCommand.Create;
end;

function TCacheStatsCommand.Name: string;
begin
  Result := 'stats';
end;

function TCacheStatsCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCacheStatsCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TCacheStatsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system cache stats');
    Exit(EXIT_USAGE_ERROR);
  end;
  RunCacheStats(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'cache', 'stats'], @CreateCacheStatsCommand, []);

end.
