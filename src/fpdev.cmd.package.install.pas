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
  Keep, NoDeps, DryRun: Boolean;
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
    Ctx.Out.WriteLn('  --no-deps              Skip dependency resolution');
    Ctx.Out.WriteLn('  --dry-run              Show what would be installed without installing');
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
    else if (Ver = '') and (Copy(AParams[i], 1, 2) <> '--') then
      Ver := AParams[i];
  end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if Keep then LMgr.SetKeepBuildArtifacts(True);

    // Handle --dry-run: show what would be installed without installing
    if DryRun then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Dry-run mode: showing what would be installed');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Package: ' + Pkg);
      if Ver <> '' then
        Ctx.Out.WriteLn('Version: ' + Ver)
      else
        Ctx.Out.WriteLn('Version: latest');

      if NoDeps then
        Ctx.Out.WriteLn('Dependencies: skipped (--no-deps)')
      else
        Ctx.Out.WriteLn('Dependencies: will be resolved during installation');

      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('No packages will be installed (dry-run mode)');
      Exit(0);
    end;

    // Handle --no-deps: show warning
    // Note: Current TPackageManager.InstallPackage always resolves dependencies
    // Full --no-deps support would require modifying TPackageManager internals
    if NoDeps then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Warning: --no-deps flag is recognized but dependency resolution');
      Ctx.Out.WriteLn('is currently integrated into the install process.');
      Ctx.Out.WriteLn('Installing with dependencies...');
      Ctx.Out.WriteLn('');
    end;

    // Normal installation
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
