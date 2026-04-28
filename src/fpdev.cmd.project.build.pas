unit fpdev.cmd.project.build;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.project.commandflow;

type
  TProjectBuildCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectBuildCommand.Name: string; begin Result := 'build'; end;
function TProjectBuildCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectBuildCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectBuildFactory: ICommand;
begin
  Result := TProjectBuildCommand.Create;
end;

function TProjectBuildCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TProjectManager;
  LPlan: TProjectBuildCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectBuildCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    Result := ExecuteProjectBuildCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.BuildProject
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','build'], @ProjectBuildFactory, []);

end.
