unit fpdev.cmd.package.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.package.types,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

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
  Keep, NoDeps, DryRun: Boolean;
  AvailablePkgs: TPackageArray;
  HasPkg, HasVersion: Boolean;
  UnknownOption: string;
  i: Integer;
begin
  Result := EXIT_OK;

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
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_NODEPS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_DRYRUN));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams,
    ['--keep-build-artifacts', '--no-deps', '--dry-run'], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  Pkg := AParams[0];
  if Trim(Pkg) = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  Ver := '';
  Keep := False;
  NoDeps := False;
  DryRun := False;

  for i := 1 to High(AParams) do
  begin
    if SameText(AParams[i], '--keep-build-artifacts') then
      Keep := True
    else if SameText(AParams[i], '--no-deps') then
      NoDeps := True
    else if SameText(AParams[i], '--dry-run') then
      DryRun := True
    else if (Trim(AParams[i]) <> '') and (Copy(AParams[i], 1, 2) <> '--') then
    begin
      if Ver = '' then
        Ver := AParams[i]
      else
      begin
        Ctx.Err.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
        Exit(EXIT_USAGE_ERROR);
      end;
    end;
  end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if Keep then LMgr.SetKeepBuildArtifacts(True);

    // Handle --dry-run: show what would be installed without installing
    if DryRun then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_HEADER));
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn(_Fmt(CMD_PKG_INSTALL_DRYRUN_PACKAGE, [Pkg]));
      if Ver <> '' then
        Ctx.Out.WriteLn(_Fmt(CMD_PKG_INSTALL_DRYRUN_VERSION, [Ver]))
      else
        Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_VERSION_LATEST));

      if NoDeps then
        Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_DEPS_SKIPPED))
      else
        Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_DEPS_RESOLVED));

      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_NO_CHANGES));
      Exit(EXIT_OK);
    end;

    // Handle --no-deps: show warning
    // Note: Current TPackageManager.InstallPackage always resolves dependencies
    // Full --no-deps support would require modifying TPackageManager internals
    if NoDeps then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_NODEPS_WARN1));
      Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_NODEPS_WARN2));
      Ctx.Out.WriteLn(_(CMD_PKG_INSTALL_NODEPS_WARN3));
      Ctx.Out.WriteLn('');
    end;

    // Validate package existence in available index before installation
    AvailablePkgs := LMgr.GetAvailablePackageList;
    HasPkg := False;
    HasVersion := False;
    for i := 0 to High(AvailablePkgs) do
    begin
      if SameText(AvailablePkgs[i].Name, Pkg) then
      begin
        HasPkg := True;
        if (Ver = '') or SameText(AvailablePkgs[i].Version, Ver) then
        begin
          HasVersion := True;
          Break;
        end;
      end;
    end;

    if (not HasPkg) or ((Ver <> '') and (not HasVersion)) then
    begin
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_IN_INDEX, [Pkg]));
      Exit(EXIT_NOT_FOUND);
    end;

    // Normal installation
    if LMgr.InstallPackage(Pkg, Ver, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','install'], @PackageInstallFactory, []);

end.
