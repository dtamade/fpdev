unit fpdev.cmd.system.toolchain.check;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.exitcodes;

type
  TSystemToolchainCheckCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemToolchainCheckCommand: ICommand;

implementation

uses
  fpdev.toolchain;

function CreateSystemToolchainCheckCommand: ICommand;
begin
  Result := TSystemToolchainCheckCommand.Create;
end;

function TSystemToolchainCheckCommand.Name: string;
begin
  Result := 'check';
end;

function TSystemToolchainCheckCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemToolchainCheckCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemToolchainCheckCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) > 0 then
  begin
    if (Length(AParams) = 1) and ((AParams[0] = '--help') or (AParams[0] = '-h')) then
    begin
      Ctx.Out.WriteLn('Usage: fpdev system toolchain check');
      Exit;
    end;

    Ctx.Err.WriteLn('Usage: fpdev system toolchain check');
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn(BuildToolchainReportJSON());
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'toolchain', 'check'], @CreateSystemToolchainCheckCommand, []);

end.
