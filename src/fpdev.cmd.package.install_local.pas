unit fpdev.cmd.package.install_local;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageInstallLocalCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageInstallLocalCommand.Name: string; begin Result := 'install-local'; end;
function TPackageInstallLocalCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageInstallLocalCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageInstallLocalFactory: ICommand;
begin
  Result := TPackageInstallLocalCommand.Create;
end;

function TPackageInstallLocalCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  P: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['path']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  P := AParams[0];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.InstallFromLocal(P, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','install-local'], @PackageInstallLocalFactory, []);

end.
