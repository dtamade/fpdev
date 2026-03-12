unit fpdev.cmd.package.repo.remove;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
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

uses fpdev.command.utils;

function TPackageRepoRemoveCommand.Name: string; begin Result := 'remove'; end;

function TPackageRepoRemoveCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPackageRepoRemoveCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function PackageRepoRemoveFactory: ICommand;
begin
  Result := TPackageRepoRemoveCommand.Create;
end;

function TPackageRepoRemoveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  RepoName: string;
  UnknownOption: string;
  i: Integer;
begin
  Result := EXIT_OK;

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

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  RepoName := AParams[0];
  if Trim(RepoName) = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  for i := 1 to High(AParams) do
    if (AParams[i] <> '') and (AParams[i][1] <> '-') then
    begin
      Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;

  if not Ctx.Config.GetRepositoryManager.HasRepository(RepoName) then
  begin
    Ctx.Err.WriteLn(_Fmt(CMD_REPO_NOT_FOUND, [RepoName]));
    Exit(EXIT_NOT_FOUND);
  end;

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
  GlobalCommandRegistry.RegisterPath(['package','repo','remove'], @PackageRepoRemoveFactory, []);

end.
