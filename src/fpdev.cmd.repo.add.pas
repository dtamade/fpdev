unit fpdev.cmd.repo.add;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TRepoAddCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TRepoAddCommand.Name: string; begin Result := 'add'; end;
function TRepoAddCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoAddCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoAddCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RepoName, URL: string;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) <> 2 then
  begin
    Ctx.Err.WriteLn(_(HELP_REPO_ADD_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  RepoName := AParams[0];
  URL := AParams[1];
  if (Trim(RepoName)='') or (Trim(URL)='') then
  begin
    Ctx.Err.WriteLn(_(HELP_REPO_ADD_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if Ctx.Config.GetRepositoryManager.HasRepository(RepoName) then
  begin
    Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _(MSG_ALREADY_EXISTS) + ': ' + RepoName);
    Exit(EXIT_ALREADY_EXISTS);
  end;
  if Ctx.Config.GetRepositoryManager.AddRepository(RepoName, URL) then
  begin
    Ctx.Out.WriteLn(_Fmt(MSG_REPO_ADDED, [RepoName]));
    Exit(EXIT_OK);
  end;
  Ctx.Err.WriteLn(_Fmt(CMD_REPO_ADD_FAILED, [RepoName]));
  Result := EXIT_ERROR;
end;

function RepoAddFactory: ICommand;
begin
  Result := TRepoAddCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'repo', 'add'], @RepoAddFactory, []);

end.
