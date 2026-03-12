unit fpdev.cmd.package.repo.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageRepoListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TPackageRepoListCommand.Name: string; begin Result := 'list'; end;
function TPackageRepoListCommand.Aliases: TStringArray;
begin
  Result := nil;
end;
function TPackageRepoListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageRepoListFactory: ICommand;
begin
  Result := TPackageRepoListCommand.Create;
end;

function TPackageRepoListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_LIST_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 0 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_LIST_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.ListRepositories(Ctx.Out) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','list'], @PackageRepoListFactory, []);

end.
