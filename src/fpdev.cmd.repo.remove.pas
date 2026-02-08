unit fpdev.cmd.repo.remove;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TRepoRemoveCommand = class(TInterfacedObject, ICommand, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer; overload;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext); overload;
  end;

implementation

uses fpdev.cmd.utils;

function TRepoRemoveCommand.Name: string; begin Result := 'remove'; end;
function TRepoRemoveCommand.Aliases: TStringArray; begin Result := nil; SetLength(Result,1); Result[0]:='rm'; end;
function TRepoRemoveCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoRemoveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RepoName: string;
begin
  Result := 0;

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

  if Length(AParams) < 1 then
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
  if Ctx.Config.GetRepositoryManager.RemoveRepository(RepoName) then
    Exit(EXIT_OK);
  Ctx.Err.WriteLn(_Fmt(CMD_REPO_REMOVE_FAILED, [RepoName]));
  Result := EXIT_ERROR;
end;

{ @deprecated Use Execute(IContext) instead. Legacy interface for backward compatibility. }
procedure TRepoRemoveCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  RepoName: string;
begin
  if Length(AParams) < 1 then
    Exit;

  RepoName := AParams[0];

  if Trim(RepoName) = '' then
    Exit;

  Ctx.Config.RemoveRepository(RepoName);
  Ctx.SaveIfModified;
end;

function RepoRemoveFactory: ICommand;
begin
  Result := TRepoRemoveCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','remove'], @RepoRemoveFactory, ['rm']);

end.




