unit fpdev.cmd.package.why;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageWhyCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.whycommandflow;

function TPackageWhyCommand.Name: string; begin Result := 'why'; end;
function TPackageWhyCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageWhyCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TPackageWhyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageWhyCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageWhyCommandPlanCore(
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
    Result := ExecutePackageWhyCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.TraceDependencyPath
    );
  finally
    LMgr.Free;
  end;
end;

function PackageWhyFactory: ICommand;
begin
  Result := TPackageWhyCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'why'], @PackageWhyFactory, []);

end.
