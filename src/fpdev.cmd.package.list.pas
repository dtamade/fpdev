unit fpdev.cmd.package.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings;

type
  TPackageListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageListCommand.Name: string; begin Result := 'list'; end;
function TPackageListCommand.Aliases: TStringArray; begin Result := nil; SetLength(Result,1); Result[0] := 'ls'; end;
function TPackageListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageListFactory: ICommand;
begin
  Result := TPackageListCommand.Create;
end;

function TPackageListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  ShowAll: Boolean;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPT_HELP));
    Exit(0);
  end;

  ShowAll := (Length(AParams) > 0) and (SameText(AParams[0], '--all') or SameText(AParams[0], '-a'));

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.ListPackages(ShowAll, Ctx.Out) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','list'], @PackageListFactory, ['ls']);

end.
