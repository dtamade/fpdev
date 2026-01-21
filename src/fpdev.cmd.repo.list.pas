unit fpdev.cmd.repo.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  TRepoListCommand = class(TInterfacedObject, ICommand, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer; overload;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext); overload;
  end;

implementation

uses fpdev.cmd.utils;

function TRepoListCommand.Name: string; begin Result := 'list'; end;
function TRepoListCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Names: TStringArray;
  i: Integer;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_OPT_HELP));
    Exit(0);
  end;

  Names := Ctx.Config.GetRepositoryManager.ListRepositories;
  for i := 0 to High(Names) do
    Ctx.Out.WriteLn(Names[i] + ' = ' + Ctx.Config.GetRepositoryManager.GetRepository(Names[i]));
end;

procedure TRepoListCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  Names: TStringArray;
  i: Integer;
begin
  // AParams not used in legacy interface
  if Length(AParams) >= 0 then; // Suppress unused parameter warning
  Names := Ctx.Config.ListRepositories;
  // Silent execution for legacy interface - no output
end;

function RepoListFactory: ICommand;
begin
  Result := TRepoListCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','list'], @RepoListFactory, ['ls']);

end.




