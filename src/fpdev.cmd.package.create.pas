unit fpdev.cmd.package.create;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings;

type
  TPackageCreateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageCreateCommand.Name: string; begin Result := 'create'; end;
function TPackageCreateCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageCreateCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageCreateFactory: ICommand;
begin
  Result := TPackageCreateCommand.Create;
end;

function TPackageCreateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  PkgName, Path: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CREATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CREATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CREATE_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 2 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name, path']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_CREATE_USAGE));
    Exit(2);
  end;
  PkgName := AParams[0];
  Path := AParams[1];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.CreatePackage(PkgName, Path, Ctx.Out, Ctx.Err) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','create'], @PackageCreateFactory, []);

end.
