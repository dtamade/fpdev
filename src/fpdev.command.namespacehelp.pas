unit fpdev.command.namespacehelp;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

type
  TNamespaceCommandProc = procedure(const Ctx: IContext) of object;

function ExecuteNamespaceRootCommandCore(
  const AParams: array of string;
  const Ctx: IContext;
  const AHelpUsage: string;
  AExecuteDefault: TNamespaceCommandProc;
  AShowHelp: TNamespaceCommandProc
): Integer;

implementation

uses
  fpdev.exitcodes;

function ExecuteNamespaceRootCommandCore(
  const AParams: array of string;
  const Ctx: IContext;
  const AHelpUsage: string;
  AExecuteDefault: TNamespaceCommandProc;
  AShowHelp: TNamespaceCommandProc
): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) = 0 then
  begin
    if Assigned(AExecuteDefault) then
      AExecuteDefault(Ctx);
    Exit;
  end;

  if (AParams[0] = 'help') or (AParams[0] = '--help') or (AParams[0] = '-h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(AHelpUsage);
      Exit(EXIT_USAGE_ERROR);
    end;

    if Assigned(AShowHelp) then
      AShowHelp(Ctx);
    Exit;
  end;

  Ctx.Err.WriteLn('Error: Unknown subcommand: ' + LowerCase(AParams[0]));
  if Assigned(AShowHelp) then
    AShowHelp(Ctx);
  Result := EXIT_USAGE_ERROR;
end;

end.
