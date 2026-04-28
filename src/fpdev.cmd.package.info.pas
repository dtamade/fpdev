unit fpdev.cmd.package.info;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageInfoCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.infocommandflow;

function TPackageInfoCommand.Name: string; begin Result := 'info'; end;
function TPackageInfoCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageInfoCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageInfoFactory: ICommand;
begin
  Result := TPackageInfoCommand.Create;
end;

function TPackageInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageInfoCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageInfoCommandPlanCore(
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
    Result := ExecutePackageInfoCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.GetInstalledPackageList,
      @LMgr.ShowPackageInfo
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','info'], @PackageInfoFactory, []);

end.
