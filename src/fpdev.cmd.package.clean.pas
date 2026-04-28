unit fpdev.cmd.package.clean;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageCleanCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.paths,
  fpdev.package.cleancommandflow;

function TPackageCleanCommand.Name: string; begin Result := 'clean'; end;
function TPackageCleanCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageCleanCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageCleanFactory: ICommand;
begin
  Result := TPackageCleanCommand.Create;
end;

function TPackageCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageCleanCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageCleanCommandPlanCore(
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
    Result := ExecutePackageCleanCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      GetSandboxDir,
      IncludeTrailingPathDelimiter(GetCacheDir) + 'packages',
      @LMgr.Clean
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','clean'], @PackageCleanFactory, []);

end.
