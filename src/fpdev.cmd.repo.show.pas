unit fpdev.cmd.repo.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TRepoShowCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TRepoShowCommand.Name: string; begin Result := 'show'; end;
function TRepoShowCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoShowCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RepoName, URL: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_REPO_SHOW_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  RepoName := AParams[0];
  URL := Ctx.Config.GetRepositoryManager.GetRepository(RepoName);
  if URL='' then
  begin
    Ctx.Err.WriteLn(_Fmt(CMD_REPO_NOT_FOUND, [RepoName]));
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn(RepoName + ' = ' + URL);
  if SameText(Ctx.Config.GetSettingsManager.GetSettings.DefaultRepo, RepoName) then
    Ctx.Out.WriteLn(_(CMD_REPO_SHOW_DEFAULT));
end;

function RepoShowFactory: ICommand;
begin
  Result := TRepoShowCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','show'], @RepoShowFactory, []);

end.


