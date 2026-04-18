unit fpdev.cmd.package.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.i18n.strings;

type
  TPackageInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.installcommandflow;

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
  LPlan: TPackageInstallCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageInstallCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    Result := ExecutePackageInstallCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.SetKeepBuildArtifacts,
      @LMgr.GetAvailablePackageList,
      @LMgr.InstallPackage
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','install'], @PackageInstallFactory, []);

end.
