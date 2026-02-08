unit fpdev.cmd.package.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageUpdateCommand.Name: string; begin Result := 'update'; end;
function TPackageUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageUpdateCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageUpdateFactory: ICommand;
begin
  Result := TPackageUpdateCommand.Create;
end;

function TPackageUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Pkg: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UPDATE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_UPDATE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  Pkg := AParams[0];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.UpdatePackage(Pkg, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','update'], @PackageUpdateFactory, []);

end.
