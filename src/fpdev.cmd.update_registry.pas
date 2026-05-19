unit fpdev.cmd.update_registry;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TUpdateRegistryCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.command.utils, fpdev.paths, fpdev.registry.updater;

function TUpdateRegistryCommand.Name: string;
begin
  Result := 'update-registry';
end;

function TUpdateRegistryCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TUpdateRegistryCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;
end;

function TUpdateRegistryCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RegistryDir: string;
  Mirror: string;
  Res: TRegistryUpdateResult;
  I: Integer;
begin
  Result := EXIT_OK;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev update-registry [--mirror=github|gitee]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Update the local registry from remote repository.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Options:');
    Ctx.Out.WriteLn('  --mirror=<name>  Use specific mirror (github, gitee)');
    Ctx.Out.WriteLn('  -h, --help       Show this help message');
    Exit(EXIT_OK);
  end;

  Mirror := '';
  for I := Low(AParams) to High(AParams) do
  begin
    if Pos('--mirror=', AParams[I]) = 1 then
      Mirror := Copy(AParams[I], 10, MaxInt);
  end;

  if Mirror = '' then
  begin
    if (Ctx <> nil) and (Ctx.Config <> nil) then
      Mirror := Ctx.Config.GetSettingsManager.GetSettings.Mirror;
    if (Mirror = '') or (Mirror = 'auto') then
      Mirror := 'github';
  end;

  RegistryDir := IncludeTrailingPathDelimiter(GetDataRoot) + 'registry';

  Res := UpdateRegistry(RegistryDir, Mirror, Ctx.Out);

  case Res of
    rurCloned:
      Ctx.Out.WriteLn('Registry cloned successfully.');
    rurSuccess:
      Ctx.Out.WriteLn('Registry updated successfully.');
    rurAlreadyUpToDate:
      Ctx.Out.WriteLn('Registry is already up to date.');
    rurFailed:
    begin
      Ctx.Err.WriteLn('Failed to update registry.');
      Result := EXIT_ERROR;
    end;
  end;
end;

function UpdateRegistryFactory: ICommand;
begin
  Result := TUpdateRegistryCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['update-registry'], @UpdateRegistryFactory, []);

end.
