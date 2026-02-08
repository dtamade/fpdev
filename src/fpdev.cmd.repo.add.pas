unit fpdev.cmd.repo.add;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TRepoAddCommand = class(TInterfacedObject, ICommand, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer; overload;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext); overload;
  end;

implementation

uses fpdev.cmd.utils;

function TRepoAddCommand.Name: string; begin Result := 'add'; end;
function TRepoAddCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoAddCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoAddCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RepoName, URL: string;
begin
  Result := 0;

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

  if Length(AParams) < 2 then
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
  if Ctx.Config.GetRepositoryManager.AddRepository(RepoName, URL) then
  begin
    Ctx.Out.WriteLn(_Fmt(MSG_REPO_ADDED, [RepoName]));
    Exit(EXIT_OK);
  end;
  Ctx.Err.WriteLn(_Fmt(CMD_REPO_ADD_FAILED, [RepoName]));
  Result := EXIT_ERROR;
end;

{ @deprecated Use Execute(IContext) instead. Legacy interface for backward compatibility. }
procedure TRepoAddCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  RepoName, URL: string;
begin
  if Length(AParams) < 2 then
    Exit;

  RepoName := AParams[0];
  URL := AParams[1];

  if (Trim(RepoName) = '') or (Trim(URL) = '') then
    Exit;

  Ctx.Config.AddRepository(RepoName, URL);
  Ctx.SaveIfModified;
end;

function RepoAddFactory: ICommand;
begin
  Result := TRepoAddCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','add'], @RepoAddFactory, []);

end.




