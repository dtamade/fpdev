unit fpdev.cmd.repo.use;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config.interfaces,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TRepoUseCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.command.utils;

function TRepoUseCommand.Name: string; begin Result := 'use'; end;
function TRepoUseCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoUseCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoUseCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RepoName: string;
  S: TFPDevSettings;
begin
  Result := EXIT_OK;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) <> 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_REPO_DEFAULT_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  RepoName := AParams[0];
  if Ctx.Config.GetRepositoryManager.GetRepository(RepoName) = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(CMD_REPO_NOT_FOUND, [RepoName]));
    Exit(EXIT_NOT_FOUND);
  end;
  S := Ctx.Config.GetSettingsManager.GetSettings;
  S.DefaultRepo := RepoName;
  if Ctx.Config.GetSettingsManager.SetSettings(S) then
    Exit(EXIT_OK);
  Ctx.Err.WriteLn(_Fmt(CMD_REPO_DEFAULT_FAILED, [RepoName]));
  Result := EXIT_ERROR;
end;

function RepoUseFactory: ICommand;
begin
  Result := TRepoUseCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'repo', 'use'], @RepoUseFactory, []);

end.
