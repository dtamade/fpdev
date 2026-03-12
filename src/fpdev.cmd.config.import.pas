unit fpdev.cmd.config.import;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TConfigImportCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateConfigImportCommand: ICommand;

implementation

uses
  fpdev.config.commandflow, fpdev.exitcodes;

function CreateConfigImportCommand: ICommand;
begin
  Result := TConfigImportCommand.Create;
end;

function TConfigImportCommand.Name: string;
begin
  Result := 'import';
end;

function TConfigImportCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TConfigImportCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TConfigImportCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) <> 1 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system config import <file>');
    Exit(EXIT_USAGE_ERROR);
  end;
  Result := RunConfigImport(AParams[0], Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'config', 'import'], @CreateConfigImportCommand, []);

end.
