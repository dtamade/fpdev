unit fpdev.cmd.package.repo.add;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.package.repocommandflow;

type
  TPackageRepoAddCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TPackageRepoAddCommand.Name: string; begin Result := 'add'; end;
function TPackageRepoAddCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageRepoAddCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageRepoAddFactory: ICommand;
begin
  Result := TPackageRepoAddCommand.Create;
end;

function TPackageRepoAddCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageRepoAddCommandPlan;
  LShouldExit: Boolean;
  LRepositoryExists: Boolean;
begin
  Result := PreparePackageRepoAddCommandPlanCore(
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
    Result := ExecutePackageRepoAddCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      LRepositoryExists,
      @LMgr.AddRepository
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','add'], @PackageRepoAddFactory, []);

end.
