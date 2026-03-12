unit fpdev.help.details.repo;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

function WriteRepoHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function WriteRepoHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;
var
  LSubcmd: string;
begin
  Result := True;
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'add' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_OPT_HELP));
  end
  else if LSubcmd = 'remove' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_OPT_HELP));
  end
  else if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_OPT_HELP));
  end
  else if LSubcmd = 'show' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_OPT_HELP));
  end
  else if LSubcmd = 'versions' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_REPO));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_OS));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_ARCH));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_OFFLINE));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_REFRESH));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_HELP));
  end
  else if LSubcmd = 'use' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_OPT_HELP));
  end
  else
    Result := False;
end;

end.
