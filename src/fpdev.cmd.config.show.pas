unit fpdev.cmd.config.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TConfigShowCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateConfigShowCommand: ICommand;

implementation

uses
  fpdev.config.commandflow;

function CreateConfigShowCommand: ICommand;
begin
  Result := TConfigShowCommand.Create;
end;

function TConfigShowCommand.Name: string;
begin
  Result := 'show';
end;

function TConfigShowCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TConfigShowCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TConfigShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;
  if Length(AParams) <> 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system config show');
    Exit(EXIT_USAGE_ERROR);
  end;
  RunConfigShow(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'config', 'show'], @CreateConfigShowCommand, []);

end.
