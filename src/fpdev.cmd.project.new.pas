unit fpdev.cmd.project.new;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.project.commandflow;

type
  TProjectNewCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectNewCommand.Name: string; begin Result := 'new'; end;
function TProjectNewCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectNewCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectNewFactory: ICommand;
begin
  Result := TProjectNewCommand.Create;
end;

function TProjectNewCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TProjectManager;
  LPlan: TProjectNewCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectNewCommandPlanCore(
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
    Result := ExecuteProjectNewCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.CreateProject
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','new'], @ProjectNewFactory, []);

end.
