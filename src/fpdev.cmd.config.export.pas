unit fpdev.cmd.config.export;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TConfigExportCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateConfigExportCommand: ICommand;

implementation

uses
  fpdev.config.commandflow, fpdev.exitcodes;

function CreateConfigExportCommand: ICommand;
begin
  Result := TConfigExportCommand.Create;
end;

function TConfigExportCommand.Name: string;
begin
  Result := 'export';
end;

function TConfigExportCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TConfigExportCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TConfigExportCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) <> 1 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system config export <file>');
    Exit(EXIT_USAGE_ERROR);
  end;
  Result := RunConfigExport(AParams[0], Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'config', 'export'], @CreateConfigExportCommand, []);

end.
