unit fpdev.cmd.package.uninstall;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageUninstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.lifecyclecommandflow;

function TPackageUninstallCommand.Name: string; begin Result := 'uninstall'; end;
function TPackageUninstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageUninstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageUninstallFactory: ICommand;
begin
  Result := TPackageUninstallCommand.Create;
end;

function TPackageUninstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageUninstallCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageUninstallCommandPlanCore(
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
    Result := ExecutePackageUninstallCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.GetInstalledPackageList,
      @LMgr.UninstallPackage
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','uninstall'], @PackageUninstallFactory, []);

end.
