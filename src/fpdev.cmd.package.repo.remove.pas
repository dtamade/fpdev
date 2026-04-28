unit fpdev.cmd.package.repo.remove;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.package.repocommandflow;

type
  TPackageRepoRemoveCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TPackageRepoRemoveCommand.Name: string; begin Result := 'remove'; end;

function TPackageRepoRemoveCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPackageRepoRemoveCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function PackageRepoRemoveFactory: ICommand;
begin
  Result := TPackageRepoRemoveCommand.Create;
end;

function TPackageRepoRemoveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageRepoRemoveCommandPlan;
  LShouldExit: Boolean;
  LRepositoryExists: Boolean;
begin
  Result := PreparePackageRepoRemoveCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LRepositoryExists := Ctx.Config.GetRepositoryManager.HasRepository(LPlan.RepoName);

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    Result := ExecutePackageRepoRemoveCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      LRepositoryExists,
      @LMgr.RemoveRepository
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','remove'], @PackageRepoRemoveFactory, []);

end.
