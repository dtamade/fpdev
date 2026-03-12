unit fpdev.cmd.package.repo.add;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageRepoAddCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TPackageRepoAddCommand.Name: string; begin Result := 'add'; end;
function TPackageRepoAddCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageRepoAddCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageRepoAddFactory: ICommand;
begin
  Result := TPackageRepoAddCommand.Create;
end;

function TPackageRepoAddCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  RepoName, URL: string;
  UnknownOption: string;
  i: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_ADD_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_ADD_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_ADD_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_ADD_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 2 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name, url']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_ADD_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  RepoName := AParams[0];
  URL := AParams[1];
  if (Trim(RepoName) = '') or (Trim(URL) = '') then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name, url']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_ADD_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  for i := 2 to High(AParams) do
    if (AParams[i] <> '') and (AParams[i][1] <> '-') then
    begin
      Ctx.Err.WriteLn(_(HELP_PACKAGE_REPO_ADD_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;

  if Ctx.Config.GetRepositoryManager.HasRepository(RepoName) then
  begin
    Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _(MSG_ALREADY_EXISTS) + ': ' + RepoName);
    Exit(EXIT_ALREADY_EXISTS);
  end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.AddRepository(RepoName, URL, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','add'], @PackageRepoAddFactory, []);

end.
