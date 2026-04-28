unit fpdev.cmd.package.repo.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.package.repocommandflow;

type
  TPackageRepoListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TPackageRepoListCommand.Name: string; begin Result := 'list'; end;
function TPackageRepoListCommand.Aliases: TStringArray;
begin
  Result := nil;
end;
function TPackageRepoListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageRepoListFactory: ICommand;
begin
  Result := TPackageRepoListCommand.Create;
end;

function TPackageRepoListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageRepoListCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageRepoListCommandPlanCore(
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
    Result := ExecutePackageRepoListCommandPlanCore(
      Ctx.Out,
      @LMgr.ListRepositories
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','list'], @PackageRepoListFactory, []);

end.
