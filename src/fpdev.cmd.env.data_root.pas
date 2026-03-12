unit fpdev.cmd.env.data_root;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.exitcodes;

type
  TEnvDataRootCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateEnvDataRootCommand: ICommand;

implementation

uses
  fpdev.paths;

function CreateEnvDataRootCommand: ICommand;
begin
  Result := TEnvDataRootCommand.Create;
end;

function TEnvDataRootCommand.Name: string;
begin
  Result := 'data-root';
end;

function TEnvDataRootCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TEnvDataRootCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TEnvDataRootCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) > 0 then
  begin
    if (Length(AParams) = 1) and ((AParams[0] = '--help') or (AParams[0] = '-h')) then
    begin
      Ctx.Out.WriteLn('Usage: fpdev system env data-root');
      Exit;
    end;

    Ctx.Err.WriteLn('Usage: fpdev system env data-root');
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn(GetDataRoot());
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'env', 'data-root'], @CreateEnvDataRootCommand, []);

end.
