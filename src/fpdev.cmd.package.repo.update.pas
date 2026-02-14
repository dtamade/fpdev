unit fpdev.cmd.package.repo.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageRepoUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageRepoUpdateCommand.Name: string; begin Result := 'update'; end;
function TPackageRepoUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageRepoUpdateCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function PackageRepoUpdateFactory: ICommand;
begin
  Result := TPackageRepoUpdateCommand.Create;
end;

function TPackageRepoUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_UPDATE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.UpdateRepositories(Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','update'], @PackageRepoUpdateFactory, []);

end.
