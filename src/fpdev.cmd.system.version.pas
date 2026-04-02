unit fpdev.cmd.system.version;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.exitcodes;

type
  TSystemVersionCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemVersionCommand: ICommand;

implementation

uses
  fpdev.paths,
  fpdev.version,
  fpdev.i18n,
  fpdev.i18n.strings;

function CreateSystemVersionCommand: ICommand;
begin
  Result := TSystemVersionCommand.Create;
end;

function TSystemVersionCommand.Name: string;
begin
  Result := 'version';
end;

function TSystemVersionCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemVersionCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemVersionCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) > 0 then
  begin
    if (Length(AParams) = 1) and ((AParams[0] = '--help') or (AParams[0] = '-h')) then
    begin
      Ctx.Out.WriteLn('Usage: fpdev system version');
      Exit;
    end;

    Ctx.Err.WriteLn('Usage: fpdev system version');
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn(Format(_(MSG_VERSION), [GetFullVersionString]));
  Ctx.Out.WriteLn(FPDEV_DESCRIPTION);
  if IsPortableMode then
    Ctx.Out.WriteLn('Mode: Portable')
  else
    Ctx.Out.WriteLn('Mode: Standard');
  Ctx.Out.WriteLn('Data: ' + GetDataRoot());
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'version'], @CreateSystemVersionCommand, []);

end.
