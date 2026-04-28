unit fpdev.cmd.package.repo.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.package.repocommandflow;

type
  TPackageRepoUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TPackageRepoUpdateCommand.Name: string; begin Result := 'update'; end;
function TPackageRepoUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageRepoUpdateCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function PackageRepoUpdateFactory: ICommand;
begin
  Result := TPackageRepoUpdateCommand.Create;
end;

function TPackageRepoUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageRepoUpdateCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageRepoUpdateCommandPlanCore(
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
    Result := ExecutePackageRepoUpdateCommandPlanCore(
      Ctx.Out,
      Ctx.Err,
      @LMgr.UpdateRepositories
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo','update'], @PackageRepoUpdateFactory, []);

end.
