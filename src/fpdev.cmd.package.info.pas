unit fpdev.cmd.package.info;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageInfoCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageInfoCommand.Name: string; begin Result := 'info'; end;
function TPackageInfoCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageInfoCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageInfoFactory: ICommand;
begin
  Result := TPackageInfoCommand.Create;
end;

function TPackageInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Pkg: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  Pkg := AParams[0];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.ShowPackageInfo(Pkg, Ctx.Out) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','info'], @PackageInfoFactory, []);

end.
