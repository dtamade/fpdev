unit fpdev.cmd.package.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings;

type
  TPackageInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackageInstallCommand.Name: string; begin Result := 'install'; end;
function TPackageInstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageInstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageInstallFactory: ICommand;
begin
  Result := TPackageInstallCommand.Create;
end;

function TPackageInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Pkg, Ver: string;
  Keep: Boolean;
  i: Integer;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_VERSION));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_KEEP));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
    Exit(2);
  end;

  Pkg := AParams[0];
  Ver := '';
  Keep := False;

  for i := 1 to High(AParams) do
  begin
    if SameText(AParams[i], '--keep-build-artifacts') then
      Keep := True
    else if (Ver = '') and (Copy(AParams[i], 1, 2) <> '--') then
      Ver := AParams[i];
  end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if Keep then LMgr.SetKeepBuildArtifacts(True);
    if LMgr.InstallPackage(Pkg, Ver, Ctx.Out, Ctx.Err) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','install'], @PackageInstallFactory, []);

end.
