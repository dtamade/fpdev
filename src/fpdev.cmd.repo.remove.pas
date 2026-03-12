unit fpdev.cmd.repo.remove;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TRepoRemoveCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TRepoRemoveCommand.Name: string; begin Result := 'remove'; end;
function TRepoRemoveCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoRemoveCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoRemoveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RepoName: string;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) <> 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_REPO_REMOVE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  RepoName := AParams[0];
  if (Trim(RepoName)='') then
  begin
    Ctx.Err.WriteLn(_(HELP_REPO_REMOVE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if Ctx.Config.GetRepositoryManager.GetRepository(RepoName) = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(CMD_REPO_NOT_FOUND, [RepoName]));
    Exit(EXIT_NOT_FOUND);
  end;
  if Ctx.Config.GetRepositoryManager.RemoveRepository(RepoName) then
    Exit(EXIT_OK);
  Ctx.Err.WriteLn(_Fmt(CMD_REPO_REMOVE_FAILED, [RepoName]));
  Result := EXIT_ERROR;
end;

function RepoRemoveFactory: ICommand;
begin
  Result := TRepoRemoveCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'repo', 'remove'], @RepoRemoveFactory, []);

end.
