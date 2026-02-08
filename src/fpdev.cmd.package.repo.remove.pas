unit fpdev.cmd.package.repo.remove;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageRepoRemoveCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageRepoRemoveCommand.Name: string; begin Result := 'remove'; end;
function TPackageRepoRemoveCommand.Aliases: TStringArray; begin Result := nil; SetLength(Result,2); Result[0] := 'rm'; Result[1] := 'del'; end;
function TPackageRepoRemoveCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageRepoRemoveFactory: ICommand;
begin
  Result := TPackageRepoRemoveCommand.Create;
end;

function TPackageRepoRemoveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  RepoName: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  RepoName := AParams[0];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.RemoveRepository(RepoName, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','remove'], @PackageRepoRemoveFactory, ['rm','del']);

end.
