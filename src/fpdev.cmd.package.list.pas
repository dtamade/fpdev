unit fpdev.cmd.package.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.listcommandflow;

function TPackageListCommand.Name: string; begin Result := 'list'; end;
function TPackageListCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageListFactory: ICommand;
begin
  Result := TPackageListCommand.Create;
end;

function TPackageListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageListCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageListCommandPlanCore(
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
    Result := ExecutePackageListCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.ListPackages,
      @LMgr.GetAvailablePackageList,
      @LMgr.GetInstalledPackageList
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','list'], @PackageListFactory, []);

end.
