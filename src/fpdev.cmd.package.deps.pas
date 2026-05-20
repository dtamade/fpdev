unit fpdev.cmd.package.deps;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageDepsCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.depscommandflow;

function TPackageDepsCommand.Name: string; begin Result := 'deps'; end;
function TPackageDepsCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageDepsCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TPackageDepsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageDepsCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageDepsCommandPlanCore(
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
    Result := ExecutePackageDepsCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.GetDepsForPackage,
      @LMgr.GetProjectDependencies
    );
  finally
    LMgr.Free;
  end;
end;

function PackageDepsFactory: ICommand;
begin
  Result := TPackageDepsCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'deps'], @PackageDepsFactory, []);

end.
