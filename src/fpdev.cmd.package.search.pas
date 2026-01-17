unit fpdev.cmd.package.search;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings;

type
  TPackageSearchCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageSearchCommand.Name: string; begin Result := 'search'; end;
function TPackageSearchCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageSearchCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageSearchFactory: ICommand;
begin
  Result := TPackageSearchCommand.Create;
end;

function TPackageSearchCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Q: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_EXAMPLE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['query']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
    Exit(2);
  end;
  Q := AParams[0];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.SearchPackages(Q, Ctx.Out) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','search'], @PackageSearchFactory, []);

end.
