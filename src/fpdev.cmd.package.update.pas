unit fpdev.cmd.package.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.lifecyclecommandflow;

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
  LPlan: TPackageUpdateCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageUpdateCommandPlanCore(
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
    Result := ExecutePackageUpdateCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.GetInstalledPackageList,
      @LMgr.GetAvailablePackageList,
      @LMgr.UpdatePackage
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','update'], @PackageUpdateFactory, []);

end.
