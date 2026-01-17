unit fpdev.cmd.package.clean;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.paths, fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings;

type
  TPackageCleanCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageCleanCommand.Name: string; begin Result := 'clean'; end;
function TPackageCleanCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageCleanCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageCleanFactory: ICommand;
begin
  Result := TPackageCleanCommand.Create;
end;

function TPackageCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Scope: string;
  DryRun, Yes: Boolean;
  Ok: Boolean;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_DRYRUN));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_YES));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['scope']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_CLEAN_USAGE));
    Exit(2);
  end;

  Scope := LowerCase(Trim(AParams[0]));
  if (Scope <> 'sandbox') and (Scope <> 'cache') and (Scope <> 'all') then
  begin
    Ctx.Err.WriteLn(_(CMD_PKG_CLEAN_USAGE));
    Exit(2);
  end;

  DryRun := HasFlag(AParams, 'dry-run');
  Yes := HasFlag(AParams, 'yes');

  if DryRun then
  begin
    if (Scope = 'sandbox') or (Scope = 'all') then
      Ctx.Out.WriteLn(_Fmt(CMD_PKG_CLEAN_DRY_RUN, [GetSandboxDir]));
    if (Scope = 'cache') or (Scope = 'all') then
      Ctx.Out.WriteLn(_Fmt(CMD_PKG_CLEAN_DRY_RUN, [IncludeTrailingPathDelimiter(GetCacheDir) + 'packages']));
    Exit(0);
  end;

  if not Yes then
  begin
    Ctx.Err.WriteLn(_(CMD_PKG_CLEAN_REFUSE_ROOT));
    Exit(2);
  end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    Ok := LMgr.Clean(Scope, Ctx.Out, Ctx.Err);
    if Ok then
    begin
      Ctx.Out.WriteLn(_(CMD_PKG_CLEAN_COMPLETE));
      Exit(0);
    end;
    Ctx.Err.WriteLn(_(CMD_PKG_CLEAN_ERRORS));
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','clean'], @PackageCleanFactory, []);

end.
